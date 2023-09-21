require 'ffi'
require 'json'
require_relative './extism/version'
require_relative './extism/plugin'
require_relative './extism/current_plugin'
require_relative './extism/libextism'
require_relative './extism/wasm'
require_relative './extism/host_environment'

module Extism
  class Error < StandardError
  end

  # Return the version of Extism
  #
  # @return [String] The version string of the Extism runtime
  def self.extism_version
    LibExtism.extism_version
  end

  # Set log file and level, this is a global configuration
  # @param name [String] The path to the logfile
  # @param level [String] The log level. One of {"debug", "error", "info", "trace" }
  def self.set_log_file(name, level = nil)
    LibExtism.extism_log_file(name, level)
  end

  $PLUGINS = {}
  $FREE_PLUGIN = proc { |ptr|
    x = $PLUGINS[ptr]
    unless x.nil?
      LibExtism.extism_plugin_free(x[:plugin])
      $PLUGINS.delete(ptr)
    end
  }

  Memory = Struct.new(:offset, :len)
end
