module Extism
  module ValType
    I32 = 0
    I64 = 1
    F32 = 2
    F64 = 3
    V128 = 4
    FUNC_REF = 5
    EXTERN_REF = 6
  end

  class Val
    def initialize(ptr)
      @c_val = LibExtism::ExtismVal.new(ptr)
    end

    def type
      case @c_val[:t]
      when :I32
        :i32
      when :I64
        :i64
      when :F32
        :f32
      when :F64
        :f64
      else
        raise "Unsupported wasm value type #{type}"
      end
    end

    def value
      @c_val[:v][type]
    end

    def value=(val)
      @c_val[:v][type] = val
    end
  end

  # A CancelHandle can be used to cancel a running plugin from another thread
  class CancelHandle
    def initialize(handle)
      @handle = handle
    end

    # Cancel the plugin used to generate the handle
    def cancel
      LibExtism.extism_plugin_cancel(@handle)
    end
  end

  class Function
    def initialize(name, args, returns, func_proc, user_data)
      @name = name
      @args = args
      @returns = returns
      @func = func_proc
      @user_data = user_data
    end

    def pointer
      return @pointer if @pointer

      free = proc { puts 'freeing ' }
      args = LibExtism.from_int_array(@args)
      returns = LibExtism.from_int_array(@returns)
      @pointer = LibExtism.extism_function_new(@name, args, @args.length, returns, @returns.length, c_func, free, nil)
    end

    private

    def c_func
      @c_func ||= proc do |plugin_ptr, inputs_ptr, inputs_size, outputs_ptr, outputs_size, _data_ptr|
        current_plugin = Extism::CurrentPlugin.send(:new, plugin_ptr)
        val_struct_size = LibExtism::ExtismVal.size

        inputs = (0...inputs_size).map do |i|
          Val.new(inputs_ptr + i * val_struct_size)
        end
        outputs = (0...outputs_size).map do |i|
          Val.new(outputs_ptr + i * val_struct_size)
        end

        @func.call(current_plugin, inputs, outputs, @user_data)
      end
    end
  end
end
