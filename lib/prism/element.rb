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
    delegate(
      set:   :node,
      click: :node,
      hover: :node,
    )

    def visible?(timeout: 0)
      Util.wrap_timeout(timeout) { |t| node.wait_until_present(timeout: t) }
    end

    def not_visible?(timeout: 0)
      Util.wrap_timeout(timeout) { |t| node.wait_while_present(timeout: t) }
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
    alias :any? :visible?

    def not_visible?(timeout: 0)
      Util.wrap_timeout(timeout) { |t| first_child.wait_while_present(timeout: t) }
    end
    alias :empty? :not_visible?

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
    alias :[] :at!

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
    alias :count :size
    alias :length :size

    def each
      return enum_for(:each) unless block_given?

      [*0...size].each { |i| yield at(i) }
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
