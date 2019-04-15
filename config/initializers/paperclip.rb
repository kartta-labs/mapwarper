Paperclip.options[:content_type_mappings] = {
   jpeg: %w( application/octet-stream ),
   jpg: %w( application/octet-stream )
}

if !APP_CONFIG["public_shared_dir"].blank?
  Map.attachment_definitions[:upload][:url] =  "/#{APP_CONFIG['public_shared_dir']}/:attachment/:id/:style/:basename.:extension"
end

if APP_CONFIG["google_storage_enabled"]
  #clear the path for Import as the one defined in the import model is for normal file storage 
  Import.attachment_definitions[:metadata].delete(:path)

  Paperclip::Attachment.default_options.merge!(
    storage: :fog,
    fog_credentials: {
      provider: 'Google',
      google_project: APP_CONFIG["google_storage_project"],
      google_json_key_location:  APP_CONFIG["google_json_key_location"]
    },
    fog_attributes: { cache_control: "public, max-age=#{365.days.to_i}" },
    fog_directory: APP_CONFIG["google_storage_bucket"],
    path: ":class/:attachment/:id_partition/:style/:filename"
  )

end


