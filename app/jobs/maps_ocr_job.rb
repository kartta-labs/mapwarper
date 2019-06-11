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
      command = ["convert", "#{filename}[0]", "-resize", "8000x6000\>", "-threshold", "50%", "-trim", "+repage", "-write", processed_img, "-rotate", "90" ,processed_rotate_img  ]
      logger.debug command

      stdout_str, stderr_str, status = Open3::capture3(*command)
      ocr_result = nil
      if stderr_str.blank?
        begin
          response = google_image_annotate(processed_img)
          text = process_text(response)
          response_rotate = google_image_annotate(processed_rotate_img)
          text_rotate = process_text(response_rotate)

          ocr_result = text.map {|a| a.downcase}.join(" ") + text_rotate.map {|a| a.downcase}.join(" ") 

          logger.debug "ocr result = #{ocr_result}"

          map.ocr_result = ocr_result
          map.save
      rescue StandardError => e
        logger.error "ERROR with Google Image Annotate StandardError " + e.to_s
      end
  
    
        geocode_map(map) if geocode && !ocr_result.blank?
      else
        logger.error "ERROR with OCR command out #{stdout_str} err #{stderr_str.inspect} status #{status}"
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

    response
  end
  

  def geocode_map(map)
    scantext = map.ocr_result + " " + map.description

    geocode_result = call_google_geocode(scantext)
    map.geocode_result = geocode_result unless geocode_result.nil? || geocode_result["status"] == "fail" 
    map.save
  end


  def call_google_geocode(scantext)
    region = "US"
    components= "country:US"
    key = APP_CONFIG["google_maps_key"]
    #uri = URI("https://maps.googleapis.com/maps/api/geocode/json?address=#{scantext}&region=#{region}&components=#{components}&key=#{key}")
    uri = URI("https://maps.googleapis.com/maps/api/geocode/json?address=#{scantext}&region=#{region}&key=#{key}")
    req = Net::HTTP::Get.new(uri)

    result = nil

    begin
      res = Net::HTTP.start(uri.hostname, uri.port, :use_ssl => true, :read_timeout => 2) do |http|
        http.request(req)
      end

      result = JSON.parse(res.body)

      if result["status"] == "ZERO_RESULTS"
        result = {"status" => "fail", "code" => "noResults"}
      end

    rescue JSON::ParserError => e
      logger.error "JSON ParserError in find call_google_geocode places " + e.to_s
      result = {"status" => "fail", "code" => "jsonError"}
    rescue Net::ReadTimeout => e
      logger.error "timeout in find call_google_geocode places, probably throttled " + e.to_s
      result = {"status" => "fail", "code" => "timeout"}
    rescue Net::HTTPBadResponse => e
      logger.error "http bad response in call_google_geocode places " + e.to_s
      result = {"status" => "fail", "code" => "badResponse"}
    rescue SocketError => e
      logger.error "Socket error in call_google_geocode " + e.to_s
      result = {"status" => "fail", "code" => "socketError"}
    rescue StandardError => e
      logger.error "StandardError " + e.to_s
      result = {"status" => "fail", "code" => "StandardError"}
    end

    logger.debug "google geocode result = #{result}"

    result.to_json
  end


  def numeric?(str)
    return true if str =~ /\A\d+\z/
    true if Float(str) rescue false
  end

end
