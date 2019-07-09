module Prism
  class Configuration
    extend Forwardable

    attr_reader :app_host, :remote_selenium_url

    # default explicit wait timeout
    def_delegators Watir, :default_timeout, :default_timeout=

    # scale explicit wait timeouts by:
    #   coefficient * timeout^exponent
    # e.g.
    #   timeout_scaling: 1.5
    #   timeout_scaling_exponent: 0.7
    #   1.5 * 2 sec  ^ 0.7 = 2.4 sec
    #   1.5 * 4 sec  ^ 0.7 = 4.0 sec
    #   1.5 * 8 sec  ^ 0.7 = 6.4 sec
    #   1.5 * 16 sec ^ 0.7 = 10 sec
    #   1.5 * 30 sec ^ 0.7 = 16 sec
    attr_accessor :timeout_scaling # aka 'coefficient'
    attr_accessor :timeout_scaling_exponent

    # NOTE: these are for the http client to chromedriver, *not* the driven browser!
    attr_accessor :http_client_open_timeout # open connection
    attr_accessor :http_client_read_timeout # reading data

    # I think this waits for the `DOMContentLoaded` JavaScript event
    attr_accessor :chrome_page_load_timeout
    # I think this waits for the `load` JavaScript event
    attr_accessor :chrome_script_timeout

    # plain Hash for misc user settings
    attr_reader   :other

    def initialize
      # NOTE: Do not change these setting
      # Change configurations.local.yml for any local override
      self.default_timeout      = 4
      @timeout_scaling          = 1.0
      @timeout_scaling_exponent = 1.0
      @http_client_open_timeout = 1
      @http_client_read_timeout = 8
      @chrome_page_load_timeout = 4
      @chrome_script_timeout    = 30
      @other                    = {}
    end

    def app_host=(url)
      @app_host = parse_url(url)
    end

    def remote_selenium_url=(url)
      @remote_selenium_url = parse_url(url)
    end

    private

    def parse_url(url)
      uri = URI.parse(url)
      raise ArgumentError unless uri.hierarchical? && uri.absolute?
      Addressable::URI.parse(url)
    end
  end
end
