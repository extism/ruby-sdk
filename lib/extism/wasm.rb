module Extism
  # Extism specific values for Wasm types. Useful when you need to describe
  # something in pure wasm like host function signatures.
  #
  # @example
  #   register_import :hostfunc, [Extism::ValType::I32, Extism::ValType::F64], [Extism::ValType::I64]
  module ValType
    I32 = 0
    I64 = 1
    PTR = 1
    F32 = 2
    F64 = 3
    V128 = 4
    FUNC_REF = 5
    EXTERN_REF = 6
  end

  # A raw Wasm value. Contains the type and the data
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
      when :PTR
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

  # Represents a host function. This is mostly for internal use and you should
  # try to use HostEnvironment instead
  #
  # @see Extism::HostEnvironment
  class Function
    # Create a new host function
    #
    # @param name [String] Must match the import name in Wasm. Doesn't include namespace. All extism host functions are in the env name space
    # @param params [Array[Extism::ValType]] An array of val types matching the import's params
    # @param returns [Array[Extism::ValType]] An array of val types matching the import returns
    # @param func_proc [Proc] A proc that will be executed when the host function is executed
    # @param user_data [Object] Any reference to object you want to be passed back to you when the func is invoked
    # @param on_free [Proc] A proc triggered when this function is freed by the runtime. Not guaranteed to trigger.
    def initialize(name, params, returns, func_proc, user_data: nil, on_free: nil)
      @name = name
      @params = params
      @returns = returns
      @func = func_proc
      @user_data = user_data
      @on_free = on_free
    end

    private

    # Gets the pointer to this function.
    # Warning: This should not be used
    def pointer
      return @_pointer if @_pointer

      free = @on_free || proc {}
      args = LibExtism.from_int_array(@params)
      returns = LibExtism.from_int_array(@returns)
      @_pointer = LibExtism.extism_function_new(@name, args, @params.length, returns, @returns.length, c_func, free,
                                                nil)
    end

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
