require 'test_helper'

class GcpsControllerTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers
  tests GcpsController

  setup do
    @available_map = FactoryGirl.create(:available_map)
    @user = FactoryGirl.create(:user)
    request.env["devise.mapping"] = Devise.mappings[:user]
    sign_in @user
  end

 
  test "add_corner_gcps" do
    post 'corner_coords', :mapid => @available_map.id , :coords => [{corner: "tr", lon: 12, lat:44 },{corner: "tl", lon: 33, lat:11 }].to_json, :format => :json
    
    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal 2, body["items"].size
    assert_equal "tr", body["items"].first["name"]
  end
end