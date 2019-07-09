module Prism
  class Wait
    def initialize
      @waiting = false
    end

    def while(node, timeout:)
      allow_nesting_if(timeout.zero?) { node.wait_while(timeout: scale(timeout)) { yield } }
    rescue Watir::Wait::TimeoutError => ex
      raise ExplicitTimeoutError, ex.message
    end

    def until(node, timeout:)
      allow_nesting_if(timeout.zero?) { node.wait_until(timeout: scale(timeout)) { yield } }
    rescue Watir::Wait::TimeoutError => ex
      raise ExplicitTimeoutError, ex.message
    end

    def visible?(node, timeout:)
      allow_nesting_if(timeout.zero?) { node.wait_until_present(timeout: scale(timeout)) }
      true
    rescue Watir::Wait::TimeoutError, Selenium::WebDriver::Error::StaleElementReferenceError
      false
    end

    def not_visible?(node, timeout:)
      allow_nesting_if(timeout.zero?) { node.wait_while_present(timeout: scale(timeout)) }
      true
    rescue Watir::Wait::TimeoutError, Selenium::WebDriver::Error::StaleElementReferenceError
      false
    end

    def blocked
      allow_nesting_if(false) { yield }
    end

    def self.scale(timeout)
      exponent = Prism.config.timeout_scaling_exponent
      Prism.config.timeout_scaling * timeout**exponent
    end

    private

    def scale(timeout)
      self.class.scale(timeout)
    end

    def allow_nesting_if(timeout_is_zero)
      return yield if timeout_is_zero
      raise NestedWaitError, "Already nested within a Wait block, instead: increase outermost timeout and/or reduce inner timeouts to zero" if @waiting

      begin
        @waiting = true
        yield
      ensure
        @waiting = false
      end
    end
  end
end
