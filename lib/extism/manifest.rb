module Extism
  class Manifest
    attr_reader :manifest_data

    # Create a manifest of a single wasm from url.
    # Look at {Manifest#new} for an interface with more control
    #
    # @see Manifest::new
    # @param [String] url The url to the wasm module
    # @param [String | nil] url An optional sha256 integrity hash. Defaults to nil
    # @param [String | nil] An optional name. Defaults to nil
    # @returns [Extism::Manifest]
    def self.from_url(url, hash: nil, name: nil)
      wasm = { url: url }
      wasm[:hash] = hash unless hash.nil?
      wasm[:name] = name unless hash.nil?

      Manifest.new({ wasm: [wasm] })
    end

    # Create a manifest of a single wasm from file path.
    # Look at {Manifest#new} for an interface with more control
    #
    # @see Manifest::new
    # @param [String] path The path to the wasm module on disk
    # @param [String | nil] url An optional sha256 integrity hash. Defaults to nil
    # @param [String | nil] An optional name. Defaults to nil
    # @returns [Extism::Manifest]
    def self.from_path(path, hash: nil, name: nil)
      wasm = { path: path }
      wasm[:hash] = hash unless hash.nil?
      wasm[:name] = name unless hash.nil?

      Manifest.new({ wasm: [wasm] })
    end

    # Create a manifest of a single wasm module with raw binary data.
    # Look at {Manifest#new} for an interface with more control
    # Consider using a file path instead of the raw wasm binary in memory.
    # The performance is often better letting the runtime load the binary itself.
    #
    # @see Manifest::new
    # @param [String] The binary data of the wasm module
    # @param [String | nil] hash An optional sha256 integrity hash. Defaults to nil
    # @param [String | nil] name An optional name. Defaults to nil
    # @returns [Extism::Manifest]
    def self.from_bytes(data, hash: nil, name: nil)
      wasm = { data: data }
      wasm[:hash] = hash unless hash.nil?
      wasm[:name] = name unless hash.nil?

      Manifest.new({ wasm: [wasm] })
    end

    # Initialize a manifest
    # See https://extism.org/docs/concepts/manifest for schema
    #
    # @param
    def initialize(hash)
      @manifest_data = hash
    end
  end
end
