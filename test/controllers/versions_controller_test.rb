require 'test_helper'
require 'database_cleaner'

class VersionsControllerTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers
  tests  VersionsController
  PaperTrail.enabled = true
  PaperTrail.request.enabled = true
  self.use_transactional_fixtures = false
  DatabaseCleaner.strategy = :truncation

  def setup 
    @map = FactoryGirl.create(:available_map)
 
  end

  teardown do
    DatabaseCleaner.clean
  end

  test "revert not allowed by normal user" do
    new_title = "Warped map v2"
    @map.title =  new_title 
    @map.save

    gcp = Gcp.new(:x => 123, :y =>234,:lat=>1.1, :lon=>1.2)
    gcp.map = @map
    gcp.save

    normal_user_sign_in
    version_id = @map.versions[-1].id
    
    patch :revert_map, id: version_id
    
    assert_response :redirect 
    assert_redirected_to root_path
    assert flash[:error].include?("Sorry you do not have permission")
  end

  test "revert allowed by admin" do
    new_title = "Warped map v2"
    @map.title =  new_title 
    @map.save

    gcp = Gcp.new(:x => 123, :y =>234,:lat=>1.1, :lon=>1.2)
    gcp.map = @map
    gcp.save

    gcp2 = Gcp.new(:x => 222, :y =>222,:lat=>2.2, :lon=>2.2)
    gcp2.map = @map
    gcp2.save

    gcp3 = Gcp.new(:x => 333, :y =>333,:lat=>3.3, :lon=>3.3)
    gcp3.map = @map
    gcp3.save


    assert_equal 5, @map.versions.size
    assert_equal 3, @map.gcps.size
    assert_equal true, @map.gcps.include?(gcp3)

    admin_sign_in
    version_id = @map.versions[-1].id
    put :revert_map, id: version_id
    assert_response :redirect 
    assert flash[:notice].include?("Map Reverted")
    assert_redirected_to activity_details_path
    assert_equal 2, @map.gcps.size
    assert_equal false, @map.gcps.include?(gcp3)

end

end
  

