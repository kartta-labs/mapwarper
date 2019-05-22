require 'test_helper'
require 'integration_test_helper'

class HomeTest < ActionDispatch::IntegrationTest

  setup do
    @warped_map = FactoryGirl.create(:warped_map_with_upload)
    #@index_maps = FactoryGirl.create_list(:index_map, 5)
    Capybara.current_driver = :selenium_headless 
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
    visit '/maps/geosearch?show_warped=1'
    assert page.has_content?("Found")
  end


end
