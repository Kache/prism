module Prism
  class Element < Node
    def initialize(parent, locator)
      super(parent)
      ele = parent.node.element(locator)
      if ele.exist?
        ele = ele.to_subtype
        # handle contenteditable, requires existence for now
        ele = ele.extend(Watir::UserEditable) if ele.content_editable? && !ele.is_a?(Watir::UserEditable)
      end
      @node = ele
    end

    attr_reader :parent

    # expose just a few internal operations
    def set(value)
      gracefully { node.set(value) }
    end

    def select_value(option)
      gracefully { node.select(option) }
    end

    def get_select_options
      gracefully { node.options }
    end

    def click
      gracefully { node.click }
    end

    def hover
      gracefully { node.hover }
    end

    def visible?(timeout: 0)
      Util.wrap_timeout(timeout) { |t| node.wait_until_present(timeout: t) }
    end

    def not_visible?(timeout: 0)
      Util.wrap_timeout(timeout) { |t| node.wait_while_present(timeout: t) }
    end

    def drag_and_drop_to(destination)
      target = self

      selenium_actions(target, destination) do |target, destination|
        # react-beautiful-dnd looks for a click, hold, and small movement to initiate a drag event
        click_and_hold(target)
        move_by(0, -5)

        move_to(destination) # now that the drag has started, move to your destination

        release # drop the target at it's destination
      end
      sleep 1 # allow for a rerender
    end

    private

    def _node
      @node
    end
  end

  # enumerable container of elements
  class Elements < Node
    include Enumerable
    extend Forwardable

    attr_reader :parent
    def initialize(parent, element_class, locator)
      super(parent)
      @element_class = element_class
      @locator = locator
    end

    def visible?(timeout: 0)
      Util.wrap_timeout(timeout) { |t| first_child.wait_until_present(timeout: t) }
    end

    def not_visible?(timeout: 0)
      Util.wrap_timeout(timeout) { |t| first_child.wait_while_present(timeout: t) }
    end

    def with(locator)
      Elements.new(parent, @element_class, @locator.merge(locator))
    end

    def at(i)
      @element_class.new(parent, @locator.merge(index: i))
    end

    def at!(i)
      ele = at(i)
      ele.node.exist? ? ele : nil
    end
    alias_method :[], :at!

    def first
      at(0)
    end

    def last
      at(size - 1)
    end

    def size
      selenium_elements = node.elements(@locator).send(:elements) # trick for speed
      selenium_elements.size
    end
    alias_method :count, :size
    alias_method :length, :size

    def each
      return enum_for(:each) unless block_given?

      (0...size).each { |i| yield at(i) }
      self
    end

    delegate to_a: :each
    def_delegators :to_a, :sample, :values_at, :inspect

    private

    def first_child
      node.element(@locator.merge(index: 0))
    end

    def _node
      @parent.node
    end
  end
end
