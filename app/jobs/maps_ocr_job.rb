class MapsOcrJob < ActiveJob::Base
  require "google/cloud/vision"
  require "open3"

  queue_as :default

  #force to force ocr 
  #geocode to do the geocoding
  def perform(map, force=false, geocode=true)

    filename = nil
    if map.mask_status == :masked
      filename = map.masked_src_filename
    else
      filename = map.unwarped_filename
    end

    return if filename.nil?

    # Don't ocr this map again if there is already a result, unless the force param is set to true
    if force == false && !map.ocr_result.nil? && geocode
      geocode_map(map)
    else

      processed_img = filename + ".ocr.jpg"
      processed_rotate_img = filename + ".rot.ocr.jpg"

      #resize makes it smaller. -threshold black and whites it, -trim and +repage "auto crops it", -write saves the first image, -rotate rotates it and finally saves the file
      command = "convert #{filename}[0] -resize 8500x6000 -threshold 50% -trim +repage -write #{processed_img} -rotate 90 #{processed_rotate_img}"
      logger.debug command

      stdout_str, stderr_str, status = Open3::capture3(command)
      #puts "out #{stdout_str} err #{stderr_str.inspect} status #{status}"
      if stderr_str.blank?
      response = google_image_annotate(processed_img)
      text = process_text(response)
      response_rotate = google_image_annotate(processed_rotate_img)
      text_rotate = process_text(response_rotate)

      ocr_result = text.map {|a| a.downcase}.join(" ") + text_rotate.map {|a| a.downcase}.join(" ") 

      logger.debug ocr_result

      map.ocr_result = ocr_result
      map.save
  
      geocode_map(map) if geocode
      else
        logger.error "ERROR out #{stdout_str} err #{stderr_str.inspect} status #{status}"
      end

    end


  end


  def process_text(response)
    tt = []
    response.responses.each do |res|
      res.text_annotations.each do |text|
        tt << text.description
      end
    end
    tt.shift unless Rails.env == "test" #remove the first item as this contains everything

    text = tt.map { |a | a.gsub(/[^0-9A-Za-z]/, '')}  #remove special characters
    text.keep_if {|a| a == a.upcase}     # keep the UPPERCASE strings as these are road names
    text.delete_if {|a| a.length <= 2 }  #remove the small hits 
    text.delete_if{|aa| aa.match(/\d/)}  #remove strings with numbers in them


    return text 
  end

  def google_image_annotate(image)
    image_annotator = Google::Cloud::Vision::ImageAnnotator.new(credentials: APP_CONFIG["google_json_key_location"])

    response = image_annotator.text_detection(
      image: image,
      image_context: {:language_hints => ["en"]},
      max_results: 1 # optional, defaults to 10
    )
      puts response

    return response
  end
  

  def geocode_map(map)
    scantext = map.ocr_result + " " + map.description

    map.geocode_result = call_google_geocode(scantext)

    unless map.geocode_result.nil?
      map.save
    end 
  end


  def call_google_geocode(scantext)
    region = "US"
    components= "country:US"
    key = APP_CONFIG["google_maps_key"]
    uri = URI("https://maps.googleapis.com/maps/api/geocode/json?address=#{scantext}&region=#{region}&components=#{components}&key=#{key}")
    req = Net::HTTP::Get.new(uri)

    result = nil

    begin
      res = Net::HTTP.start(uri.hostname, uri.port, :use_ssl => true, :read_timeout => 2) do |http|
        http.request(req)
      end

      result = JSON.parse(res.body)

    rescue JSON::ParserError => e
      logger.error "JSON ParserError in find call_google_geocode places " + e.to_s
      result = {:status => "fail", :code => "jsonError"}
    rescue Net::ReadTimeout => e
      logger.error "timeout in find call_google_geocode places, probably throttled " + e.to_s
      result = {:status => "fail", :code => "timeout"}
    rescue Net::HTTPBadResponse => e
      logger.error "http bad response in call_google_geocode places " + e.to_s
      result = {:status => "fail", :code => "badResponse"}
    rescue SocketError => e
      logger.error "Socket error in call_google_geocode " + e.to_s
      result = {:status => "fail", :code => "socketError"}
    rescue StandardError => e
      logger.error "StandardError " + e.to_s
      result = {:status => "fail", :code => "StandardError"}
    end

  
    puts result.inspect

    result
  end

  
  def call_geoparsexyz(scantext)

    return nil if APP_CONFIG["geoparse_enable"] == false 
      
    uri = URI("https://geocode.xyz")
    
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
        end
      
        result = {:status => "ok", :map_id => map.id, :count => places.size, :places => places}
          
      else
        result = {:status => "fail", :code => "no results"}
      end
    rescue JSON::ParserError => e
      logger.error "JSON ParserError in call_geoparsexyz " + e.to_s
      result = {:status => "fail", :code => "jsonError"}
    rescue Net::ReadTimeout => e
      logger.error "timeout in  call_geoparsexyz places, probably throttled " + e.to_s
      result = {:status => "fail", :code => "timeout"}
    rescue Net::HTTPBadResponse => e
      logger.error "http bad response in  call_geoparsexyz places " + e.to_s
      result = {:status => "fail", :code => "badResponse"}
    rescue SocketError => e
      logger.error "Socket error in  call_geoparsexyz places " + e.to_s
      esult = {:status => "fail", :code => "socketError"}
    rescue StandardError => e
      logger.error "StandardError " + e.to_s
      result = {:status => "fail", :code => "StandardError"}
    end
      
    puts result

    result
  end

  def numeric?(str)
    return true if str =~ /\A\d+\z/
    true if Float(str) rescue false
  end

end
