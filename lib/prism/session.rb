module Prism
  class Session
    def initialize
      @browser = nil
      @app_host = Prism.config.app_host&.dup
      @_wait = Wait.new
      @cookies = {}
      Prism._session_pool[object_id] = self
    end

    # runs page load validations
    def load!(page_class, timeout: Prism.config.default_timeout, uri_vars: {})
      page = visit(page_class, uri_vars: uri_vars)

      url_matches, valid_load = page._check_loaded?(timeout: timeout, uri_vars: uri_vars)
      raise NavigationError, "Failed to load #{page_class}" if !url_matches
      raise NavigationError, "#{page_class} load_validation failed" if !valid_load

      page
    end

    # no page load validations
    def visit(page_class, uri_vars: {})
      page = page_class.new(self)

      begin
        browser.goto visit_uri(page_class, uri_vars).to_s
      rescue Selenium::WebDriver::Error::TimeOutError
        # selenium bug? see page_load timeout set by Prism#init_browser_session
        ignore_timeout = (
          Selenium::WebDriver::Chrome::Driver === browser.driver &&
          page.loaded?(timeout: 0, uri_vars: uri_vars)
        )
        raise PageLoadTimeoutError, "Gave up waiting for page to load, (try tweaking chrome_page_load_timeout)" unless ignore_timeout
      rescue Net::OpenTimeout
        raise AutomationError, "Gave up waiting for driver to respond, (try tweaking http_client_open_timeout)"
      rescue Net::ReadTimeout
        raise AutomationError, "Gave up waiting for driver to respond, (try tweaking http_client_read_timeout)"
      end

      page
    end

    def within_popup(page_klass, uri_vars: {})
      url = visit_uri(page_klass, uri_vars).to_s
      popup_page = page_klass.new(self)
      browser.window(url: url) do # watir will have one unavoidable focus switch
        yield popup_page
        browser.driver.close # avoids yet another focus switch when closing window
      end
    end

    def current_path
      current_uri = Addressable::URI.parse(browser.url)
      is_app_url = app_host&.host == current_uri.host && app_host&.port == current_uri.port
      current_uri = current_uri.omit(:scheme, :authority) if is_app_url # return relative url for the "main app"
      current_uri
    end

    # Usage: To call HTTP Get/POST request using browser cookies
    # Example: download file
    def get_cookies
      @cookies = browser.cookies.to_a
    end

    def browser
      @browser ||= init_browser
    end

    # resets state, should be equivalent to WebDriver quit & reinitialize
    def reset!
      @browser&.cookies&.clear
      @browser&.driver&.local_storage&.clear
      @browser&.goto 'data:,'
      @browser
    end

    def quit
      @browser&.quit
      @browser = nil
      Prism._session_pool.delete(object_id)
    end

    attr_reader :_wait

    private

    attr_reader :app_host

    def visit_uri(page_klass, uri_vars)
      visit_uri = page_klass.uri(uri_vars)
      if visit_uri.relative? && app_host
        app_host + visit_uri
      else
        visit_uri # absolute
      end
    end

    def init_browser
      watir_opts = {
        http_client: Selenium::WebDriver::Remote::Http::Default.new.tap do |client|
          client.open_timeout = Prism.config.http_client_open_timeout
          client.read_timeout = Prism.config.http_client_read_timeout
        end,
        args: [
          # '--headless', '--disable-gpu', # waitr handles local vs remote variations
          # '--window-size=1024,768', # XGA
          # '--window-size=1366,768', # WXGA
          # '--window-size=1280,800', # WXGA/WQXGA
          '--window-size=1280,720', # 720p
          # '--window-size=1920,1080', # 1080p
          # '--enable-logging=stderr --v=1', # enable verbose logging
        ],
        options: {
            prefs: {
              download: {
                  prompt_for_download: false,
                  default_directory: File.expand_path(Prism.config.other[:file_download_path])
              }
            }
        },

      }
      watir_opts[:args] += Prism.config.other[:chrome_extra_options] if Prism.config.other[:chrome_extra_options]
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
