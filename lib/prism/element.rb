module Prism
  class Element < Node
    def initialize(parent, locator)
      super(parent)
      tag_name = locator.fetch(:tag_name, '')
      # Pre-emptively subtype if given (Why doesn't Watir do this automatically?)
      klass = Watir.element_class_for(tag_name)
      @node = klass.new(parent.node, locator)
    end

    attr_reader :parent

    def visible?(timeout: 0)
      page.session._wait.visible?(node, timeout: timeout)
    end

    def not_visible?(timeout: 0)
      page.session._wait.not_visible?(node, timeout: timeout)
    end

    # Watir element interaction passthroughs
    # NOTE: use subclasses for other tag-specific operations!
    # For example, prefer Elements::Input for #set and #clear
    def click(*modifiers); gracefully { node.click(*modifiers) }; end
    def click!;            gracefully { node.click!            }; end
    def double_click;      gracefully { node.double_click      }; end
    def double_click!;     gracefully { node.double_click!     }; end
    def right_click;       gracefully { node.right_click       }; end
    def hover;             gracefully { node.hover             }; end

    def send_keys(*args);  gracefully { node.send_keys(*args)  }; end
    def focused?;          gracefully { node.focused?          }; end

    def scroll_into_view;  gracefully { node.scroll_into_view  }; end
    def location;          gracefully { node.location          }; end
    def size;              gracefully { node.size              }; end
    def height;            gracefully { node.height            }; end
    def width;             gracefully { node.width             }; end
    def center;            gracefully { node.center            }; end

    def enabled?;          gracefully { node.enabled?          }; end
    def value;             gracefully { node.value             }; end
    def loaded?;           gracefully { node.loaded?           }; end

    # Check element doesn't exists in DOM
    def exists?
       node.exists?
    end

    # Added select_value to unblock the HRIS automation
    def select_value(option); gracefully { node.select(option) }; end
    def selected?(option); gracefully { node.selected?(option) }; end
    def get_select_options; gracefully { node.options          }; end

    private

    def _node
      @node
    end

    def _ensured_node!
      ensured = (
        !(Watir::HTMLElement === node) && # already subtyped
        node.instance_variable_get(:@element) # is_located (private Watir api)
      )
      return node if ensured

      @node = if node.exist?
        subtype = node.to_subtype
        subtype.extend(Watir::UserEditable) if subtype.content_editable? && !subtype.is_a?(Watir::UserEditable)
        subtype
      else # not safe to use inside wait block
        begin
          page.session._wait.blocked { node.to_subtype }
        rescue NestedWaitError
          raise NestedWaitError, 'Element must exist before doing this operation in a Wait block! Try `element.visible?` first.'
        end
      end
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
      page.session._wait.visible?(first_child, timeout: timeout)
    end

    def not_visible?(timeout: 0)
      page.session._wait.not_visible?(first_child, timeout: timeout)
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

    def _ensured_node!
      @parent.ensured_node!
    end
  end
end
