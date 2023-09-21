# Extism Ruby Host SDK

> **Note**: This houses the 1.0 version of the Ruby SDK and is a work in progress. Please use the ruby SDK in extism/extism until we hit 1.0.

This repo houses the ruby gem for integrating with the [Extism](https://extism.org/) runtime. Install this library into your host ruby applications to run Extism plugins.

## Installation

You first need to [install the Extism runtime](https://extism.org/docs/install).

Add this library to your [Gemfile](https://bundler.io/):

```ruby
gem 'extism', '1.0.0.pre.rc.1'
```

Or if installing on the system level:

```
gem install extism --pre
```

## Getting Started

First you should require `"extism"`:

```ruby
require "extism"
```

### Creating A Plug-in

The primary concept in Extism is the plug-in. You can think of a plug-in as a code module. It has imports and it has exports. These imports and exports define the interface, or your API. You decide what they are called and typed, and what they do. Then the plug-in developer implements them and you can call them.

The code for a plug-in exist as a binary wasm module. We can load this with the raw bytes or we can use the manifest to tell Extism how to load it from disk or the web.

For simplicity let's load one from the web:

```ruby
manifest = {
  wasm: [
    { url: "https://github.com/extism/plugins/releases/latest/download/count_vowels.wasm" }
  ]
}
plugin = Extism::Plugin.new(manifest)
```

> **Note**: The schema for this manifest can be found here: https://extism.org/docs/concepts/manifest/

### Calling A Plug-in's Exports

This plug-in was written in C and it does one thing, it counts vowels in a string. As such it exposes one "export" function: `count_vowels`. We can call exports using `Extism::Plugin#call`:

```ruby
plugin.call("count_vowels", "Hello, World!")
# => {"count": 3, "total": 3, "vowels": "aeiouAEIOU"}
```

All exports have a simple interface of optional bytes in, and optional bytes out. This plug-in happens to take a string and return a JSON encoded string with a report of results.


### Plug-in State

Plug-ins may be stateful or stateless. Plug-ins can maintain state b/w calls by the use of variables. Our count vowels plug-in remembers the total number of vowels it's ever counted in the "total" key in the result. You can see this by making subsequent calls to the export:

```ruby
plugin.call("count_vowels", "Hello, World!")
# => {"count": 3, "total": 6, "vowels": "aeiouAEIOU"}
plugin.call("count_vowels", "Hello, World!")
# => {"count": 3, "total": 9, "vowels": "aeiouAEIOU"}
```

These variables will persist until this plug-in is freed or you initialize a new one.

### Configuration

Plug-ins may optionally take a configuration object. This is a static way to configure the plug-in. Our count-vowels plugin takes an optional configuration to change out which characters are considered vowels. Example:

```ruby
plugin = Extism::Plugin.new(manifest)
plugin.call("count_vowels", "Yellow, World!")
# => {"count": 3, "total": 3, "vowels": "aeiouAEIOU"}

plugin = Extism::Plugin.new(manifest, config: { vowels: "aeiouyAEIOUY" })
plugin.call("count_vowels", "Yellow, World!")
# => {"count": 4, "total": 4, "vowels": "aeiouAEIOUY"}
```

### Host Functions

Host functions allow us to grant new capabilities to our plug-ins from our application. They are simply some ruby methods you write which can be passed to and invoked from any language inside the plug-in.

> *Note*: Host functions can be a complicated topic. Please review this [concept doc](https://extism.org/docs/concepts/host-functions) if you are unsure how they work.

### Host Functions Example

We've created a contrived, but familiar example to illustrate this. Suppose you are a stripe-like payments platform.
When a [charge.succeeded](https://stripe.com/docs/api/events/types#event_types-charge.succeeded) event occurs, we will call the `on_charge_succeeded` function on our merchant's plug-in and let them decide what to do with it. Here our merchant has some very specific requirements, if the account has spent more than $100, their currency is USD, and they have no credits on their account, it will add $10 credit to their account and then send them an email.

> *Note*: The source code for this is [here](https://github.com/extism/plugins/blob/main/store_credit/src/lib.rs) and is written in rust, but it could be written in any of our PDK languages.

First let's create the manifest for our plug-in like usual but load up the store_credit plug-in:

```ruby
manifest = {
  wasm: [
    { url: "https://github.com/extism/plugins/releases/latest/download/store_credit.wasm" }
  ]
}
```

But, unlike our original plug-in, this plug-in expects you to provide host functions that satisfy our plug-ins imports.

In the ruby sdk, we have a concept for this call an "host environment". An environment is just an object that responds to `host_functions` and returns an array of `Extism::Function`s. We want to expose two capabilities to our plugin, `add_credit(customer_id, amount)` which adds credit to an account and `send_email(customer_id, email)` which sends them an email.

```ruby

# This is global is just for demo purposes but would in
# reality be in a database or something
CUSTOMER = {
  full_name: 'John Smith',
  customer_id: 'abcd1234',
  total_spend: {
    currency: 'USD',
    amount_in_cents: 20_000
  },
  credit: {
    currency: 'USD',
    amount_in_cents: 0
  }
}

class Environment
  include Extism::HostEnvironment

  register_import :add_credit, [Extism::ValType::I64, Extism::ValType::I64], [Extism::ValType::I64]
  register_import :send_email, [Extism::ValType::I64, Extism::ValType::I64], []

  def add_credit(plugin, inputs, outputs, _user_data)
    # add_credit takes a string `customer_id` as the first parameter
    customer_id = plugin.input_as_string(inputs.first)
    # it takes an object `amount` { amount_in_cents: int, currency: string } as the second parameter
    amount = plugin.input_as_json(inputs[1])

    # we're just going to print it out and add to the CUSTOMER global
    puts "Adding Credit #{amount} to customer #{customer_id}"
    CUSTOMER[:credit][:amount_in_cents] += amount['amount_in_cents']

    # add_credit returns a Json object with the new customer details
    plugin.return_json(outputs.first, CUSTOMER)
  end

  def send_email(plugin, inputs, _outputs, _user_data)
    # send_email takes a string `customer_id` as the first parameter
    customer_id = plugin.input_as_string(inputs.first)
    # it takes an object `email` { subject: string, body: string } as the second parameter
    email = plugin.input_as_json(inputs[1])

    # we'll just print it but you could imagine we'd put something 
    # in a database or call an internal api to send this email
    puts "Sending email #{email} to customer #{customer_id}"

    # it doesn't return anything
  end
end
```

Now we just need to create a new host environment and pass it in when loading the plug-in. Here our environment initializer takes no arguments, but you could imagine putting some merchant specific instance variables in there:

```ruby
env = Environment.new
plugin = Extism::Plugin.new(manifest, environment: env)
```

Now we can invoke the event:

```ruby
event = {
  event_type: 'charge.succeeded',
  customer: CUSTOMER
}
result = plugin.call('on_charge_succeeded', JSON.generate(event))
```

This will print:

```
Adding Credit {"amount_in_cents"=>1000, "currency"=>"USD"} for customer abcd1234
Sending email {"subject"=>"A gift for you John Smith", "body"=>"You have received $10 in store credi
t!"} to customer abcd1234
```
