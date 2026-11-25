require "test_helper"

# Chrome 158 rejects the "*" origin Capybara clears storage with (teamcapybara/capybara#2865).
# Remove once a Capybara after 3.40.0 fixes it.
module ResetWithoutWildcardOrigin
  private
    def execute_cdp(command, params = {})
      return super unless params[:origin] == "*"

      super("Network.clearBrowserCookies")
      return unless params[:storageTypes].include?("local_storage")

      urls = super("Page.getNavigationHistory")["entries"].map { |entry| entry["url"] }
      urls.filter_map { |url| url[%r{\Ahttps?://[^/?#]+}] }.uniq.each do |origin|
        super("Storage.clearDataForOrigin", { origin: origin, storageTypes: "local_storage" })
      end
    end
end
Capybara::Selenium::Driver::ChromeDriver.prepend(ResetWithoutWildcardOrigin)

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]
end
