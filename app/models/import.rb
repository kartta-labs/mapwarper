class Import < ActiveRecord::Base
  require 'csv'
  
  has_many :maps
  belongs_to :layer
  belongs_to :user, :class_name => "User"
  has_and_belongs_to_many :layers

  has_attached_file :metadata,
    path: ":rails_root/db/:class/:attachment/:id_partition/:filename", 
    preserve_files: false,
    restricted_characters: /[&$+,\/:;=?@<>\[\]\{\}\)\(\'\"\|\\\^~%# ]/,
    :fog_public => false
  
  validates_attachment_content_type :metadata, content_type: ["text/csv", "text/plain"]
  validates_presence_of :metadata, :message => :no_file_uploaded
  
  acts_as_enum :status, [:ready, :running, :finished, :failed]

  after_initialize :default_values
  after_destroy :delete_logfile
  
  def default_values
    self.status ||= :ready
    self.imported_count ||= 0
    self.file_count = dir_file_count
  end
  
  def logfile
    "import-#{id}-#{Time.new.strftime('%Y-%m-%d-%H%M%S')}.log"
  end
  
  def log_path
    "#{Rails.root}/log/imports/#{log_filename}"
  end

  def import_logger
    @import_logger ||= Logger.new(log_path)
  end

  
  def prepare_run
    self.update_attribute(:status, :running)
    self.update_attribute(:log_filename, logfile)
    import_logger.info "prepared run"
  end
  
  def finish_import(options)
    self.status = :finished
    self.finished_at = Time.now
    self.save
    save_maps_to_layers unless self.maps.empty? || self.save_layer == false || self.layer_ids.empty?
    log_info "Finished import #{Time.now}"
  end
  
  def import!(options={})
    options = {:async => false}.merge(options)
    
    async = options[:async]
    if valid? && file_count > 0
      prepare_run unless async
      log_info "Stared import #{Time.now}"
      begin
        import_maps
        finish_import(options)
      rescue => e
        log_error "Error with import #{e.inspect}"
        log_error e.backtrace
        
        self.status = :failed
        self.save
      end
      
    else
      log_error "Import not run"
      log_error "CSV File was either not valid or there were no files in the directory"
      self.status = :failed
      self.save
    end
    
    self.status
  end
  
  def import_maps
    local_copy = File.join("tmp", self.metadata_file_name)
    self.metadata.copy_to_local_file(nil, local_copy)
    data = open(local_copy)
    map_data = CSV.parse(data, :headers => true, :header_converters => :symbol, :col_sep => "," , :quote_char => '"')
    map_data.by_row!
    map_data.each do  | map_row |
      uuid = map_row[:uuid]
      if Map.exists?(unique_id: uuid)
        map = Map.find_by_unique_id(uuid)
        map.import_id = self.id
        log_info "Map already exists. Adding it to the import" + map.inspect
        map.save
        next
      end
      filename = map_row[:filename]
      file_base =  APP_CONFIG['import_maps_sftp_path']+"/"+filename
      next if Dir.glob(file_base).empty?
      upload_filename = Dir.glob(file_base).first
     
      published_date = map_row[:published_date]
      issue_year = map_row[:issue_year] 
      date_depicted = map_row[:date_depicted]
      
      date_depicted = issue_year if date_depicted.blank?
    
      description = map_row[:description]

      #example of using custom fields in csv to build out description
      #unless map_row[:additional_information].blank?
       # description = description +  " Additional Information: " + map_row[:additional_information]
      #end


      tag_list = map_row[:tag_list]
      subject_area = map_row[:subject_area] 
      publisher = map_row[:publisher] 
      authors = map_row[:authors] 
      source_uri = map_row[:source_uri] 
      scale = map_row[:scale]
      published_date =  map_row[:published_date]
      reprint_date = map_row[:reprint_date]
      publication_place = map_row[:publication_place]
      metadata_projection = map_row[:metadata_projection]
      metadata_lat = map_row[:lat]
      metadata_lon = map_row[:lon]
      call_number = map_row[:call_number]

      map = {
        title: map_row[:title],
        description: description,
        date_depicted: date_depicted,
        issue_year: issue_year,
        source_uri: source_uri,
        tag_list: tag_list,
        subject_area: subject_area,
        publisher: publisher,
        authors: authors,
        scale: scale,
        published_date: published_date,
        reprint_date: reprint_date,
        publication_place: publication_place,
        metadata_projection: metadata_projection,
        metadata_lat: metadata_lat,
        metadata_lon: metadata_lon, 
        call_number: call_number,
        unique_id: uuid,
        status: :unloaded,
        map_type: 'is_map',
        public: true
      } 
      map = Map.new(map)
      map.upload = File.new(upload_filename)

      map.import_id = self.id
      map.owner = self.user
      map.users << self.user
      if map.save
        log_info "Saved new Map" + map.inspect
        Import.increment_counter(:imported_count, self.id)
      else
        log_info "Didn't save new Map" + map.inspect
        log_info "Errors" + map.errors.messages.inspect
      end
    end

  end

  def save_maps_to_layers
    log_info "Saving maps to layers"
    ids = self.layer_ids.split(",")
    layers = Layer.find(ids)
    layers.each do | layer |
      log_info "adding maps to layer"
      maps_to_add = self.maps.select{ |map| !layer.maps.include?(map)}
      layer.maps << maps_to_add
      save
    end
    log_info "finished saving maps to layers"
  end

  
  #counts number of files in the directory 
  def dir_file_count
    directory = APP_CONFIG['import_maps_sftp_path']
    count =  Dir[File.join(directory, '**')].count { |file| File.file?(file) }

    return count
  end
  
  protected

  def update_count
    file_count = dir_file_count
  end
  

  def log_info(msg)
    puts msg  if defined? Rake
    import_logger.info msg
  end
  
  def log_error(msg)
    puts msg  if defined? Rake
    import_logger.error msg
  end
  
  
  def delete_logfile
    if log_filename && log_filename.include?(".log") && File.exists?("#{Rails.root}/log/imports/#{log_filename}")
      File.delete("#{Rails.root}/log/imports/#{log_filename}")
    end
  end

end
