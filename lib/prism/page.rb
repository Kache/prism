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

    def refresh
      tap { node.refresh }
    end

    def refresh!(timeout: Prism.config.default_timeout)
      refresh.wait_until(timeout: timeout) { loaded?(timeout: 0) }
    end

    def loaded?(timeout: Prism.config.default_timeout, uri_vars: {})
      url_matches, valid_load = _check_loaded?(timeout: timeout, uri_vars: uri_vars)
      url_matches && valid_load
    end

    def not_loaded?(timeout: Prism.config.default_timeout, uri_vars: {})
      wait_while(timeout: timeout) { loaded?(timeout: 0, uri_vars: uri_vars) }
      true
    rescue ExplicitTimeoutError
      false
    end

    def _check_loaded?(timeout:, uri_vars:)
      url_matches, valid_load = false, false
      wait_until(timeout: timeout) do
        extracts = self.class.extract_uri_vars(session.current_path)
        url_matches = !extracts.nil? && uri_vars.all? { |k, v| extracts[k.to_s] == v.to_s }
        valid_load = !!validate_loading
        url_matches && valid_load
      end
      [url_matches, valid_load]
    rescue ExplicitTimeoutError
      [url_matches, valid_load]
    end

    protected

    # don't respond to, but still allow Pages to call it on Elements
    undef_method :attribute_value

    # Wait after taking an action that redirects, example:
    #
    #     def action_that_redirects
    #       link_btn.click                   # triggers redirection
    #       wait_until_redirection(FooPage)  # wait for a FooPage to load and return instance
    #     end
    #
    # Usages:
    #
    #     wait_until_redirection(FooPage, BarPage) # when redirection could land on one of many pages
    #     wait_until_redirection(FooPage, validate_load: false) # skip load validation on destination
    def wait_until_redirection(*page_classes, validate_load: true, timeout: Prism.config.default_timeout)
      still_loaded, curr_path, page_class = true, nil, nil
      begin
        wait_until(timeout: timeout) do
          still_loaded &&= loaded?(timeout: 0)
          return if !still_loaded && page_classes.empty?

          if !still_loaded
            curr_path = session.current_path
            page_class = page_classes.detect { |pc| pc.loads?(curr_path) }
          end
        end
      rescue ExplicitTimeoutError
        reason = still_loaded ? 'current Page is still loaded' : "no Page matches destination #{curr_path}"
        raise NavigationError, "Redirect failure, #{reason}"
      end

      page_object = page_class.new(session)
      page_object.loaded?(timeout: timeout) if validate_load
      page_object
    end

    class << self
      def set_url(url_template, url_processor = nil)
        url_template = Addressable::Template.new(url_template)
        Prism.sitemap[url_template] = self
        @url_processor = url_processor
        @url_template = url_template
      end

      def load_validation(&block)
        private (define_method :validate_loading do
          instance_exec(&block)
        end)
      end

      def loads?(url)
        !extract_uri_vars(url).nil?
      end

      def uri(uri_vars = {})
        @url_template.expand(uri_vars, @url_processor)
      end

      def extract_uri_vars(url)
        @url_template.extract(url, @url_processor)
      end
    end

    private

    def validate_loading
      true
    end

    def _node
      session.browser
    end

    def _ensured_node!
      raise 'Unhandled, for now' unless _node.exists?
      _node
    end
  end
end
