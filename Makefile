.PHONY: test test-file test-watch clean setup

# Встановлення залежностей
setup:
	@echo "📦 Встановлення залежностей..."
	@mkdir -p deps
	@if [ ! -d "deps/plenary.nvim" ]; then \
		git clone --depth 1 https://github.com/nvim-lua/plenary.nvim deps/plenary.nvim; \
		echo "✅ plenary.nvim встановлено"; \
	else \
		echo "✅ plenary.nvim вже встановлено"; \
	fi

# Запуск всіх тестів
test: setup
	nvim --headless --noplugin -u tests/minimal_init.lua \
		-c "lua require('plenary.test_harness').test_directory('tests/nvim-agent', { minimal_init = 'tests/minimal_init.lua' })"

# Запуск конкретного тестового файлу
test-file: setup
	@if [ -z "$(FILE)" ]; then \
		echo "Usage: make test-file FILE=tests/nvim-agent/config_spec.lua"; \
		exit 1; \
	fi
	nvim --headless --noplugin -u tests/minimal_init.lua -c "PlenaryBustedFile $(FILE)"

# Запуск тестів у watch режимі (потребує entr)
test-watch: setup
	find lua tests -name "*.lua" | entr -c make test

# Очистка
clean:
	rm -rf nvim-agent.log
	rm -rf tests/*.log
	rm -rf deps/

# Показати покриття (якщо встановлено luacov)
coverage:
	@echo "Coverage report:"
	@luacov-console
	@luacov-console -s
