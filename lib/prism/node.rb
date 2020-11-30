module Prism
  class Node
    extend Forwardable

    def initialize(parent)
      raise ArgumentError unless parent
      @parent = parent
    end

    def html
      gracefully { node.html }
    end

    def text
      gracefully { node.text }
    end

    def page
      @parent.page
    end

    protected

    def wait_while(timeout: Prism.config.default_timeout)
      page.session._wait.while(node, timeout: timeout) { yield(self) }
      self
    end

    def wait_until(timeout: Prism.config.default_timeout)
      page.session._wait.until(node, timeout: timeout) { yield(self) }
      self
    end

    # needs to be undef_method for Pages
    def attribute_value(attribute_name)
      gracefully { node.attribute_value(attribute_name) }
    end

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
          still_loaded &&= page.loaded?(timeout: 0)
          return if !still_loaded && page_classes.empty?

          if !still_loaded
            curr_path = page.session.current_path
            page_class = page_classes.detect { |pc| pc.loads?(curr_path) }
          end
        end
      rescue ExplicitTimeoutError
        reason = still_loaded ? 'current Page is still loaded' : "no Page matches destination #{curr_path}"
        raise NavigationError, "Redirect failure, #{reason}"
      end

      page_object = page_class.new(page.session)
      page_object.loaded?(timeout: timeout) if validate_load
      page_object
    end

    def node
      _node
    end

    def ensured_node!
      _ensured_node!
    end

    private

    def execute_script(script, *objs)
      objects = objs.map do |el|
        Prism::Node === el ? el.node : el
      end
      node.execute_script(script, *objects)
    rescue Watir::Exception::UnknownObjectException => ex
      raise ElementNotFoundError, ex.message
    end

    # [:release, :click, :perform, :send_keys, :double_click, :context_click, :move_to, :move_by, :key_down, :key_up, :click_and_hold, :drag_and_drop, :drag_and_drop_by]
    def selenium_actions(*objs, &block)
      objects = objs.map do |obj|
        Prism::Node === obj ? obj.node.wd : obj
      end
      selenium_action_builder = page.node.driver.action
      selenium_action_builder.instance_exec(*objects, &block)
      selenium_action_builder.perform
    end

    # Use to wrap interaction calls that require existance
    # For example, element-context clicking, typing, reading DOM, etc
    # And to give messaging to errors from Watir, Selenium, etc
    def gracefully
      yield ensured_node!
    rescue Watir::Exception::UnknownObjectException => e
      raise ElementNotFoundError, e.message
    rescue Selenium::WebDriver::Error::UnknownError => e
      rgx = /(Element <.*> is not clickable at point \(\d+, \d+\)\. Other element would receive the click: <.*>$)/
      obscured_err = e.message[rgx, 1]
      raise ElementNotFoundError, obscured_err if obscured_err
      raise
    rescue Selenium::WebDriver::Error::TimeoutError => e
      raise 'Timed out waiting for driver to respond'
    end

    class << self
      def element(name, *args, &anon_class_def)
        element_class, locator = parse_args(args, anon_class_def)
        define_method name do |runtime_locator = {}|
          element_class.new(self, locator.merge(runtime_locator))
        end
      end

      def elements(name, *args, &anon_class_def)
        element_class, locator = parse_args(args, anon_class_def)
        define_method name do
          Elements.new(self, element_class, locator)
        end
      end

      private

      # arg parser for flexible usage
      def parse_args(args, anon_class_def)
        named_class = Class === args.first && Element > args.first
        if named_class && !anon_class_def
          element_class, *find_args = args
        elsif !named_class
          element_class = anon_class_def ? Class.new(Element, &anon_class_def) : Element
          find_args = args
        else
          raise ArgumentError, 'Provide an Element subclass, an anonymous block definition, or neither, but not both'
        end

        locator = Hash === find_args.last ? find_args.pop : {}

        case find_args.size
        when 1 then locator[:css]            = find_args.shift
        when 2 then locator[find_args.shift] = find_args.shift
        end

        [element_class, locator]
      end
    end
  end
end
