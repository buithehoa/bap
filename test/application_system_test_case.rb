require "test_helper"
require "capybara/selenium/driver"

# Chrome 158 rejects the wildcard origin Capybara 3.40.0 passes to
# Storage.clearDataForOrigin when it resets the session after each test
# ("invalid argument: * is not a valid URL"). Fall back to clearing every
# cookie, which is all the reset needs here: the app keeps nothing in
# localStorage. Drop this once a Capybara release handles it.
module ChromeWildcardStorageClearFix
  private
    def execute_cdp(cmd, params = {})
      super
    rescue Selenium::WebDriver::Error::InvalidArgumentError
      raise unless cmd == "Storage.clearDataForOrigin" && params[:origin] == "*"
      super("Network.clearBrowserCookies")
    end
end
Capybara::Selenium::Driver::ChromeDriver.prepend(ChromeWildcardStorageClearFix)

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]
end
