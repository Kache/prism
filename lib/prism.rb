require 'uri'
require 'watir'
require 'addressable'
require 'selenium-webdriver'

require 'prism/version'
require 'prism/configuration'
require 'prism/wait'
require 'prism/session'
require 'prism/node'
require 'prism/page'
require 'prism/element'

module Prism
  @sitemap = {}
  @session_pool = {}

  # currently only supports a single browser session at a time
  class << self
    attr_reader :sitemap

    def config
      @config ||= begin
        # Selenium::WebDriver.logger.level = Selenium::WebDriver::Logger::WARN
        Prism::Configuration.new
      end
      yield @config if block_given?
      @config
    end

    def default_session
      @session_pool[:default] ||= Prism::Session.new
    end

    def clear_sessions!
      @session_pool.each_value(&:quit)
      @session_pool.clear
    end

    def _session_pool
      @session_pool
    end
  end

  class Error < StandardError; end
  class AutomationError < Error; end
  class PageLoadTimeoutError < Error; end
  class ElementNotFoundError < Error; end
  class ExplicitTimeoutError < Error; end
  class NavigationError < Error; end
  class NestedWaitError < Error; end
end
