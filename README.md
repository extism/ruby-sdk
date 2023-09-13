# Extism Ruby Host SDK

> **Note**: This houses the 1.0 version of the Ruby SDK and is a work in progress. Please use the ruby SDK in extism/extism until we hit 1.0.

This repo houses the ruby gem for integrating with the [Extism](https://extism.org/) runtime. Install this library into your host ruby applications to run Extism plugins.

## Installation

You first need to [install the Extism runtime](https://extism.org/docs/install).

Add this library to your [Gemfile](https://bundler.io/):

```ruby
gem 'extism', '1.0.0-rc.1'
```

Or if installing on the system level:

```
gem install extism
```

## Getting Started

First you should require `"extism"`:

```
require "extism"
```

## Creating A Plug-in

The primary concept in Extism is the plug-in. You can think of a plug-in as a code module. It has imports and it has exports. These imports and exports define the interface, or your API. You decide what they are called and typed, and what they do. Then the plug-in developer implements them and you can call them.

The code for a plug-in exist as a binary wasm module. We can load this with the raw bytes or we can use the manifest to tell Extism how to load it from disk or the web.

For simplicity let's load one from the web:

```ruby
manifest = {
  wasm: [
    { url: "https://raw.githubusercontent.com/extism/extism/main/wasm/code.wasm" }
  ]
}
plugin = Extism::Plugin.new(manifest)
```

> **Note**: The schema for this manifest can be found here: https://extism.org/docs/concepts/manifest/


This plug-in was written in C and it does one thing, it counts vowels in a string. As such it exposes one "export" function: `count_vowels`. We can call exports using `Extism::Plugin#call`:

```
plugin.call("count_vowels", "Hello, World!")
# => {"count": 3, "total": 3, "vowels": "aeiouAEIOU"}
```

All exports have a simple interface of optional bytes in, and optional bytes out. This plug-in happens to take a string and return a JSON encoded string with a report of results.


### Plug-in State

Plug-ins may be stateful or stateless. Plug-ins can maintain state b/w calls by the use of variables. Our count vowels plug-in remembers the total number of vowels it's ever counted in the "total" key in the result. You can see this by making subsequent calls to the export:

```
plugin.call("count_vowels", "Hello, World!")
# => {"count": 3, "total": 6, "vowels": "aeiouAEIOU"}
plugin.call("count_vowels", "Hello, World!")
# => {"count": 3, "total": 9, "vowels": "aeiouAEIOU"}
```

These variables will persist until this plug-in is freed or you initialize a new one.

### Configuration

Plug-ins may optionally take a configuration object. This is a static way to configure the plug-in. Our count-vowels plugin takes an optional configuration to change out which characters are considered vowels. Example:

```
plugin = Extism::Plugin.new(manifest)
plugin.call("count_vowels", "Yellow, World!")
# => {"count": 3, "total": 3, "vowels": "aeiouAEIOU"}

plugin = Extism::Plugin.new(manifest, config: { vowels: "aeiouyAEIOUY" })
plugin.call("count_vowels", "Yellow, World!")
# => {"count": 4, "total": 4, "vowels": "aeiouAEIOUY"}
```

### Host Functions

Host functions can be a complicated concept. You can think of them like custom syscalls for your plug-in. You can use them to add capabilities to your plug-in through a simple interface.

Another way to look at it is this: Up until now we've only invoked functions given to us by our plug-in, but what if our plug-in needs to invoke a function in our ruby app? Host functions allow you to do this by passing a reference to a ruby method to the plug-in.

Let's load up a version of count vowels with a host function:

```ruby
manifest = {
  wasm: [
    { url: "https://raw.githubusercontent.com/extism/extism/main/wasm/count-vowels-host.wasm" }
  ]
}
plugin = Extism::Plugin.new(manifest)
```

Unlike our original plug-in, this plug-in expects you to provide your own implementation of "is_vowel" in ruby.
First let's create our host function which we can do with a proc:

```ruby
is_vowel_proc = proc do |current_plugin, inputs, outputs, user_data|
  puts "Hello From Ruby!"
  input = current_plugin.input_as_string(inputs.first)
  if "aeiouAEIOU".include? input[0]
      current_plugin.return_int(outputs.first, 1)
  else
      current_plugin.return_int(outputs.first, 0)
  end
end
```

This proc will be exposed to the plug-in in it's native language. We need to know the inputs and outputs and their types ahead of time. This function expects a string (single character) as the first input and expects a 0 (false) or 1 (true) in the output (returns).

We need to pass these imports to the plug-in to create them. All imports of a plug-in must be satisfied for it to be initialized:

```ruby
# we need to give it the Wasm signature, it takes one i64 as input which acts as a pointer to a string
# and it returns an i64 which is the 0 or 1 result
is_vowel = Extism::Function.new('is_vowel', [Extism::ValType::I64], [Extism::ValType::I64], is_vowel_proc)
plugin = Extism::Plugin.new(host_manifest, functions: [is_vowel])
# => Hello From Ruby!
# => {"count": 3, "total": 3}
```

Although this is a trivial example, you could imagine some more elaborate APIs for host functions. This is truly how you unleash the power of the plugin. You could, for example, imagine giving the plug-in access to APIs your app normally has like reading from a database, authenticating a user, sending messages, etc.
