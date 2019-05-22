require 'database_cleaner'

class ActiveSupport::TestCase
  self.use_transactional_fixtures = false
  DatabaseCleaner.strategy = :truncation
  Map.attachment_definitions[:upload][:path] = "#{Rails.root}/public/test/:attachment/:id/:style/:basename.:extension"
  #Paperclip::Attachment.default_options[:path] = "#{Rails.root}/public/test/:attachment/:id/:style/:basename.:extension"

  WebMock.allow_net_connect!
  
  # Cleans the db after each test
  teardown do
    DatabaseCleaner.clean
  end

end