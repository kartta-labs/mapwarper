namespace :warper do
  desc "starts an import rake warper:import ID=3" 
  task :import_nypl =>  :environment  do |t, args|
    require "json"
    require "open3"

    puts "Starts an import from the NYPL Metadata. Pass in or set env NYPL_METADATA_FILE=/mnt/metadata.json and NYPL_MAPS_DIR=/mnt/maps"
    puts "USAGE rake 'warper:import_nypl NYPL_METADATA_FILE=/mnt/metadata.json NYPL_MAPS_DIR=/mnt/maps' where x is the ID of an import in the ready state"
    metadata_file = ENV['NYPL_METADATA_FILE']  || nil
    nypl_maps_dir = ENV['NYPL_MAPS_DIR']  || nil
    
    break unless metadata_file && nypl_maps_dir

    break unless File.exist? metadata_file
    puts "Reading in from #{metadata_file}"
    
    print "Are you sure you want to continue ? [y/N] "
    break unless STDIN.gets.match(/^y$/i)
    count = 0
    maps_items = JSON.parse(File.read(metadata_file))
    maps_items.each do | m | 
      print "."
     
      if ENV['MAX_MAPS_COUNT'] && count >= ENV['MAX_MAPS_COUNT'].to_i
        puts ""
        puts "stopping after #{count} maps saved"
        break
      end 

      uuid = m["uuid"]

      if Map.exists?(unique_id: uuid)
        puts "INFO Map already exists. Skipping #{uuid}"
        next
      end

      description = m["subtitle"].nil? ? "" :  m["subtitle"].compact.join(". ")
     
      file_base =  nypl_maps_dir+"/"+uuid
      next if Dir.glob(file_base).empty?
      upload_filename = File.join(file_base +"/highres.tiff")
      unless File.exists? upload_filename
        puts "INFO Map image file doesnt exist at #{upload_filename} Skipping #{uuid}"
        next
      end
       
      date_depicted = nil
      issue_year = nil

      if m["dateCreated"]
        date_depicted = m["dateCreated"][0]["date"][0..3].to_i
        if m["dateCreated"].length > 1
          keydates = m["dateCreated"].select{|d| d["keyDate"]}
          if keydates.length > 1 && !keydates.blank?
            date_depicted = keydates.min_by{|d| d["date"][0..3].to_i }["date"]
          else
            date_depicted = m["dateCreated"].min_by{|d| d["date"][0..3].to_i}["date"]
          end
        end
      end

      if m["dateIssued"]
        issue_year = m["dateIssued"][0]["date"][0..3].to_i
        if m["dateIssued"].length > 1
          issue_keydates = m["dateIssued"].select{|d| d["keyDate"]}
          if issue_keydates.length > 1 && !issue_keydates.blank?
            issue_year = issue_keydates.min_by{|d| d["date"][0..3].to_i }["date"]
          else
            issue_year = m["dateIssued"].min_by{|d| d["date"][0..3].to_i}["date"]
          end
        end
      end

      #set the date depicted to issue year if its not there
      if issue_year && date_depicted.nil?
        date_depicted = issue_year
      end

      publisher =  m["publisher"].nil? ? nil : m["publisher"].compact.join(". ")
      tags = m["place"].nil? ? nil : m["place"].compact.join(",")
      title = m["title"].nil? ? nil : m["title"].compact.join(". ")
      source_uri = "https://digitalcollections.nypl.org/items/#{uuid}"
     
      map = Map.new(
        unique_id: uuid,
        tag_list: tags,
        title: title,
        description: description,
        date_depicted: date_depicted,
        issue_year: issue_year,
        publisher: publisher,
        source_uri: source_uri
      )
      map.upload = File.new(upload_filename)
      map.upload.instance_write(:file_name, "#{uuid}.tiff")
      map.owner = Role.find_by_name('administrator').users.last

      # if date_depicted.nil? && issue_year.nil?
      #   puts "INFO no date found"
      #   puts m.inspect
      # end
      # TODO get from layer?

      if map.valid?
        puts "INFO Saving new map #{uuid}"
        map.save
        count  = count + 1
      else
        puts "ERROR Map Invalid"    
        puts m.inspect 
        puts map.errors.inspect
        puts "----"
        next
      end

      if m["mapwarper"] && m["mapwarper"]["coordinates"]
        coords = m["mapwarper"]["coordinates"].reverse.map {|c| [c["lng"], c["lat"]] }
        geojson = {
          "type": "FeatureCollection",
             "features": [ 
               {
                "type": "Feature", "properties": { "gml_id": "#{uuid}" },
                "geometry": {
                  "type": "Polygon", "coordinates": [coords]
                }
               }
             ]
        }

        command =["ogr2ogr", "-f", "geojson", "-s_srs", "epsg:4326", "-t_srs", "epsg:3857", "/dev/stdout", "/vsistdin/"]
        o_out, o_err = Open3.capture3( *command, :stdin_data => geojson.to_json )

        if !o_err.blank? 
          puts "Error ogr2ogr script" + o_err
          puts "output = "+o_out
          o_out = nil
        end

        transformed_geojson = o_out 
      
        puts "INFO Saving geojson maskings for map id: #{map.id}"
        #save the maskings:
        Masking.find_or_initialize_by(map_id: map.id).update(transformed_geojson: transformed_geojson, geojson: geojson)

      end #if coordinates
 
      
    end  #each map item
     puts ""
     puts "#{count} maps saved"
  end
end


