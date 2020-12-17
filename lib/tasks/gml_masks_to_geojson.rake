namespace :warper do
  desc "converts gml masks files to geojson masks and stores in database"
  task(:gml_masks_to_geojson => :environment) do
    puts
    count = 0
    maps = Map.all
    maps.each do |map|
      reg_geojson = nil
      ol_geojson = nil
      if File.exists?(map.masking_file_gml)
        reg_command =["ogr2ogr", "-f", "geojson", "/dev/stdout", map.masking_file_gml]
        reg_out, reg_err = Open3.capture3( *reg_command )

        if !reg_err.blank? 
          puts "Error ogr2ogr script" + reg_err
          puts "output = "+reg_out
          reg_out = nil
        end

        reg_geojson = reg_out 
      end

      if File.exists?(map.masking_file_gml+".ol")
        ol_command =["ogr2ogr", "-f", "geojson", "/dev/stdout", map.masking_file_gml+".ol"]
        ol_out, ol_err = Open3.capture3( *ol_command )

        if !ol_err.blank? 
          puts "Error ogr2ogr script" + ol_err
          puts "output = "+ol_out
          ol_out = nil
        end

        ol_geojson = ol_out 
      end
      
      if reg_geojson || ol_geojson
        puts "reg #{reg_geojson} ol #{ol_geojson}"
        map_mask = Masking.find_or_initialize_by(map_id: map.id)
        map_mask.update({original: reg_geojson, original_ol: ol_geojson })
        count  = count + 1
      end
     

    end
        
    puts "\n Count = #{count} maps done"
  end
end
