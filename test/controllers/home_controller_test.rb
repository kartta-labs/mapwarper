require 'test_helper'

class HomeControllerTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers
  tests  HomeController

  test "provider user with profile is ok" do
    user = FactoryGirl.create(:provider)
    request.env["devise.mapping"] = Devise.mappings[:provider]
    sign_in user
    
    get :index

    assert_response :success
  end

  test "provider user without profile is redirected" do
    user = FactoryGirl.create(:provider_no_login)
    request.env["devise.mapping"] = Devise.mappings[:provider_no_login]
    sign_in user
    
    get :index

    assert_response :redirect
    assert flash[:error].include?("display name")
    assert_redirected_to edit_user_registration_path(user)
  end

end