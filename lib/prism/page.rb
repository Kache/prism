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

      @_validation_failure = url_matches && !validate_loading
      url_matches && !@_validation_failure
    rescue Selenium::WebDriver::Error::TimeOutError
      false
    end

    attr_reader :_validation_failure

    protected

    def wait_until_redirection(*page_classes, timeout: Prism.config.default_timeout)
      begin
        wait_while(timeout: timeout) { loaded? }
      rescue ExplicitTimeoutError
        raise NavigationError, "Redirect failure, Page is still loaded"
      end

      return if page_classes.empty?

      curr_path, page_class = nil, nil
      begin
        wait_until(timeout: timeout) do
          curr_path = session.current_path
          page_class = page_classes.detect { |pc| pc.loads?(curr_path) }
        end
      rescue ExplicitTimeoutError
        raise NavigationError, "Redirect failure, no Page defined to load #{curr_path}"
      end

      page_class.new(session)
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
