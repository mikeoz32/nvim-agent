# Tests

Тести для nvim-agent написані з використанням [plenary.nvim](https://github.com/nvim-lua/plenary.nvim).

## 🎯 Швидкий старт

### Автоматичні тести (базові функції)
```bash
nvim -u tests/test_init.lua -l tests/quick_test.lua
```
✅ **Статус:** Всі 10 базових тестів пройшли успішно!

### Візуальне тестування (UI)
```bash
# Windows PowerShell
.\tests\visual_test.ps1

# Або вручну
nvim -u tests/test_init.lua tests/test_code.lua
```

Детальний чеклист: [manual_test.md](manual_test.md)

## Встановлення

plenary.nvim встановлюється автоматично в `deps/` при запуску тестів:

```bash
# Linux/macOS - автоматично встановить залежності
make test

# Windows
.\test.ps1
```

Або встановіть вручну:

```bash
git clone --depth 1 https://github.com/nvim-lua/plenary.nvim deps/plenary.nvim
```

## Запуск тестів

### Всі тести

```bash
make test
```

### Конкретний файл

```bash
make test-file FILE=tests/nvim-agent/config_spec.lua
```

### В інтерактивному режимі

```bash
nvim -u tests/minimal_init.lua
:PlenaryBustedDirectory tests/nvim-agent/
```

### Watch режим (потребує entr)

```bash
make test-watch
```

## Структура

```
tests/
├── nvim-agent/           # Тести модулів плагіна
│   ├── config_spec.lua   # Тести конфігурації
│   ├── mcp_spec.lua      # Тести MCP tools
│   ├── copilot_spec.lua  # Тести Copilot API
│   └── sessions_spec.lua # Тести сесій
├── helpers.lua           # Допоміжні функції для тестів
└── minimal_init.lua      # Мінімальна конфігурація для тестів
```

## Написання тестів

Приклад тесту:

```lua
local my_module = require('nvim-agent.my_module')

describe("my_module", function()
    describe("my_function", function()
        it("should do something", function()
            local result = my_module.my_function()
            assert.equals("expected", result)
        end)
        
        it("should handle errors", function()
            assert.has_error(function()
                my_module.my_function(nil)
            end)
        end)
    end)
end)
```

## Assertions

Доступні assertions від plenary.nvim:

- `assert.equals(expected, actual)`
- `assert.is_true(value)`
- `assert.is_false(value)`
- `assert.is_nil(value)`
- `assert.is_not_nil(value)`
- `assert.is_string(value)`
- `assert.is_number(value)`
- `assert.is_table(value)`
- `assert.is_function(value)`
- `assert.has_error(function)`
- `assert.matches(pattern, string)`

## Hooks

- `before_each(function)` - виконується перед кожним тестом
- `after_each(function)` - виконується після кожного тесту
- `before_all(function)` - виконується один раз перед всіма тестами
- `after_all(function)` - виконується один раз після всіх тестів

## CI/CD

Тести автоматично запускаються в GitHub Actions при:
- Push в main/develop гілки
- Pull Request

Тестується на:
- Ubuntu, Windows, macOS
- Neovim stable та nightly

## Debugging

Для debug логів в тестах:

```lua
it("should debug something", function()
    print("Debug:", vim.inspect(value))
end)
```

Або запустіть тести з verbose:

```bash
nvim --headless -u tests/minimal_init.lua \
  -c "lua vim.g.busted_output_type = 'plainTerminal'" \
  -c "PlenaryBustedDirectory tests/nvim-agent/"
```
