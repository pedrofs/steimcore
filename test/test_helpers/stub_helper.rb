module StubHelper
  # Temporarily replace a method on an object's singleton class for the
  # duration of a block. Minitest 6 dropped its built-in `Object#stub`, so
  # this brings back the same shape (`obj.stub :method, replacement do ... end`)
  # for use in job tests where the boundary we want to fake is a module-level
  # method like `RubyLLM.transcribe` or `RubyLLM.chat`.
  def stub_module_method(target, method_name, replacement)
    metaclass = target.singleton_class
    method_defined = metaclass.method_defined?(method_name) || metaclass.private_method_defined?(method_name)
    original = target.method(method_name) if method_defined

    metaclass.send(:remove_method, method_name) if method_defined
    metaclass.send(:define_method, method_name) do |*args, **kwargs, &block|
      replacement.call(*args, **kwargs, &block)
    end

    yield
  ensure
    if metaclass.method_defined?(method_name) || metaclass.private_method_defined?(method_name)
      metaclass.send(:remove_method, method_name)
    end
    metaclass.send(:define_method, method_name, original.unbind) if original
  end
end

ActiveSupport::TestCase.include(StubHelper)

# Minitest 6 dropped `Object#stub` (it lived in minitest/mock, which was
# extracted). Re-add a small replacement so tests can write
#
#   RubyLLM.stub :transcribe, ->(*args) { ... } do
#     ...
#   end
#
# with the same shape they had on Minitest 5.
unless Object.method_defined?(:stub) || Object.private_method_defined?(:stub)
  class Object
    def stub(method_name, replacement, &block)
      metaclass = singleton_class
      method_defined = metaclass.method_defined?(method_name) || metaclass.private_method_defined?(method_name)
      original = method(method_name) if method_defined

      metaclass.send(:remove_method, method_name) if method_defined
      metaclass.send(:define_method, method_name) do |*args, **kwargs, &b|
        replacement.respond_to?(:call) ? replacement.call(*args, **kwargs, &b) : replacement
      end

      block.call
    ensure
      if metaclass.method_defined?(method_name) || metaclass.private_method_defined?(method_name)
        metaclass.send(:remove_method, method_name)
      end
      metaclass.send(:define_method, method_name, original.unbind) if original
    end
  end
end
