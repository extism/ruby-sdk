module Extism
  # A Plugin represents an instance of your WASM program
  # created from the given manifest.
  class Plugin
    # Intialize a plugin
    #
    # @param wasm [Hash, String] The manifest as a Hash or WASM binary as a String. See https://extism.org/docs/concepts/manifest/.
    # @param wasi [Boolean] Enable WASI support
    # @param config [Hash] The plugin config
    def initialize(wasm, functions: [], wasi: false, config: nil)
      wasm = JSON.generate(wasm) if wasm.instance_of?(Hash)
      code = FFI::MemoryPointer.new(:char, wasm.bytesize)
      errmsg = FFI::MemoryPointer.new(:pointer)
      code.put_bytes(0, wasm)
      funcs_ptr = FFI::MemoryPointer.new(LibExtism::ExtismFunction)
      funcs_ptr.write_array_of_pointer(functions.map { |f| f.pointer })
      @plugin = LibExtism.extism_plugin_new(code, wasm.bytesize, funcs_ptr, functions.length, wasi, errmsg)
      if @plugin.null?
        err = errmsg.read_pointer.read_string
        LibExtism.extism_plugin_new_error_free errmsg.read_pointer
        raise Error, err
      end
      $PLUGINS[object_id] = { plugin: @plugin }
      ObjectSpace.define_finalizer(self, $FREE_PLUGIN)
      return unless !config.nil? and @plugin.null?

      s = JSON.generate(config)
      ptr = FFI::MemoryPointer.from_string(s)
      LibExtism.extism_plugin_config(@plugin, ptr, s.bytesize)
    end

    # Check if a function exists
    #
    # @param name [String] The name of the function
    # @return [Boolean] Returns true if function exists
    def has_function?(name)
      LibExtism.extism_plugin_function_exists(@plugin, name)
    end

    # Call a function by name
    #
    # @param name [String] The function name
    # @param data [String] The input data for the function
    # @return [String] The output from the function in String form
    def call(name, data, &block)
      # If no block was passed then use Pointer::read_string
      block ||= ->(buf, len) { buf.read_string(len) }
      input = FFI::MemoryPointer.from_string(data)
      rc = LibExtism.extism_plugin_call(@plugin, name, input, data.bytesize)
      if rc != 0
        err = LibExtism.extism_plugin_error(@plugin)
        raise Error, 'extism_call failed' if err&.empty?

        raise Error, err

      end

      out_len = LibExtism.extism_plugin_output_length(@plugin)
      buf = LibExtism.extism_plugin_output_data(@plugin)
      block.call(buf, out_len)
    end

    # Free a plugin, this should be called when the plugin is no longer needed
    #
    # @return [void]
    def free
      return if @plugin.null?

      $PLUGINS.delete(object_id)
      LibExtism.extism_plugin_free(@plugin)
      @plugin = nil
    end

    # Get a CancelHandle for a plugin
    def cancel_handle
      CancelHandle.new(LibExtism.extism_plugin_cancel_handle(@plugin))
    end
  end
end
