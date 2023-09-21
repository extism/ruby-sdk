module Extism
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
