module Prism
  class Node
    extend Forwardable

    def initialize(parent)
      raise ArgumentError unless parent
      @parent = parent
    end

    delegate(
      html: :node,
      text: :node,
    )

    def page
      @parent.page
    end

    protected

    def wait_while(timeout: Prism.config.default_timeout, &block)
      node.wait_while(timeout: Util.scale(timeout), &block)
      self
    end

    def wait_until(timeout: Prism.config.default_timeout, &block)
      node.wait_until(timeout: Util.scale(timeout), &block)
      self
    end

    def execute_script(script, *objs)
      objects = objs.map do |el|
        Prism::Node === el ? el.node : el
      end
      node.execute_script(script, *objects)
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

    def node
      _node
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
          raise ArgumentError 'Provide an Element subclass, an anonymous block definition, or neither, but not both'
        end

        locator = Hash === find_args.last ? find_args.pop : {}

        case find_args.size
        when 1 then locator[:css]            = find_args.shift
        when 2 then locator[find_args.shift] = find_args.shift
        end

        return element_class, locator
      end
    end
  end
end
