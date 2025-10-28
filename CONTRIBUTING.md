# Contributing Guide

Дякуємо за інтерес до розвитку nvim-agent! 🎉

## Налаштування середовища

### 1. Клонування репозиторію

```bash
git clone https://github.com/your-username/nvim-agent.git
cd nvim-agent
```

### 2. Встановлення залежностей

Залежності встановлюються автоматично в `deps/`:

```bash
# Linux/macOS
make setup

# Або просто запустіть тести (автоматично встановить)
make test
```

```powershell
# Windows
.\test.ps1
```

### 3. Запуск тестів

**Linux/macOS:**

```bash
make test
```

**Windows:**

```powershell
.\test.ps1
```

## Структура проекту

```
nvim-agent/
├── lua/nvim-agent/        # Основний код
│   ├── api/               # API адаптери (Copilot, OpenAI, etc.)
│   ├── ui/                # UI компоненти
│   ├── config.lua         # Конфігурація
│   ├── chat.lua           # Логіка чату
│   ├── mcp.lua            # MCP tools
│   └── ...
├── tests/                 # Тести
│   ├── nvim-agent/        # Unit тести
│   └── helpers.lua        # Допоміжні функції
└── docs/                  # Документація
```

## Написання коду

### Стиль коду

- **Відступи**: 4 пробіли
- **Імена**: snake_case для функцій і змінних
- **Коментарі**: Українською або англійською
- **Максимальна довжина рядка**: 120 символів

Приклад:

```lua
-- Добре ✅
function M.process_chat_request(message, context, previous_messages)
    local messages = previous_messages or {}
    -- ...
end

-- Погано ❌
function M.processChatRequest(msg, ctx, prev)
    local m = prev or {}
    -- ...
end
```

### Документування коду

Використовуйте LuaDoc коментарі для функцій:

```lua
--- Обробляє запит чату
--- @param message string Повідомлення користувача
--- @param context table|nil Контекст (файл, вибраний код)
--- @param previous_messages table|nil Попередні повідомлення
--- @return boolean success Чи успішно оброблено
function M.process_chat_request(message, context, previous_messages)
    -- ...
end
```

## Тестування

### Написання тестів

Всі нові функції мають бути покриті тестами. Розмістіть тести в `tests/nvim-agent/`.

Приклад тесту:

```lua
local my_module = require('nvim-agent.my_module')

describe("my_module", function()
    describe("my_function", function()
        before_each(function()
            -- Підготовка перед кожним тестом
        end)
        
        it("should handle valid input", function()
            local result = my_module.my_function("input")
            assert.equals("expected", result)
        end)
        
        it("should handle errors gracefully", function()
            assert.has_error(function()
                my_module.my_function(nil)
            end)
        end)
        
        after_each(function()
            -- Очистка після кожного тесту
        end)
    end)
end)
```

### Запуск тестів

```bash
# Всі тести
make test

# Конкретний файл
make test-file FILE=tests/nvim-agent/my_module_spec.lua

# З детальним виводом
nvim --headless -u tests/minimal_init.lua \
  -c "lua vim.g.busted_output_type = 'plainTerminal'" \
  -c "PlenaryBustedDirectory tests/nvim-agent/"
```

### Покриття тестами

Намагайтесь досягти >80% покриття для нового коду.

## Git Workflow

### Робота з гілками

```bash
# Створіть гілку від main
git checkout main
git pull origin main
git checkout -b feature/my-feature

# Або для багфіксів
git checkout -b fix/issue-123
```

### Коміти

Використовуйте [Conventional Commits](https://www.conventionalcommits.org/):

```bash
# Features
git commit -m "feat: add support for Claude API"
git commit -m "feat(mcp): add new tool for git operations"

# Bug fixes
git commit -m "fix: handle nil values in context"
git commit -m "fix(ui): prevent window flicker on resize"

# Documentation
git commit -m "docs: update installation guide"

# Tests
git commit -m "test: add tests for sessions module"

# Refactoring
git commit -m "refactor: simplify token exchange logic"
```

### Pull Request

1. Переконайтесь що всі тести проходять
2. Оновіть документацію якщо потрібно
3. Опишіть зміни в PR description
4. Прив'яжіть до issue якщо є: "Closes #123"

Шаблон PR:

```markdown
## Опис
Коротко опишіть що змінено та навіщо.

## Тип змін
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Тестування
Опишіть як ви тестували зміни.

## Checklist
- [ ] Код відповідає стилю проекту
- [ ] Додано/оновлено тести
- [ ] Всі тести проходять
- [ ] Оновлена документація
- [ ] Коміти відповідають Conventional Commits
```

## Debugging

### Локальне тестування

```lua
-- В init.lua або test config
require('nvim-agent').setup({
    debug = {
        enabled = true,
        log_level = "trace",  -- trace, debug, info, warn, error
        log_file = "nvim-agent.log"
    }
})
```

### Перегляд логів

```bash
tail -f nvim-agent.log
```

### Debug в тестах

```lua
it("should debug something", function()
    print("Debug:", vim.inspect(value))
    
    -- Або використайте helpers
    local helpers = require('helpers')
    helpers.debug_print(value)
end)
```

## Часті питання

### Як додати новий MCP tool?

1. Відкрийте `lua/nvim-agent/mcp.lua`
2. Додайте tool до масиву `tools`:

```lua
{
    name = "my_tool",
    description = "Що робить інструмент",
    parameters = {
        type = "object",
        properties = {
            param1 = {
                type = "string",
                description = "Опис параметра"
            }
        },
        required = {"param1"}
    },
    handler = function(params)
        -- Реалізація
        return {
            success = true,
            result = "..."
        }
    end
}
```

3. Додайте тести в `tests/nvim-agent/mcp_spec.lua`

### Як додати підтримку нового AI провайдера?

1. Створіть файл `lua/nvim-agent/api/my_provider.lua`
2. Реалізуйте інтерфейс:

```lua
local M = {}

function M.chat(messages, options, callback)
    -- Реалізація API виклику
    -- callback(err, response, tool_calls)
end

function M.supports_tools()
    return true  -- або false
end

return M
```

3. Додайте до `lua/nvim-agent/config.lua` в `available_providers`
4. Додайте тести

## Ресурси

- [Neovim API Documentation](https://neovim.io/doc/user/api.html)
- [Lua 5.1 Reference](https://www.lua.org/manual/5.1/)
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- [GitHub Copilot API](https://docs.github.com/en/copilot)

## Отримання допомоги

- 💬 Задайте питання в [Discussions](https://github.com/your-username/nvim-agent/discussions)
- 🐛 Повідомте про баг в [Issues](https://github.com/your-username/nvim-agent/issues)
- 📧 Напишіть на email: your-email@example.com

---

Дякуємо за ваш внесок! 🙏
