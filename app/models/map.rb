require "open3"
require "error_calculator"
require 'csv'
include ErrorCalculator
class Map < ActiveRecord::Base
  include Tilestache
  
  has_many :gcps,  :dependent => :destroy
  has_many :layers_maps,  :dependent => :destroy
  has_many :layers, :through => :layers_maps # ,:after_add, :after_remove
  has_many :my_maps, :dependent => :destroy
  has_many :users, :through => :my_maps
  has_one :masking, :dependent => :destroy
  belongs_to :owner, :class_name => "User"
  
  has_attached_file :upload, :styles => {:thumb => ["100x100>", :png]} ,
    :url => '/:attachment/:id/:style/:basename.:extension',
    :default_url => "missing.png",
    :restricted_characters => /[&$+,\/:;=?@<>\[\]\{\}\)\(\'\"\|\\\^~%# ]/ ,
    :fog_public => true
    
  validates_attachment_size(:upload, :less_than => MAX_ATTACHMENT_SIZE) if defined?(MAX_ATTACHMENT_SIZE)
 
  validates_attachment_content_type :upload, :content_type => ["image/jpg", "image/jpeg","image/pjpeg", "image/png","image/x-png", "image/gif", "image/tiff"]
  validates_presence_of :upload, :message => :no_file_uploaded, :unless => :upload_url_provided?
  
  validates_presence_of :title
  validates_numericality_of :rough_lat, :rough_lon, :rough_zoom, :allow_nil => true
  validates_numericality_of :metadata_lat, :metadata_lon, :allow_nil => true
  validates_length_of :issue_year, :maximum => 4,:allow_nil => true, :allow_blank => true
  validates_numericality_of :issue_year, :if => Proc.new {|c| not c.issue_year.blank?}
  validates_length_of :date_depicted, :maximum => 4,:allow_nil => true, :allow_blank => true
  validates_numericality_of :date_depicted, :if => Proc.new {|c| not c.date_depicted.blank?}
  validates_uniqueness_of :unique_id, :allow_nil => true, :allow_blank => true
  validate :unique_filename, :on => :create
  
  acts_as_taggable
  acts_as_commentable
  acts_as_enum :map_type, [:index, :is_map, :not_map ]
  acts_as_enum :status, [:unloaded, :loading, :available, :warping, :warped, :published, :publishing]
  acts_as_enum :mask_status, [:unmasked, :masking, :masked]
  acts_as_enum :rough_state, [:step_1, :step_2, :step_3, :step_4]
  has_paper_trail :ignore => [:bbox, :bbox_geom]
  
  include PgSearch
  multisearchable :against => [:title, :description], :if => :warped_published_and_public?
  
  scope :warped,    -> { where({ :status => [Map.status(:warped), Map.status(:published)], :map_type => Map.map_type(:is_map)  }) }
  scope :published, -> { where({:status => Map.status(:published), :map_type => Map.map_type(:is_map)})}
  scope :unpublished, -> { where.not(:status => Map.status(:published)) }
  scope :are_public, -> { where(public: true) }
  scope :real_maps, -> { where({:map_type => Map.map_type(:is_map)})}
  scope :unprotected,  -> { unpublished.where(protect: false) }

  attr_accessor :error
  attr_accessor :upload_url

  after_initialize :default_values
  before_create :download_remote_image, :if => :upload_url_provided?
  before_create :save_dimensions
  after_create :setup_image
  after_create :update_user_counts
  after_destroy :delete_images
  after_destroy :delete_map, :update_counter_cache, :update_layers
  after_destroy :update_user_counts
  after_save :update_counter_cache
  
  ##################
  # CALLBACKS / Validations
  ###################
  
  def default_values
    self.status  ||= :available
    self.mask_status  ||= :unmasked  
    self.map_type  ||= :is_map  
    self.rough_state ||= :step_1  
  end
  
  def unique_filename
    if upload.original_filename
      errors.add(:filename, :filename_not_unique) if Map.find_by_upload_file_name(upload.original_filename)
    end
  end
  
  def upload_url_provided?
    !self.upload_url.blank?
  end

  def thumb_url
    thumb = self.upload.url(:thumb)
    if thumb.start_with?('http')
      thumb
    else
      (APP_CONFIG['site_prefix'] || "") + thumb
    end
  end
  
  def download_remote_image
    img_upload = do_download_remote_image
    unless img_upload
      errors.add(:upload_url, :error_url)  #(en.activerecord.errors.models.map.error_url)
      return false
    end
    self.upload = img_upload
 
    self.source_uri  = source_uri.blank? ? upload_url : source_uri
    
    if Map.find_by_source_uri(upload_url)
      errors.add(:filename, :filename_not_unique)
      return false
    end
    
  end
  
  def do_download_remote_image
    begin
      io = open(URI.parse(upload_url))
      def io.original_filename
        filename =  base_uri.path.split('/').last
        
        if  !filename.blank?
          basename = File.basename(filename,File.extname(filename)) + '_'+('a'..'z').to_a.shuffle[0,8].join
          extname = File.extname(filename)
          filename = basename + extname
        end
        
        filename
      end
      io.original_filename.blank? ? nil : io
    rescue => e
      logger.debug "Error with URL upload"
      logger.debug e
      return false
    end
  end
   
  def save_dimensions
    if ["image/jp2","image/jpeg", "image/tiff", "image/png", "image/gif", "image/bmp"].include?(upload.content_type.to_s)      
      tempfile = upload.queued_for_write[:original]
      unless tempfile.nil?
        geometry = Paperclip::Geometry.from_file(tempfile)
        self.width = geometry.width.to_i
        self.height = geometry.height.to_i
      end
    end
    self.status = :available
  end
  
  #this gets the upload, detects what it is, and converts to a tif, if necessary.
  #Although an uploaded tif with existing geo fields may confuse things
  def setup_image
    logger.info "setup_image "
    self.filename = upload.original_filename

    #save!  I think this is no longer needed as saving will trigger the saving of file to filesystem or cloud and we want to convert to tiff before that happens.
    
    if self.upload?
      
      if  defined?(MAX_DIMENSION) && (width > MAX_DIMENSION || height > MAX_DIMENSION)
        logger.info "Image is too big, so going to resize "
        if width > height
          dest_width = MAX_DIMENSION
          dest_height = (dest_width.to_f /  width.to_f) * height.to_f
        else
          dest_height = MAX_DIMENSION
          dest_width = (dest_height.to_f /  height.to_f) * width.to_f
        end
        self.width = dest_width
        self.height = dest_height
        
        outsize = ["-outsize", dest_width.to_i, dest_height.to_i]
      else
        outsize = []
      end
      
      orig_ext = File.extname(self.upload_file_name).to_s.downcase
      
      tiffed_filename = (orig_ext == ".tif" || orig_ext == ".tiff")? self.upload_file_name : self.upload_file_name + ".tif"
      tiffed_file_path = File.join(maps_dir , tiffed_filename)
      
      logger.info "We convert to tiff"

      #for those greyscale or black and white images with one band
      bands  = []

      tmp_upload_path = upload.queued_for_write[:original].path

      if raster_bands_count(tmp_upload_path) == 1
        if has_palette_colortable?(tmp_upload_path)
          bands = ["-expand", "rgb"]
        else
          #if it has one band and grey scale, we need to convert e.g convert grey1band.jpg -type TrueColor  rgb3band.jpg
          command = ["mogrify" , "-type",  "TrueColor", tmp_upload_path ]
          logger.info command
          c_stdin, c_stdout, c_stderr = Open3::popen3(*command)
      
          c_out = c_stdout.readlines.to_s
          c_err = c_stderr.readlines.to_s
          if c_stderr.readlines.empty? && c_err.size > 0
            logger.error "Error with convert one band script "+ c_err.inspect
            logger.error "output = "+c_out
          end

        end
      end
      
      #transparent pngs may cause issues, so let's remove the alpha band
      if raster_bands_count(tmp_upload_path) == 4 && orig_ext == ".png"
        bands = ["-b", "1", "-b", "2", "-b", "3"]
      end
      
      command  = ["#{GDAL_PATH}gdal_translate", tmp_upload_path, outsize, bands, "-co", "COMPRESS=DEFLATE", "-co",  "PHOTOMETRIC=RGB", "-co", "PROFILE=BASELINE", "-co", "BIGTIFF=YES", tiffed_file_path].reject(&:empty?).flatten
      logger.info command
      ti_stdin, ti_stdout, ti_stderr =  Open3::popen3( *command )
      logger.info ti_stdout.readlines.to_s
      logger.info ti_stderr.readlines.to_s
      

      command = ["#{GDAL_PATH}gdaladdo", "-r", "average", tiffed_file_path, "2", "4", "8", "16", "32", "64" ]
      o_stdin, o_stdout, o_stderr = Open3::popen3(*command)
      logger.info command
      
      o_out = o_stdout.readlines.to_s
      o_err = o_stderr.readlines.to_s
      if o_stderr.readlines.empty? && o_err.size > 0
        logger.error "Error gdal overview script" + o_err.inspect
        logger.error "output = "+o_out
      end
      
      self.filename = tiffed_filename
      
      #now delete the original if on file system for example
      logger.debug "Deleting uploaded file, now it's a usable tif"
      if File.exists?(self.upload.path)
        logger.debug "deleted uploaded file"
        File.delete(self.upload.path)
      end
      
    end
    self.map_type = :is_map
    self.rough_state = :step_1
    save!

  
    self.run_ocr if APP_CONFIG["enable_ocr_job"] != "false"
  end
  
  #paperclip plugin deletes the images when model is destroyed
  def delete_images
    logger.info "Deleting map images"
    if File.exists?(temp_filename)
      logger.info "deleted temp"
      File.delete(temp_filename)
    end
    if File.exists?(warped_filename)
      logger.info "Deleted Map warped"
      File.delete(warped_filename)
    end
    if File.exists?(warped_overviews_filename)
      logger.info "Deleted external warped overviews file"
      File.delete(warped_overviews_filename)
    end
    if File.exists?(warped_png_filename)
      logger.info "deleted warped png"
      File.delete(warped_png_filename)
    end
    if File.exists?(unwarped_filename)
      logger.info "deleting unwarped"
      File.delete unwarped_filename
    end
    if File.exists?(masked_src_filename)
      logger.info "deleting unwarped masked file"
      File.delete masked_src_filename
    end
  end
  
  def delete_map
    logger.info "Deleting mapfile"
  end
  
  def update_layer
    self.layers.each do |layer|
      layer.update_layer
    end unless self.layers.empty?
  end
  
  def update_layers
    logger.debug "updating (visible) layers"
    unless self.layers.visible.empty?
      self.layers.visible.each  do |layer|
        layer.update_layer
      end
    end
  end
  
  def update_counter_cache
    logger.debug "update_counter_cache"
    unless self.layers.empty?
      self.layers.each do |layer|
        layer.update_counts
      end
    end
  end
  
  def update_gcp_touched_at
    self.touch(:gcp_touched_at)
  end

  def update_user_counts
    logger.debug "updating owner map counts"
    if self.owner
      self.owner.update_map_counts
    end
  end
  
  #method to publish the map
  #sets status to published
  def publish
    self.paper_trail_event = 'publishing'
    self.status = :publishing
    self.save
    
    Spawnling.new(:nice => 7) do
      begin
        if self.tilestache_seed  #in tilestache concern
          self.paper_trail_event = 'published'
          self.status = :published
          self.save
        else
          self.paper_trail_event = 'fail_publish'
          self.status = :warped
          self.save
        end
      rescue Exception => e
        logger.error e.inspect
        self.paper_trail_event = 'fail_publish'
        self.status = :warped
        self.save
      end
      self.paper_trail_event = nil
      
    end #spawnling fork
    
  end
  
  #unpublishes a map, sets it's status to warped
  def unpublish
    self.paper_trail_event = 'unpublished'
    self.status = :warped
    self.save
    self.paper_trail_event = nil

    self.save
  end
  
  #############################################
  #CLASS METHODS
  #############################################

  def self.map_type_hash
    values = Map::MAP_TYPE
    keys = [I18n.t('maps.model.map_type.index'), I18n.t('maps.model.map_type.map'), I18n.t('maps.model.map_type.not_map')]
    Hash[*keys.zip(values).flatten]
  end
  
  def self.max_attachment_size
    max_attachment_size =  defined?(MAX_ATTACHMENT_SIZE)? MAX_ATTACHMENT_SIZE : nil
  end
  
  def self.max_dimension
    max_dimension = defined?(MAX_DIMENSION)? MAX_DIMENSION : nil
  end
  
  #############################################
  #ACCESSOR METHODS
  #############################################
  
  def maps_dir
    defined?(SRC_MAPS_DIR) ? SRC_MAPS_DIR :  File.join(Rails.root, "/public/mapimages/src/")
  end

  def dest_dir
    defined?(DST_MAPS_DIR) ?  DST_MAPS_DIR : File.join(Rails.root, "/public/mapimages/dst/")
  end


  def warped_dir
    dest_dir
  end

  def unwarped_filename
    if self.filename
      File.join(maps_dir, self.filename) 
    else
      ""
    end
  end

  def warped_filename
    File.join(warped_dir, id.to_s) + ".tif"
  end
  
  def warped_overviews_filename
    File.join(warped_dir, id.to_s) + ".aux"
  end

  def warped_png_dir
    File.join(dest_dir, "/png/")
  end

  def warped_png
    unless File.exists?(warped_png_filename)
      convert_to_png
    end
    warped_png_filename
  end
  
  def warped_png_filename
    filename = File.join(warped_png_dir, id.to_s) + ".png"
  end

  def warped_png_aux_xml
    warped_png + ".aux.xml"
  end

  def mask_file_format
    "geojson"
  end

  def temp_filename
    # self.full_filename  + "_temp"
    File.join(warped_dir, id.to_s) + "_temp"
  end

  def masking_file_gml
    File.join(MAP_MASK_DIR,  self.id.to_s) + ".gml"
  end

  #file made when rasterizing
  def masking_file_gfs
    File.join(MAP_MASK_DIR,  self.id.to_s) + ".gfs"
  end

  def masked_src_filename
    self.unwarped_filename + "_masked";
  end
  
  
  #############################################
  #INSTANCE METHODS
  #############################################
  
  def mask_geojson
    mask = nil
    if self.masking && self.masking.transformed_geojson
      mask = self.masking.transformed_geojson
    end

    mask
  end
  
  def depicts_year
    issue_year ||  self.layers.with_year.collect(&:depicts_year).compact.first
  end
  
  def warped?
    status == :warped
  end
  
  def available?
    return [:available,:warping, :warped, :published].include?(status)
  end

  def published?
    status == :published
  end

  def publishing?
    status == :publishing
  end

  def warped_or_published?
    return [:warped, :published].include?(status)
  end

  def warped_published_and_public?
    return [:warped, :published].include?(status) && public?
  end
  
  def update_map_type(map_type)
    if Map::MAP_TYPE.include? map_type.to_sym
      self.update_attributes(:map_type => map_type.to_sym)
      self.update_layers
    end
  end
  
  def last_changed
    if self.gcps.size > 0
      self.gcps.last.created_at
    elsif !self.updated_at.nil?
      self.updated_at
    elsif !self.created_at.nil?
      self.created_at
    else
      Time.now
    end
  end
  
  def save_rough_centroid(lon,lat)
    self.rough_centroid =  Point.from_lon_lat(lon,lat)
    self.save
  end
  
  def save_bbox
    stdin, stdout, stderr = Open3::popen3("#{GDAL_PATH}gdalinfo",  warped_filename)
    unless stderr.readlines.to_s.size > 0
      info = stdout.readlines.to_s
      string,west,south = info.match(/Lower Left\s+\(\s*([-.\d]+),\s+([-.\d]+)/).to_a
      string,east,north = info.match(/Upper Right\s+\(\s*([-.\d]+),\s+([-.\d]+)/).to_a
      self.bbox = [west,south,east,north].join(",")
    else
      logger.debug "Save bbox error "+ stderr.readlines.to_s
    end
  end

  def view_params
    bounds_float  = bounds.split(',').collect {|i| i.to_f}
    x = (bounds_float[0] + bounds_float[2]) / 2
    y = (bounds_float[1] + bounds_float[3]) / 2
    scale = 18
    [scale,y,x].join '/'
  end
  
  def bounds
    if bbox.nil?
      x_array = []
      y_array = []
      self.gcps.hard.each do |gcp|
        next unless gcp[:lat].is_a? Numeric and gcp[:lon].is_a? Numeric
        x_array << gcp[:lat]
        y_array << gcp[:lon]
      end
      #south, west, north, east
      our_bounds = [y_array.min ,x_array.min ,y_array.max, x_array.max].join ','
    else
      bbox
    end
  end

  #bounds set by "soft" control points
  def soft_bounds
    return nil unless self.gcps.soft.size >= 3 
    x_array = []
    y_array = []
    self.gcps.soft.each do |gcp|
      next unless gcp[:lat].is_a? Numeric and gcp[:lon].is_a? Numeric
      x_array << gcp[:lat]
      y_array << gcp[:lon]
    end
    #south, west, north, east
    our_bounds = [y_array.min ,x_array.min ,y_array.max, x_array.max].join ','
    
    our_bounds
  end

  #is the map okay for quick placement. No gcps, hard or soft, and should be available. Can be masked though.
  def quick_eligible?
    return false unless gcps.empty?
    return false unless status == :available

    true
  end
  
  
  #returns a GeoRuby polygon object representing the bounds
  def bounds_polygon
    bounds_float  = bounds.split(',').collect {|i| i.to_f}
    Polygon.from_coordinates([ [bounds_float[0..1]] , [bounds_float[2..3]] ], -1)
  end
  
  def converted_bbox
    bnds = self.bounds.split(",")
    cbounds = []
    c_in, c_out, c_err =
      Open3::popen3("echo #{bnds[0]} #{bnds[1]} | cs2cs +proj=latlong +datum=WGS84 +to +proj=merc +ellps=sphere +a=6378137 +b=6378137 +lat_ts=0.0 +lon_0=0.0 +x_0=0.0 +y_0=0 +k=1.0")
    info = c_out.readlines.to_s
    string,cbounds[0], cbounds[1] = info.match(/([-.\d]+)\s*([-.\d]+).*/).to_a
    c_in, c_out, c_err =
      Open3::popen3("echo #{bnds[2]} #{bnds[3]} | cs2cs +proj=latlong +datum=WGS84 +to +proj=merc +ellps=sphere +a=6378137 +b=6378137 +lat_ts=0.0 +lon_0=0.0 +x_0=0.0 +y_0=0 +k=1.0")
    info = c_out.readlines.to_s
    string,cbounds[2], cbounds[3] = info.match(/([-.\d]+)\s*([-.\d]+).*/).to_a
    cbounds.join(",")
  end
  
  def bbox_centroid
    logger.info 'HEY WHAT NOW 1'
    logger.info bbox_geom
    logger.info 'HEY WHAT NOW 1a'
    centroid =  bbox_geom.nil? ? nil : "#{bbox_geom.centroid.x},#{bbox_geom.centroid.x}"
    logger.info 'HEY WHAT NOW 2'
    
    return centroid
  end
  
  #attempts to align based on the extent and offset of the
  #reference map's warped image
  #results it nicer gcps to edit with later
  def align_with_warped(srcmap, align = nil, append = false)
    srcmap = Map.find(srcmap)
    origgcps = srcmap.gcps.hard

    #clear out original gcps, unless we want to append the copied gcps to the existing ones
    self.gcps.hard.destroy_all unless append == true

    #extent of source from gdalinfo
    stdin, stdout, sterr = Open3::popen3("#{GDAL_PATH}gdalinfo",  srcmap.warped_filename)
    info = stdout.readlines.to_s
    stringLW,west,south = info.match(/Lower Left\s+\(\s*([-.\d]+),\s+([-.\d]+)/).to_a
    stringUR,east,north = info.match(/Upper Right\s+\(\s*([-.\d]+),\s+([-.\d]+)/).to_a

    lon_shift = west.to_f - east.to_f
    lat_shift = south.to_f - north.to_f

    origgcps.each do |gcp|
      a = Gcp.new()
      a = gcp.clone
      if align == "east"
        a.lon -= lon_shift
      elsif align == "west"
        a.lon += lon_shift
      elsif align == "north"
        a.lat -= lat_shift
      elsif align == "south"
        a.lat += lat_shift
      else
        #if no align, then dont change the gcps
      end
      a.map = self
      a.save
    end

    newgcps = self.gcps.hard
  end

  #attempts to align based on the width and height of
  #reference map's un warped image
  #results it potential better fit than align_with_warped
  #but with less accessible gpcs to edit
  def align_with_original(srcmap, align = nil, append = false)
    srcmap = Map.find(srcmap)
    origgcps = srcmap.gcps

    #clear out original gcps, unless we want to append the copied gcps to the existing ones
    self.gcps.hard.destroy_all unless append == true

    origgcps.each do |gcp|
      new_gcp = Gcp.new()
      new_gcp = gcp.clone
      if align == "east"
        new_gcp.x -= srcmap.width

      elsif align == "west"
        new_gcp.x += srcmap.width
      elsif align == "north"
        new_gcp.y += srcmap.height
      elsif align == "south"
        new_gcp.y -= srcmap.height
      else
        #if no align, then dont change the gcps
      end
      new_gcp.map = self
      new_gcp.save
    end

    newgcps = self.gcps.hard
  end
  
  # map gets error attibute set and gcps get error attribute set
  def gcps_with_error(soft=nil)
    unless soft == 'true'
      gcps = Gcp.hard.where(["map_id = ?", self.id]).order(:created_at)
    else
      gcps = Gcp.soft.where(["map_id = ?", self.id]).order(:created_at)
    end
    gcps, map_error = ErrorCalculator::calc_error(gcps)
    @error = map_error
    #send back the gpcs with error calculation
    gcps
  end

  def mask!
    require 'fileutils'
    self.paper_trail_event = 'masking'
    self.update(mask_status: :masking)
    self.paper_trail_event = nil
    format = self.mask_file_format
    
    if format == "geojson"
      return "no mask found, have you created a clipping mask and saved it?"  if !self.masking || self.masking.original.nil?
      mask = self.masking.original
    else
      return "no mask found matching specified format found."
    end

    masked_src_filename = self.masked_src_filename
    if File.exists?(masked_src_filename)
      #deleting old masked image
      File.delete(masked_src_filename)
    end
    #copy over orig to a new unmasked file
    FileUtils.copy(unwarped_filename, masked_src_filename)
    
    command = ["#{GDAL_PATH}gdal_rasterize", "-i", "-b", "1", "-b", "2", "-b", "3", "-burn", "17", "-burn", "17", "-burn", "17", "/vsistdin/",  masked_src_filename]
    logger.debug command

    r_stdout, r_stderr = Open3.capture3( *command, :stdin_data => mask )
    
    r_out  = r_stdout
    r_err = r_stderr
    
    #if there is an error, and it's not a warning about SRS
    if !r_err.blank? #&& r_err.split[0] != "Warning"
      #error, need to fail nicely
      logger.error "ERROR gdal rasterize script: "+ r_err
      logger.error "Output = " +r_out
      r_out = "ERROR with gdal rasterise script: " + r_err + "<br /> You may want to try it again? <br />" + r_out
    else
      r_out = "Success! Map was cropped!"
    end
    self.paper_trail_event = 'masked'
    self.update(mask_status: :masked)
    self.paper_trail_event = nil
    
    r_out
  end
  
  
  
  # FIXME -clear up this method - don't return the text, just raise execption if necessary
  #
  # gdal_rasterize -i -burn 17 -b 1 -b 2 -b 3 SSS.json -l OGRGeoJson orig.tif
  # gdal_rasterize -burn 17 -b 1 -b 2 -b 3 SSS.gml -l features orig.tif

  #Main warp method
  def warp!(resample_option, transform_option, use_mask="false")
    prior_status = self.status
    self.paper_trail_event = 'warping'
    self.update(status: :warping)
    self.paper_trail_event = nil
    gcp_array = self.gcps.hard
    
    gdal_gcp_array = []
    gcp_array.each do |gcp|
      gdal_gcp_array << gcp.gdal_array
    end
    gdal_gcp_array.flatten!

    mask_options_array = []
    if use_mask == "true" && self.mask_status == :masked
      src_filename = self.masked_src_filename
      mask_options_array = ["-srcnodata", "17 17 17"]

      map_mask = Masking.find_or_initialize_by(map_id: self.id)
      map_mask.update(transformed_geojson: convert_mask_to_geojson)
    else
      src_filename = self.unwarped_filename
    end
    
    dest_filename = self.warped_filename
    temp_filename = self.temp_filename
    
    #delete existing temp images @map.delete_images
    if File.exists?(dest_filename)
      #logger.info "deleted warped file ahead of making new one"
      File.delete(dest_filename)
    end
    
    logger.info "gdal translate"
   
    command = ["#{GDAL_PATH}gdal_translate", "-a_srs", "+init=epsg:4326", "-of", "VRT", src_filename, "#{temp_filename}.vrt", gdal_gcp_array].flatten
    logger.info command
    t_stdout, t_stderr = Open3.capture3( *command )
        
    t_out  = t_stdout
    t_err = t_stderr
    
    if !t_err.blank?
      logger.error "ERROR gdal translate script: "+ t_err
      logger.error "Output = " +t_out
      t_out = "ERROR with gdal translate script: " + t_err + "<br /> You may want to try it again? <br />" + t_out
    else
      t_out = "Okay, translate command ran fine! <div id = 'scriptout'>" + t_out + "</div>"
    end
    trans_output = t_out
     
    memory_limit = APP_CONFIG["gdal_memory_limit"].blank? ? [] : ["-wm",  APP_CONFIG['gdal_memory_limit'] ]

    command = ["#{GDAL_PATH}gdalwarp", memory_limit, transform_option.strip.split, resample_option.strip, "-dstalpha", mask_options_array, "-dstnodata", "none", "-s_srs", "EPSG:4326", "#{temp_filename}.vrt", dest_filename, "-co", "TILED=YES", "-co", "COMPRESS=JPEG", "-co", "BIGTIFF=YES"].reject(&:empty?).flatten
    logger.info command
   
    w_stdout, w_stderr = Open3.capture3( *command )
    
    w_out = w_stdout
    w_err = w_stderr
    if !w_err.blank?
      logger.error "Error gdal warp script" + w_err
      logger.error "output = "+w_out
      w_out = "error with gdal warp: "+ w_err +"<br /> try it again?<br />"+ w_out
      raise TransformNotSolveableError if w_err.to_s.include?("Transform is not solvable")
    else
      w_out = "Okay, warp command ran fine! <div id='scriptout'>" + w_out +"</div>"
    end
    warp_output = w_out
    
    # gdaladdo
    command = ["#{GDAL_PATH}gdaladdo", "-r", "average", dest_filename, "2", "4", "8", "16", "32", "64" ]
    o_stdout, o_stderr = Open3.capture3( *command )
    logger.info command
    
    o_out = o_stdout
    o_err = o_stderr
    if !o_err.blank? 
      logger.error "Error gdal overview script" + o_err
      logger.error "output = "+o_out
      o_out = "error with gdal overview: "+ o_err +"<br /> try it again?<br />"+ o_out
    else
      o_out = "Okay, overview command ran fine! <div id='scriptout'>" + o_out +"</div>"
    end
    overview_output = o_out
    
    if File.exists?(temp_filename + '.vrt')
      logger.info "deleted temp vrt file"
      File.delete(temp_filename + '.vrt')
    end
    
    # don't care too much if overviews threw a random warning
    if w_err.size <= 0 and t_err.size <= 0
      if prior_status == :published
        self.status = :published
      else
        self.status = :warped
      end
      Spawnling.new do
        convert_to_png
      end
      self.rectified_at  = Time.now
    else
      self.status = :available
    end
    self.paper_trail_event = 'warped'
    save!
    self.paper_trail_event = nil

    update_layers
    update_bbox
    output = "Step 1: Translate: "+ trans_output + "<br />Step 2: Warp: " + warp_output + \
      "Step 3: Add overviews:" + overview_output
  end
  
  def update_bbox
    
    if File.exists? self.warped_filename
      logger.info "updating bbox..."
      begin
        extents = get_raster_extents self.warped_filename
        self.bbox = extents.join ","
        logger.debug "SAVING BBOX GEOM"
        poly_array = [
          [ extents[0], extents[1] ],
          [ extents[2], extents[1] ],
          [ extents[2], extents[3] ],
          [ extents[0], extents[3] ],
          [ extents[0], extents[1] ]
        ]

        self.bbox_geom = GeoRuby::SimpleFeatures::Polygon.from_coordinates([poly_array]).as_wkt

        save
      rescue Exception => e
        logger.debug e.inspect
      end
    end
  end
  
  def delete_mask
    logger.info "delete mask"

    map_mask = Masking.find_by(map_id: self.id)
    if map_mask
      map_mask.update({original: nil, original_ol:nil})
    end

    self.mask_status = :unmasked
    self.paper_trail_event = 'mask_deleted'
  
    save!
    self.paper_trail_event = nil
    I18n.t('maps.model.delete_mask_success')
  end
  
  
  def save_mask(vector_features)
    if self.mask_file_format == "geojson"
      msg = save_mask_geojson(vector_features)
    else
      msg = I18n.t('maps.model.unknown_mask_format')
    end
    msg
  end
  
  def save_mask_geojson(string)
    #saves geojson to masking and converts to ol
    geojson = JSON.parse(string)
    ol_geojson = JSON.parse(string)

    geojson["features"].each do | feature | 
      feature["geometry"]["coordinates"][0].each do | coord |
        coord[1]  = self.height - coord[1].to_f
      end
    end

    map_mask = Masking.find_or_initialize_by(map_id: self.id)
    map_mask.update({original: JSON.dump(geojson), original_ol: JSON.dump(ol_geojson) })

    message = I18n.t('maps.model.geojson_mask_saved')
  end
  
  
  def self.to_csv
    CSV.generate(:col_sep => ";") do |csv|
      csv <<  ["id", "title", "description", "authors", "bbox", "bbox_centroid", "call_number", "created_at", "updated_at", 
        "date_depicted",  "filename", "import_id", "issue_year", "map_type", "mask_status", "owner_id", "public", 
        "metadata_lat", "metadata_lon", "metadata_projection",
        "publication_place", "published_date", "publisher", "rectified_at", "reprint_date", "scale", "source_uri", "status", 
        "subject_area",  "unique_id",  "upload_content_type",  "upload_file_name", "upload_file_size", "height", "width"] ## Header values of CSV
      all.each do |m |
        csv << [m.id, m.title, m.description, m.authors, m.bbox, m.bbox_centroid, m.call_number, m.created_at, m.updated_at,
          m.date_depicted, m.filename, m.import_id, m.issue_year, m.map_type, m.mask_status, m.owner_id, m.public,
          m.metadata_lat, m.metadata_lon, m.metadata_projection,
          m.publication_place, m.published_date, m.publisher, m.rectified_at, m.reprint_date, m.scale, m.source_uri, m.status,
          m.subject_area, m.unique_id, m.upload_content_type, m.upload_file_name, m.upload_file_size, m.height, m.width          
        ] ##Row values of CSV
      end
    end
  end  

  def has_metadata_location?
    !metadata_lat.blank? && !metadata_lon.blank?
  end

  # 
  # Calls the maps ocr job 
  #
  def run_ocr(force=false, geocode=true)
    # Spawnling will run the job in another thread and return immediately
    # When on Rails 5+ instead of Spawnling, use the async job which uses an in memory queue
    Spawnling.new do
      MapsOcrJob.perform_later(self, force, geocode)
    end
  end
 
  ############
  #PRIVATE
  ############
  
  def convert_to_png
    logger.info "start convert to png ->  #{warped_png_filename}"
    ext_command = ["#{GDAL_PATH}gdal_translate", "-of", "png", warped_filename, warped_png_filename]
    stdout, stderr = Open3.capture3( *ext_command )
    logger.debug ext_command
    if !stderr.blank?
      logger.error "ERROR convert png #{warped_filename} -> #{warped_png_filename}"
      logger.error stderr
      logger.error stdout
    else
      logger.info "end, converted to png -> #{warped_png_filename}"
    end
  end

  #uses geocode.xyz geoparse api
  def find_bestguess_places
    return  {:status => "fail", :code => "geoparse disabled"} if APP_CONFIG["geoparse_enable"] == false 
    
    uri = URI("https://geocode.xyz")
    scantext = ERB::Util.h(self.title.to_s) + " "+ ERB::Util.h(self.description.to_s)
    
    begin
     
      form_data = {'scantext' => scantext, 'geojson' => '1'}
      if !APP_CONFIG["geoparse_region"].blank?
        form_data = form_data.merge({"region"=> APP_CONFIG["geoparse_region"]})
      end
      if !APP_CONFIG["geoparse_geocodexyz_key"].blank?
        form_data = form_data.merge({"auth" => APP_CONFIG["geoparse_geocodexyz_key"]})
      end
           
      req = Net::HTTP::Post.new(uri)
      req.set_form_data(form_data)
      
      res = Net::HTTP.start(uri.hostname, uri.port, :use_ssl => true, :read_timeout => 2) do |http|
        http.request(req)
      end
      
      results = JSON.parse(res.body)
      
      if results["properties"]["matches"].to_i > 0
        places = Array.new
        found_places  = results["features"]
        max_lat, max_lon, min_lat, min_lon = -90.0, -180.0, -90.0, 180.0
        found_places.each do | found_place |
          place_hash = Hash.new
          place_hash[:name] = found_place["properties"]["location"]
          lon = place_hash[:lon] = found_place["geometry"]["coordinates"][0]
          lat = place_hash[:lat] = found_place["geometry"]["coordinates"][1]
          places << place_hash
          
          max_lat = lat.to_f if lat.to_f > max_lat
          min_lat = lat.to_f if lat.to_f < min_lat
          max_lon = lon.to_f if lon.to_f > max_lon
          min_lon = lon.to_f if lon.to_f < min_lon
        end
        
        extents =  [min_lon, min_lat, max_lon, max_lat].join(',')
        if !self.layers.visible.empty? && !self.layers.visible.first.maps.warped.empty?
          sibling_extent = self.layers.visible.first.maps.warped.last.bbox
        else
          sibling_extent = nil
        end
        
        placemaker_result = {:status => "ok", :map_id => self.id, :extents => extents, :count => places.size, :places => places, :sibling_extent=> sibling_extent}
          
      else
        placemaker_result = {:status => "fail", :code => "no results"}
      end
    rescue JSON::ParserError => e
      logger.error "JSON ParserError in find bestguess places " + e.to_s
      placemaker_result = {:status => "fail", :code => "jsonError"}
    rescue Net::ReadTimeout => e
      logger.error "timeout in find bestguess places, probably throttled " + e.to_s
      placemaker_result = {:status => "fail", :code => "timeout"}
    rescue Net::HTTPBadResponse => e
      logger.error "http bad response in find bestguess places " + e.to_s
      placemaker_result = {:status => "fail", :code => "badResponse"}
    rescue SocketError => e
      logger.error "Socket error in find bestguess places " + e.to_s
      placemaker_result = {:status => "fail", :code => "socketError"}
    rescue StandardError => e
      logger.error "StandardError " + e.to_s
      placemaker_result = {:status => "fail", :code => "StandardError"}
    end
    
    return placemaker_result
  end
  
  def clear_cache
    if Rails.application.config.action_controller.perform_caching
      Rails.cache.delete_matched ".*/maps/wms/#{self.id}.png\?status=warped.*"
      Rails.cache.delete_matched "*/maps/tile/#{self.id}/*"
    end
  end

  #takes in the clipping mask file, transforms it to geo and converts to geojson, returning the geojson
  def convert_mask_to_geojson
    if self.gcps.hard.size < 3
      return nil;
    else
      gcp_array = self.gcps.hard

      gdal_gcp_array = []
      gcp_array.each do |gcp|
        gdal_gcp_array << gcp.gdal_array
      end
      gdal_gcp_array.flatten!
      mask = self.masking.original
      command = ["ogr2ogr", "-f", "geojson", "-s_srs", "epsg:4326", "-t_srs", "epsg:3857", gdal_gcp_array, "/dev/stdout",  "/vsistdin/" ].flatten
      logger.info command
      o_out, o_err = Open3.capture3( *command, :stdin_data => mask  )

      if !o_err.blank? 
        logger.error "Error ogr2ogr script" + o_err
        logger.error "output = "+o_out
        return nil;
      end


      return o_out
    end
  end


  def calc_rezize_image(max_dimension)
    img_width = width
    img_height = height

    if width > max_dimension || height  > max_dimension
      if width > height
        dest_width = max_dimension
        dest_height = (dest_width.to_f / width.to_f) * height.to_f
      else
        dest_height = max_dimension
        dest_width = (dest_height.to_f /  height.to_f) * width.to_f
      end
      img_width  = dest_width
      img_height = dest_height
    end

    return img_width, img_height
  end
  
  class TransformNotSolveableError < StandardError
    def message
      "Transform not solveable"
    end
  end
  
  
end
