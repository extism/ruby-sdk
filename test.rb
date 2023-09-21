require_relative './lib/extism'

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

class HostEnvironment
  def add_credit(plugin, inputs, outputs, _user_data)
    customer_id = plugin.input_as_string(inputs.first)
    amount = plugin.input_as_json(inputs[1])

    puts "Adding Credit #{amount} to customer #{customer_id}"
    CUSTOMER[:credit][:amount_in_cents] += amount['amount_in_cents']

    plugin.return_json(outputs.first, CUSTOMER)
  end

  def send_email(plugin, inputs, _outputs, _user_data)
    customer_id = plugin.input_as_string(inputs.first)
    email = plugin.input_as_json(inputs[1])

    puts "Sending email #{email} to customer #{customer_id}"
  end

  def host_functions
    [
      Extism::Function.new(
        'add_credit',
        [Extism::ValType::I64, Extism::ValType::I64],
        [Extism::ValType::I64],
        method(:add_credit).to_proc
      ),
      Extism::Function.new(
        'send_email',
        [Extism::ValType::I64, Extism::ValType::I64],
        [],
        method(:send_email).to_proc
      )
    ]
  end
end

manifest = {
  wasm: [
    { url: 'https://github.com/extism/plugins/releases/latest/download/store_credit.wasm' }
  ]
}
plugin = Extism::Plugin.new(manifest, environment: HostEnvironment.new)
puts plugin
event = {
  event_type: 'charge.succeeded',
  customer: CUSTOMER
}
result = plugin.call('on_charge_succeeded', JSON.generate(event))
puts 'Called'
puts result
