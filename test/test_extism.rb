# frozen_string_literal: true

require 'test_helper'

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

  attr_accessor :credit_args, :email_args

  def add_credit(plugin, inputs, outputs, _user_data)
    customer_id = plugin.input_as_string(inputs.first)
    amount = plugin.input_as_json(inputs[1])
    self.credit_args = [customer_id, amount]
    plugin.output_json(outputs.first, CUSTOMER)
  end

  def send_email(plugin, inputs, _outputs, _user_data)
    customer_id = plugin.input_as_string(inputs.first)
    email = plugin.input_as_json(inputs[1])
    self.email_args = [customer_id, email]
  end
end

class TestExtism < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil Extism::VERSION
  end

  def test_plugin_call
    plugin = Extism::Plugin.new(vowels_manifest)
    res = JSON.parse(plugin.call('count_vowels', 'this is a test'))
    assert_equal res['count'], 4
    res = JSON.parse(plugin.call('count_vowels', 'this is a test again'))
    assert_equal res['count'], 7
    res = JSON.parse(plugin.call('count_vowels', 'this is a test thrice'))
    assert_equal res['count'], 6
    res = JSON.parse(plugin.call('count_vowels', '🌎hello🌎world🌎'))
    assert_equal res['count'], 3
  end

  def test_can_free_plugin
    plugin = Extism::Plugin.new(vowels_manifest)
    _res = plugin.call('count_vowels', 'this is a test')
    plugin.free
    assert_raises(Extism::Error) do
      _res = plugin.call('count_vowels', 'this is a test')
    end
  end

  def test_errors_on_bad_manifest
    assert_raises(Extism::Error) do
      _plugin = Extism::Plugin.new({ not_a_real_manifest: true })
    end
  end

  def test_has_function
    plugin = Extism::Plugin.new(vowels_manifest)
    assert plugin.has_function? 'count_vowels'
    refute plugin.has_function? 'i_am_not_a_function'
  end

  def test_errors_on_unknown_function
    plugin = Extism::Plugin.new(vowels_manifest)
    assert_raises(Extism::Error) do
      plugin.call('non_existent_function', 'input')
    end
  end

  def test_host_functions
    func = proc do |current_plugin, inputs, outputs, user_data|
      input = current_plugin.input_as_string(inputs.first)
      current_plugin.output_string(outputs.first, "#{input} #{user_data}")
    end
    f = Extism::Function.new('host_reflect', [Extism::ValType::I64], [Extism::ValType::I64], func,
                             user_data: 'My User Data')
    plugin = Extism::Plugin.new(reflect_manifest, functions: [f], wasi: true)
    result = plugin.call('reflect', 'Hello, World!')
    assert_equal result, 'Hello, World! My User Data'
  end

  def test_environment
    env = Environment.new
    plugin = Extism::Plugin.new(store_credit_manifest, environment: env, wasi: true)
    _result = plugin.call('on_charge_succeeded', JSON.generate({ event_type: 'charge.succeeded', customer: CUSTOMER }))
    assert_equal env.credit_args[0], 'abcd1234'
    assert_equal env.credit_args[1], { 'amount_in_cents' => 1_000, 'currency' => 'USD' }
    assert_equal env.email_args[0], 'abcd1234'
    assert_equal env.email_args[1],
                 { 'subject' => 'A gift for you John Smith', 'body' => 'You have received $10 in store credit!' }
  end

  private

  def vowels_manifest
    Extism::Manifest.from_path File.join(__dir__, '../wasm/count_vowels.wasm')
  end

  def reflect_manifest
    Extism::Manifest.from_path File.join(__dir__, '../wasm/reflect.wasm')
  end

  def store_credit_manifest
    Extism::Manifest.from_path File.join(__dir__, '../wasm/store_credit.wasm')
  end
end
