require 'test_helper'

class MapsControllerTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers
  tests  MapsController

  setup do
    @available_map = FactoryGirl.create(:available_map, :issue_year => 1950, :description => "available description" )
    @warped_map = FactoryGirl.create(:warped_map, :upload_file_name => "different.png",  :issue_year => 1850, :title => "warped", :description => "warped description")
  end

  test "index all maps" do
    get :index
    assert_response :success
    @maps = assigns(:maps)
   
    assert_not_nil @maps
    assert @maps.length == 2
  end
  
  test "show one map" do
    get :show, :id => @available_map.id
    assert_response :success
    @map = assigns(:map)

    assert_not_nil @map
    assert_equal @available_map.title, @map.title
  end
  
  test "publish not allowed by admin" do
    normal_user_sign_in
    get :publish, :to => "publish", :id => @available_map.id
    assert_response :redirect
        
    assert_redirected_to root_path
    assert flash[:error].include?("Sorry you do not have permission")
  end
       
 
  test "publish allowed by admin" do
    Map.any_instance.stubs(:tilestache_seed).returns(true)
    admin_sign_in
   
    get :publish, :to => "publish", :id => @warped_map.id
    assert_response :redirect
    assert_redirected_to @warped_map
    
    @map = assigns(:map)
    assert_equal :publishing, @map.status
    
    assert_redirected_to @map
    assert flash[:notice].include?("Map publishing")
  end
  

  
  test "search for map via title" do
    get :index, :field => "title", :query => "title"
    index_maps = assigns(:maps)
    assert index_maps.include? @available_map
  end
  
  test "search for map via description" do
    get :index, :field => "description", :query => "available"
    index_maps = assigns(:maps)
    assert index_maps.include? @available_map
    
    get :index, :field => "description", :query => "warped"
    index_maps = assigns(:maps)
    assert_equal false, index_maps.include?(@available_map)
    
  end
  
  test "search for map via text" do
    get :index, :field => "text", :query => "title"
    index_maps = assigns(:maps)
    assert index_maps.include? @available_map
    
    get :index, :field => "text", :query => "warped"
    index_maps = assigns(:maps)
    assert index_maps.include? @warped_map
  end
  
  test "search/index maps for year" do
    get :index, :from => 1800, :to => 2000
    index_maps = assigns(:maps)
    
    assert index_maps.include? @available_map
    assert index_maps.include? @warped_map
    
    get :index, :from => 1800, :to => 1900
    index_maps = assigns(:maps)
    
    assert_equal false, index_maps.include?(@available_map)
    assert index_maps.include? @warped_map
  end

  test "quick only for logged in users" do
    get :quick, :id => @available_map
    assert_response :redirect
    assert_redirected_to :new_user_session

    normal_user_sign_in
    get :quick, :id => @available_map
    assert_response :success
  end

  test "quick redirect if has gcps" do
    normal_user_sign_in
    FactoryGirl.create(:gcp_1, :map => @available_map)
    FactoryGirl.create(:gcp_2, :map => @available_map)
    FactoryGirl.create(:gcp_3, :map => @available_map)

    get :quick, :id => @available_map
    assert_response :redirect
    assert_redirected_to @available_map
    assert flash[:notice].include?("Sorry")
  end

  test "quick for maps with no gcps" do
    normal_user_sign_in
    assert 0, @available_map.gcps.size

    get :quick, :id => @available_map
    assert_response :success
  end

  test "can show list of all quick maps" do
    normal_user_sign_in
    get :quick_index

    maps = assigns(:maps)

    assert maps.include? @available_map
    assert_equal false, maps.include?(@warped_map)
    assert_response :success
  end

end
