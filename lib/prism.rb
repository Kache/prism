require 'watir'
require 'addressable'

require 'prism/version'
require 'prism/configuration'
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
        Selenium::WebDriver.logger.level = Selenium::WebDriver::Logger::WARN
        Prism::Configuration.new
      end
      yield @config if block_given?
      @config
    end

    def page_for(url)
      page_class = sitemap.each_value.detect { |page_class| page_class.loads?(url) }
      raise "No page matching `#{url}` defined!" unless page_class
      page_class
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
end
