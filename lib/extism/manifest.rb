module Extism
  # The manifest represents a recipe to build a plug-in.
  # It generally consists of a path to one wasm module
  # but could contain more. It also helps you define some
  # options and restrictions on the runtime behavior of the plug-in.
  # See https://extism.org/docs/concepts/manifest for more info.
  class Manifest
    attr_reader :manifest_data

    # Create a manifest of a single wasm from url.
    # Look at {Manifest#initialize} for an interface with more control
    #
    # @see Manifest::initialize
    # @param [String] url The url to the wasm module
    # @param [String | nil] hash An optional sha256 integrity hash. Defaults to nil
    # @param [String | nil] name An optional name. Defaults to nil
    # @return [Extism::Manifest]
    def self.from_url(url, hash: nil, name: nil)
      wasm = { url: url }
      wasm[:hash] = hash unless hash.nil?
      wasm[:name] = name unless hash.nil?

      Manifest.new({ wasm: [wasm] })
    end

    # Create a manifest of a single wasm from file path.
    # Look at {Manifest#initialize} for an interface with more control
    #
    # @see Manifest::initialize
    # @param [String] path The path to the wasm module on disk
    # @param [String | nil] hash An optional sha256 integrity hash. Defaults to nil
    # @param [String | nil] name An optional name. Defaults to nil
    # @return [Extism::Manifest]
    def self.from_path(path, hash: nil, name: nil)
      wasm = { path: path }
      wasm[:hash] = hash unless hash.nil?
      wasm[:name] = name unless hash.nil?

      Manifest.new({ wasm: [wasm] })
    end

    # Create a manifest of a single wasm module with raw binary data.
    # Look at {Manifest#initialize} for an interface with more control
    # Consider using a file path instead of the raw wasm binary in memory.
    # The performance is often better letting the runtime load the binary itself.
    #
    # @see Manifest::initialize
    # @param [String] data The binary data of the wasm module
    # @param [String | nil] hash An optional sha256 integrity hash. Defaults to nil
    # @param [String | nil] name An optional name. Defaults to nil
    # @return [Extism::Manifest]
    def self.from_bytes(data, hash: nil, name: nil)
      wasm = { data: data }
      wasm[:hash] = hash unless hash.nil?
      wasm[:name] = name unless hash.nil?

      Manifest.new({ wasm: [wasm] })
    end

    # Initialize a manifest
    # See https://extism.org/docs/concepts/manifest for schema
    #
    # @param [Hash] data The Hash data that conforms the Manifest schema
    def initialize(data)
      @manifest_data = data
    end
  end
end
