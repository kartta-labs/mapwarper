namespace :warper do
  desc "Runs ocr job on a map rake warper:run_ocr ID=3 " 
  task :run_map_ocr =>  :environment  do |t, args|

    puts "Runs ocr job on a map. Pass in ID for the ID of the map to ru "

    map_id = ENV['ID']  || nil
    break unless map_id

    map = Map.find map_id
    break unless map
    puts "Running OCR for map #{map.id}"
    map.run_ocr(force=true, geocode=true)

    puts "Ocr Result"
    puts map.reload.ocr_result.inspect

    puts "Geocode Result"
    puts map.reload.geocode_result
   
  end

  desc "Runs ocr job for all maps  "
  task :run_all_maps_ocr =>  :environment  do |t, args|

    puts "Runs ocr job all maps. Optionally pass in FORCE=true to force OCR on all maps even if they have a result. Optionally Pass in GEOCODE=false to disable geocoding of results"

    force = ENV['FORCE']  || false
    geocode =  ENV['GEOCODE']  || true

    count = Map.where(ocr_result: nil).count
    count = Map.all.count  if force

    puts "This will apply to #{count} maps"
    print "Are you sure you want to continue ? [y/N] "
    break unless STDIN.gets.match(/^y$/i)

    if force
      maps = Map.all
    else
      maps = Map.where(ocr_result: nil)
    end

    maps.each do | map |
      puts "Running OCR for map #{map.id}"
      map.run_ocr(force=force, geocode=geocode)
      puts "Ocr Result"
      puts map.reload.ocr_result.inspect

      puts "Geocode Result"
      puts map.reload.geocode_result

      puts "---"
   end

  end 

end


