require 'test_helper'
require 'integration_test_helper'

#specific test: ruby -Ilib:test test/integration/home_test.rb -n /geosearch/

class HomeTest < ActionDispatch::IntegrationTest

  setup do
    @warped_map = FactoryGirl.create(:warped_map_with_upload)
    #@index_maps = FactoryGirl.create_list(:index_map, 5)
    Capybara.current_driver = :selenium_headless
    # Edit and uncomment the following two lines for running against a remote server
    #Capybara.app_host = "http://test.example.com/"
    #Capybara.run_server = false
  end

  # Clears out uploads after each run
  Minitest.after_run do
    if Rails.env.test?
      test_uploads = Dir["#{Rails.root}/public/test/uploads"]
      FileUtils.rm_rf(test_uploads)
    end
  end

  test "shows home page" do
    #Selenium::WebDriver.logger.level = :debug
    visit '/'
    click_on 'Browse All Maps'
    assert page.has_content?("Browse Maps")
    assert page.has_content?(@warped_map.title)
  end

  test "shows maps" do
    visit '/maps'
    assert page.has_content?("Browse Maps")
    assert page.has_content?(@warped_map.title)
  end

  test "shows map geosearch" do
    Capybara.default_max_wait_time = 5  ##FIXME for testing?

    visit '/maps/geosearch?show_warped=1'
    assert page.has_content?("Found")  #html title
    assert page.has_selector?('#popup', visible: false)  #no popup should be visible at the beginning

    find("tr#map-row-#{@warped_map.id} td.mini-map-thumb").click  #click on the cell with the map in it
    assert find("#popup").visible?  #did the popup appear?
    assert page.has_selector?('#popup', visible: true) #did the popup appear?

    assert find("#popup").has_selector?("div#popup .searchmap-popup img", visible: true)  #does the popup show an image?

    #click on the map viewport somewhere
    find('#searchmap .ol-viewport').click
    assert page.has_selector?('#popup', visible: false)  #no popup should be visible if nothing is clicked
    assert page.has_no_selector?('#nothing-here') 

   #assert find('#nothing here this is to keep browser window open').click  
  end


end
