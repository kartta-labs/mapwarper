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

      #we can have larger images if saving to the bucket
      resize = "7500x6000\>"
      if !APP_CONFIG["ocr_bucket"].blank?
        resize = "11000x11000\>"
      end
      #resize makes it smaller. -threshold black and whites it, -trim and +repage "auto crops it"
      command = ["convert", "#{filename}[0]", "-resize", resize, "-threshold", "50%", "-trim", "+repage",  processed_img ]
      logger.debug command

      stdout_str, stderr_str, status = Open3::capture3(*command)
      ocr_result = nil
      if stderr_str.blank?
        begin
          response = google_image_annotate(processed_img)
          text = process_text(response)

          text.uniq!

          ocr_result = text.map {|a| a.downcase}.join(" ") 
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

      #delete the ocr images
      File.delete processed_img if File.exists? processed_img
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
    keep_suffixes = %w(CP CT CV CY DL DR DV FT GN HL IS LF LN ML MT PL PT RD SQ ST UN VW YU AVE JCT PKY PLZ STA VIA VLY WAY BTM BLF ARC ALY FWY THE AND ICE PUB PAN END WAY)
    text.delete_if {|a| a.length <= 3 unless keep_suffixes.include? a }  #remove the small hits except for the useful ones
    text.delete_if {|a| a.match(/\d/)}  #remove strings with numbers in them
    exclude_words = %w(division map zone zones height restriction restrictions property plate section part building garage)
    text.delete_if {|a| exclude_words.include? a.downcase }
    
    return text 
  end

  def google_image_annotate(image)
    image_annotator = Google::Cloud::Vision::ImageAnnotator.new(credentials: APP_CONFIG["google_json_key_location"])
  
    if !APP_CONFIG["ocr_bucket"].blank?
      connection = Fog::Storage::Google.new(
        google_project: APP_CONFIG["google_storage_project"],
        google_json_key_location:  APP_CONFIG["google_json_key_location"]
      )

     connection.put_object(APP_CONFIG["ocr_bucket"],  File.basename(image), File.open(image))

     image = "gs://#{APP_CONFIG["ocr_bucket"]}/#{File.basename(image)}"
    end

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
