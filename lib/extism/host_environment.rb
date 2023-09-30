module Extism
  # Represents an "environment" that can be imported to a plug-in
  #
  # @example
  #   class MyEnvironment
  #     include Extism::HostEnvironment
  #     # we need to register each import that the plug-in expects and match the Wasm signature
  #     # register_import takes the name, the param types, and the return types
  #     register_import :reflect, [Extism::ValType::I64], [Extism::ValType::I64]
  #
  #     # reflect just takes a string from the plug-in and reflects it back in return
  #     def reflect(plugin, inputs, outputs, _user_data)
  #       msg = plugin.input_as_string(inputs.first)
  #       plugin.output_string(outputs.first, msg)
  #     end
  #   end
  #
  module HostEnvironment
    def self.included(base)
      base.extend ClassMethods
      base.class_variable_set(:@@import_funcs, [])
    end

    # Creates the host functions to pass to the plug-in on intialization.
    # Used internally by the Plugin initializer
    #
    # @see Extism::Plugin::new
    #
    # @return [Array<Extism::Function>]
    def host_functions
      import_funcs = self.class.class_variable_get(:@@import_funcs)
      import_funcs.map do |f|
        name, params, returns = f
        Extism::Function.new(
          name.to_s,
          params,
          returns,
          method(name).to_proc
        )
      end
    end

    module ClassMethods
      # Register an import by name. You must know the wasm signature
      # of the function to do this.
      #
      # @example
      #   register_import :my_func, [Extism::ValType::I64], [Extism::ValType::F64]
      #
      # @param [Symbol | String] func_name The name of the wasm import function. Assumes `env` namespace.
      # @param [Array<Extism::ValType>] parameters The Wasm types of the parameters that the import takes
      # @param [Array<Extism::ValType>] returns The Wasm types of the returns that the import returns. Will usually be just be one of these.
      def register_import(func_name, parameters, returns)
        import_funcs = class_variable_get(:@@import_funcs)
        import_funcs << [func_name, parameters, returns]
      end
    end
  end
end
