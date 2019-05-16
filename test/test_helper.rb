ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'
require 'webmock/minitest'
#require "mocha/test_unit"
require 'mocha/minitest'
require 'capybara/rails'

FileUtils.cp(Dir[File.join(Rails.root, "/test/fixtures/data/*.tif")].select {|f| test ?f, f}, File.join(Rails.root, "/test/fixtures/data/src/"))

Minitest.after_run do
  FileUtils.rm(Dir.glob(File.join(Rails.root, "/test/fixtures/data/src/*")))
  FileUtils.rm(Dir.glob(File.join(Rails.root, "/test/fixtures/data/tileindex/*")))
end

class ActiveSupport::TestCase
  include FactoryGirl::Syntax::Methods 
  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all
  
  Map.auditing_enabled = false
  Gcp.auditing_enabled = false

  Object.send(:remove_const, :SRC_MAPS_DIR)
  Object.const_set("SRC_MAPS_DIR", File.join(Rails.root, "/test/fixtures/data/src/"))
  Object.send(:remove_const, :DST_MAPS_DIR)
  Object.const_set("DST_MAPS_DIR", File.join(Rails.root, "/test/fixtures/data/dst/"))
  
  Object.send(:remove_const, :TILEINDEX_DIR)
  Object.const_set("TILEINDEX_DIR", File.join(Rails.root, "/test/fixtures/data/tileindex/"))

  Paperclip::Attachment.default_options[:path] = "#{Rails.root}/test/test_files/:class/:id_partition/:style.:extension"
  


  def admin_sign_in
    admin_user = FactoryGirl.create(:admin)
    request.env["devise.mapping"] = Devise.mappings[:admin]
    sign_in admin_user
  end
  
  def normal_user_sign_in
    user = FactoryGirl.create(:user)
    request.env["devise.mapping"] = Devise.mappings[:user]
    sign_in user
  end
  
   def editor_user_sign_in
    user = FactoryGirl.create(:editor)
    request.env["devise.mapping"] = Devise.mappings[:editor]
    sign_in user
  end
end

 #from http://stackoverflow.com/questions/4901306/how-can-i-mute-rails-3-deprecation-warnings-selectively
 #we are doing it manually anyhow..
 module ActiveSupport
  class Deprecation
    module Reporting
      # Mute specific deprecation messages
      def warn(message = nil, callstack = nil)
        return if message.match(/Automatic updating of counter caches/)

        super
      end
    end
  end
end

 class WordArray
   def self.word_seq(n)
     @@words ||= get_words

     @@words[n]
   end

   # this path may not be on all systems, but should be common across *nix ones
   def self.get_words
     File.read('/usr/share/dict/words').lines.select {|l| (5..15).cover?(l.strip.size) }.sample(160).sort_by(&:downcase).collect(&:strip)
   end
 end


 require 'capybara/rails'
 require 'capybara/minitest'
 require 'capybara/minitest/spec'

 class ActionDispatch::IntegrationTest
   # Make the Capybara DSL available in all integration tests
   include Capybara::DSL
   # Make `assert_*` methods behave like Minitest assertions
   include Capybara::Minitest::Assertions

   # Reset sessions and driver between tests
   teardown do
     Capybara.reset_sessions!
     Capybara.use_default_driver
   end
 end
