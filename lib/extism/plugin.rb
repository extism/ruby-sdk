module Extism
  # A Plugin represents an instance of your WASM program
  # created from the given manifest.
  class Plugin
    # Intialize a plugin
    #
    # @example Initialize a plugin from a url
    #   manifest = Extism::Manifest.from_url "https://github.com/extism/plugins/releases/latest/download/count_vowels.wasm"
    #   plugin = Extism::Plugin.new(manifest)
    #
    # @example Pass a config object to configure the plug-in
    #   plugin = Extism::Plugin.new(manifest, config: { hello: "world" })
    #
    # @example Initalize a plug-in that needs WASI
    #   plugin = Extism::Plugin.new(manifest, wasi: true)
    #
    # @param wasm [Hash, String, Manifest] The manifest as a Hash or WASM binary as a String. See https://extism.org/docs/concepts/manifest/.
    # @param wasi [Boolean] Enable WASI support
    # @param config [Hash] The plugin config
    def initialize(wasm, environment: nil, functions: [], wasi: false, config: nil)
      wasm = case wasm
             when Hash
               JSON.generate(wasm)
             when Manifest
               JSON.generate(wasm.manifest_data)
             else
               wasm
             end

      code = FFI::MemoryPointer.new(:char, wasm.bytesize)
      errmsg = FFI::MemoryPointer.new(:pointer)
      code.put_bytes(0, wasm)
      if functions.empty? && environment
        unless environment.respond_to?(:host_functions)
          raise ArgumentError 'environment should implement host_functions method'
        end

        functions = environment.host_functions
      end
      funcs_ptr = FFI::MemoryPointer.new(LibExtism::ExtismFunction)
      funcs_ptr.write_array_of_pointer(functions.map { |f| f.send(:pointer) })
      @plugin = LibExtism.extism_plugin_new(code, wasm.bytesize, funcs_ptr, functions.length, wasi, errmsg)
      if @plugin.null?
        err = errmsg.read_pointer.read_string
        LibExtism.extism_plugin_new_error_free errmsg.read_pointer
        raise Error, err
      end
      $PLUGINS[object_id] = { plugin: @plugin }
      ObjectSpace.define_finalizer(self, $FREE_PLUGIN)
      return if config.nil? or @plugin.null?

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
    # @example
    #   input = JSON.generate({hello: "world"})
    #   result = plugin.call("my_func", input)
    #   output = JSON.parse(result)
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
