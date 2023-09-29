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
  end

  module ClassMethods
    def register_import(func_name, parameters, returns)
      import_funcs = class_variable_get(:@@import_funcs)
      import_funcs << [func_name, parameters, returns]
    end
  end
end
