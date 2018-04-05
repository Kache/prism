module Prism
  class Page < Node
    def initialize(session = Prism.default_session)
      super(session)
    end

    def page
      self
    end

    def session
      @parent
    end

    def loaded?(uri_template_mapping = {})
      extracts = self.class.url_template.extract(session.current_path)

      url_matches = if uri_template_mapping.empty?
        !extracts.nil?
      else
        extracts == uri_template_mapping.map { |k, v| [k.to_s, v] }.to_h
      end

      url_matches && validate_loading
    rescue Selenium::WebDriver::Error::TimeOutError
      false
    end

    class << self
      attr_reader :url_template

      def uri(uri_template_mapping = {})
        @url_template.expand(uri_template_mapping)
      end

      def set_url(url_template)
        url_template = Addressable::Template.new(url_template)
        Prism.sitemap[url_template] = self
        @url_template = url_template
      end

      def load_validation(&block)
        private (define_method :validate_loading do
          instance_exec(&block)
        end)
      end

      def loads?(url)
        !@url_template.match(url).nil?
      end
    end

    private

    def validate_loading
      true
    end

    def _node
      session.browser
    end
  end
end
