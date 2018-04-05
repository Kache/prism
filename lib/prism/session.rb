module Prism
  class Session
    def initialize
      @browser = nil
      @app_host = Prism.config.app_host&.dup
      Prism._session_pool[object_id] = self
    end

    def visit(page_class, uri_template_mapping = {})
      visit_uri = page_class.uri(uri_template_mapping)
      visit_uri = app_host + visit_uri if visit_uri.relative? && app_host

      page = page_class.new(self)

      begin
        browser.goto visit_uri.to_s
      rescue Selenium::WebDriver::Error::TimeOutError
        # selenium bug? see page_load timeout set by Prism#init_browser_session
        ignore_timeout = (
          Selenium::WebDriver::Chrome::Driver === browser.driver &&
          page.loaded?(uri_template_mapping)
        )
        raise unless ignore_timeout
      end

      page
    end

    def current_page
      Prism.page_for(current_path).new(self)
    end

    def visit_url(url)
      visit(Prism.page_for(url))
    end

    def current_path
      current_uri = Addressable::URI.parse(browser.url)
      current_uri = current_uri.omit(:scheme, :authority) if app_host&.host == current_uri.host
      current_uri
    end

    def browser
      @browser ||= init_browser
    end

    def quit
      @browser&.quit
      @browser = nil
      Prism._session_pool.delete(object_id)
    end

    private

    attr_reader :app_host

    def init_browser
      watir_opts = {
        http_client: Selenium::WebDriver::Remote::Http::Default.new.tap do |client|
          client.open_timeout = Prism.config.http_client_open_timeout
          client.read_timeout = Prism.config.http_client_read_timeout
        end,
        args: [
          # '--headless', '--disable-gpu', # waitr handles local vs remote variations
          '--window-size=1280,800',
        ],
      }
      watir_opts[:url] = Prism.config.remote_selenium_url if Prism.config.remote_selenium_url

      browser = Watir::Browser.new(:chrome, watir_opts)

      # selenium & chrome bug?
      # addresses: https://github.com/seleniumhq/selenium-google-code-issue-archive/issues/4448
      # timeouts can be ignored in Prism#open
      if Selenium::WebDriver::Chrome::Driver === browser.driver
        browser.driver.manage.timeouts.page_load = Prism.config.chrome_page_load_timeout
        browser.driver.manage.timeouts.script_timeout = Prism.config.chrome_script_timeout
      end

      browser
    end
  end
end
