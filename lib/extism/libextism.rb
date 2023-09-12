module Extism
  # Private module used to interface with the Extism runtime.
  # *Warning*: Do not use or rely on this directly
  # improperly using this interface may enable exploits and the interface
  # might change over time.
  module LibExtism
    extend FFI::Library
    ffi_lib 'extism'

    def self.from_int_array(ruby_array)
      ptr = FFI::MemoryPointer.new(:int, ruby_array.length)
      ptr.write_array_of_int(ruby_array)
      ptr
    end

    typedef :uint64, :ExtismMemoryHandle
    typedef :uint64, :ExtismSize

    enum :ExtismValType, %i[I32 I64 F32 F64 V128 FuncRef ExternRef]

    class ExtismValUnion < FFI::Union
      layout :i32, :int32,
             :i64, :int64,
             :f32, :float,
             :f64, :double
    end

    class ExtismVal < FFI::Struct
      layout :t, :ExtismValType,
             :v, ExtismValUnion
    end

    class ExtismFunction < FFI::Struct
      layout :name, :string,
             :inputs, :pointer,
             :n_inputs, :uint64,
             :outputs, :pointer,
             :n_outputs, :uint64,
             :data, :pointer
    end

    callback :ExtismFunctionType, [
      :pointer, # plugin
      :pointer, # inputs
      :ExtismSize, # n_inputs
      :pointer, # outputs
      :ExtismSize, # n_outputs
      :pointer # user_data
    ], :void

    callback :ExtismFreeFunctionType, [], :void

    attach_function :extism_plugin_id, [:pointer], :pointer
    attach_function :extism_current_plugin_memory, [:pointer], :pointer
    attach_function :extism_current_plugin_memory_alloc, %i[pointer ExtismSize], :ExtismMemoryHandle
    attach_function :extism_current_plugin_memory_length, %i[pointer ExtismMemoryHandle], :ExtismSize
    attach_function :extism_current_plugin_memory_free, %i[pointer ExtismMemoryHandle], :void
    attach_function :extism_function_new,
                    %i[string pointer ExtismSize pointer ExtismSize ExtismFunctionType ExtismFreeFunctionType pointer], :pointer
    attach_function :extism_function_free, [:pointer], :void
    attach_function :extism_function_set_namespace, %i[pointer string], :void
    attach_function :extism_plugin_new, %i[pointer ExtismSize pointer ExtismSize bool pointer], :pointer
    attach_function :extism_plugin_new_error_free, [:pointer], :void
    attach_function :extism_plugin_free, [:pointer], :void
    attach_function :extism_plugin_cancel_handle, [:pointer], :pointer
    attach_function :extism_plugin_cancel, [:pointer], :bool
    attach_function :extism_plugin_config, %i[pointer pointer ExtismSize], :bool
    attach_function :extism_plugin_function_exists, %i[pointer string], :bool
    attach_function :extism_plugin_call, %i[pointer string pointer ExtismSize], :int32
    attach_function :extism_error, [:pointer], :string
    attach_function :extism_plugin_error, [:pointer], :string
    attach_function :extism_plugin_output_length, [:pointer], :ExtismSize
    attach_function :extism_plugin_output_data, [:pointer], :pointer
    attach_function :extism_log_file, %i[string string], :bool
    attach_function :extism_version, [], :string
  end
end
