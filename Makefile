RUBYGEMS_API_KEY ?=

.PHONY: prepare test

prepare:
	bundle install
	bundle binstubs --all

test: prepare
	bundle exec rake test

clean:
	rm -f extism-*.gem

publish-local: clean prepare
	gem build extism.gemspec
	gem push extism-*.gem

publish: clean prepare
	gem build extism.gemspec
	GEM_HOST_API_KEY=$(RUBYGEMS_API_KEY) gem push extism-*.gem

lint:
	bundle exec rufo --check .

format:
	bundle exec rufo .

docs:
	bundle exec yard

show-docs: docs
	open doc/index.html

seed:
	curl -L https://github.com/extism/plugins/releases/latest/download/count_vowels.debug.wasm > wasm/count_vowels.wasm
	curl -L https://github.com/extism/plugins/releases/latest/download/reflect.debug.wasm > wasm/reflect.wasm
	curl -L https://github.com/extism/plugins/releases/latest/download/store_credit.debug.wasm > wasm/store_credit.wasm

