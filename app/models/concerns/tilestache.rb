module Tilestache
  require "open3"
  extend ActiveSupport::Concern

  def tilestache_seed
    bucket_name = ENV['google_tiles_bucket'] || APP_CONFIG['google_tiles_bucket']
    max_zoom = ENV['s3_tiles_max_zoom'] || APP_CONFIG['s3_tiles_max_zoom'] #i.e. 21

    if max_zoom == "" || max_zoom.to_i > 25
      max_zoom = 21
    end

    # ==============================================================================
    # Code to compute max_zoom
    # uses width of map in pixels, and width of map in degrees
    if self.class.to_s == "Map"
      warped_filename = self.warped_filename
      pixel_width = self.width
    else
      warped_filename = self.maps.select {|m| m.map_type == :is_map}.first.warped_filename
      pixel_width = self.maps.select {|m| m.map_type == :is_map}.first.width
    end

    if warped_filename
      tile_width = 256.0
      bbox = RGeo::Cartesian::BoundingBox.create_from_geometry(self.bbox_geom)

      degree_width = bbox.x_span

      max_tiles_x = (pixel_width / tile_width).ceil # 39

      max_zoom = compute_max_zoom(max_tiles_x, degree_width)

      max_zoom= add_zoom_levels(max_zoom)
    end
    # ==============================================================================

    item_type  = self.class.to_s.downcase
    item_id =  self.id

    options = {
      :item_type => item_type,
      :item_id => item_id,
      :bucket => bucket_name,
      :max_zoom => max_zoom
    }

    config_json = tilestache_config_json(options)

    config_file = File.join(Rails.root, 'tmp', "#{options[:item_type]}_#{options[:item_id]}_tilestache.json")
    File.open(config_file, "w+") do |f|
      f.write(config_json)
    end

    bbox = self.bbox.split(",")
    tile_bbox = bbox[1],bbox[0],bbox[3],bbox[2]
    tile_bbox_str = tile_bbox.join(" ")

    layer_name = self.id.to_s
    layer_name = "map-"+ layer_name if options[:item_type] == "map"
    tilestache_path = File.join(Rails.root, 'lib/tilestache/TileStache-1.51.5')

    #make sure both GOOGLE_APPLICATION_CREDENTIALS and PYTHONPATH  environment variables are set for this to work (see application_config.rb)
    command = "cd #{tilestache_path}; ./scripts/tilestache-seed.py -c #{config_file}" +
      " -l #{layer_name} -b #{tile_bbox_str} --enable-retries -x #{(1..max_zoom.to_i).to_a.join(' ')}"

    puts command

    t_stdout, t_stderr, t_status = Open3.capture3( command )

    unless t_status.success?

      puts t_stderr

      return nil
    else

      send_tile_config(options)

      return true
    end


  end


  private

  def add_zoom_levels(zoom)
    # adds zoom levels to allow for deeper zoom despite the geotiff not being high-res enough
    new_zoom = zoom
    if zoom >= 1 && zoom <= 7
      new_zoom = new_zoom + 3
    elsif zoom >= 8 && zoom <= 10
      new_zoom = new_zoom + 2
    elsif zoom >= 11 && zoom <= 20
      new_zoom = new_zoom + 1
    end
    return new_zoom
  end

  def compute_max_zoom(max_tiles_x, degree_width)
    n = max_tiles_x / (degree_width / 360.0)
    zoom = Math.log(n, 2).ceil

    return zoom
  end

  def tilestache_config_json(options)

    url = "#{APP_CONFIG['host_with_scheme']}/#{options[:item_type]}s/tile/#{options[:item_id]}/{Z}/{X}/{Y}.png"

    layer_name = options[:item_id].to_s
    layer_name = "map-"+ layer_name if options[:item_type] == "map"

    config = {
      "cache" => {
        "class" => "TileStache.Goodies.Caches.GoogleCloudNative:Cache",
        "kwargs" => {
          "bucket" => options[:bucket],
          "use_locks" => "false" 
        }
      },
      "layers" => {
        layer_name => {
          "provider" => {
            "name" => "proxy",
            "url" =>  url
          }
        }
      }
    }

    JSON.pretty_generate(config)
  end

  def send_tile_config(options)
    bucket_name = options[:bucket]

    connection = Fog::Storage::Google.new(
      google_project: APP_CONFIG["google_storage_project"],
      google_json_key_location:  APP_CONFIG["google_json_key_location"]
    )
    bucket = connection.directories.get(APP_CONFIG["google_tiles_bucket"])

    layer_name = options[:item_id].to_s
    layer_name = "map-"+ layer_name if options[:item_type] == "map"

    tile_config_filename = "#{layer_name}spec.json"
    tile_config_file = layer_name + "/" + tile_config_filename

    the_json = tile_config_json(options)

    file = bucket.files.create(
      :key    => tile_config_file,
      :body   => the_json,
      :public => true
    )
      
  end

  #config file to be sent to s3 as well
  def tile_config_json(options)
    layer_name = options[:item_id].to_s
    layer_name = "map-"+ layer_name if options[:item_type] == "map"
    tiles_host = APP_CONFIG['cdn_tiles_host'].blank? ? "https://storage.googleapis.com/#{APP_CONFIG['google_tiles_bucket']}" : APP_CONFIG['cdn_tiles_host']

    name = self.title if options[:item_type] == "map"
    name = self.name if options[:item_type] == "layer"
    max_zoom = options[:max_zoom].to_i || 21

    description  = self.description
    site_url = APP_CONFIG['host_with_scheme']
    site_name  =  APP_CONFIG['site_name']
    attribution ="From: <a href='#{site_url}/#{self.class.to_s.downcase}s/#{self.id}/'>#{site_name}</a>" 

    bbox = self.bbox.split(",")

    tile_bbox = [bbox[0].to_f,bbox[1].to_f,bbox[2].to_f,bbox[3].to_f]

    centroid_y = tile_bbox[1] + ((tile_bbox[3] -  tile_bbox[1]) / 2)
    centroid_x = tile_bbox[0] + ((tile_bbox[2] -  tile_bbox[0]) / 2)

    config = {
      "tilejson"      => "2.0.0",
      "autoscale"   => true,
      "name"        => "#{name}",
      "description" => "#{description}",
      "version"     => "1.5.0",
      "attribution" => "#{attribution}",
      "scheme"      => "xyz",
      "tiles"       => ["#{tiles_host}/#{layer_name}/{z}/{x}/{y}.png"],
      "minzoom"     => 1,
      "maxzoom"     => max_zoom,
      "bounds"      => tile_bbox,
      "center"      => [centroid_x, centroid_y, max_zoom ]
    }

    return JSON.pretty_generate(config)

  end
end
