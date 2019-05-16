require 'test_helper'

class HomeTest < ActionDispatch::IntegrationTest
  
  setup do
    Capybara.current_driver = :selenium_headless 
  end
  WebMock.allow_net_connect!

  test "shows home page" do
    #Selenium::WebDriver.logger.level = :debug
    visit '/'
    click_on 'Browse All Maps'
    assert page.has_content?("Browse Maps")
  end
end
