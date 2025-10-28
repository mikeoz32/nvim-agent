# Тестування nvim-agent локально

## Швидкий старт

### 1. Мінімальна конфігурація для тестування

Створіть тестовий файл `test_config.lua`:

```lua
-- Додайте шлях до плагіна
vim.opt.runtimepath:append("d:/work/nvim-agent")

-- Базова конфігурація Neovim
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.expandtab = true
vim.opt.shiftwidth = 4
vim.opt.tabstop = 4

-- Налаштування плагіна
require('nvim-agent').setup({
    api = {
        provider = "openai",  -- або "local" для тестування без API
        model = "gpt-4",
        api_key = os.getenv("OPENAI_API_KEY"),
        -- Для локального тестування без API:
        -- provider = "local",
        -- endpoint = "http://localhost:11434/v1",  -- Ollama
    },
    ui = {
        chat = {
            width = 50,
            height = 80,
            position = "right",
            border = "rounded",
        }
    },
    mcp = {
        enabled = true,
        review_mode_default = false,
    },
    keymaps = {
        toggle_chat = "<leader>cc",
        explain_code = "<leader>ce",
        generate_code = "<leader>cg",
        toggle_mode = "<leader>cm",
    },
    debug = {
        enabled = true,
        log_level = "debug",
    }
})

-- Гарячі клавіші для тестування
vim.keymap.set('n', '<leader>cc', ':NvimAgentChat<CR>', { desc = 'Toggle Chat' })
vim.keymap.set('n', '<leader>cm', ':NvimAgentToggleMode<CR>', { desc = 'Toggle Mode' })
vim.keymap.set('v', '<leader>ce', ':NvimAgentExplain<CR>', { desc = 'Explain' })

-- Швидкі команди для тестування
vim.keymap.set('n', '<leader>t1', function()
    vim.cmd('NvimAgentReviewMode on')
    vim.notify('Review mode ON', vim.log.levels.INFO)
end, { desc = 'Test: Enable Review Mode' })

vim.keymap.set('n', '<leader>t2', function()
    vim.cmd('NvimAgentMode agent')
    vim.notify('Agent mode ON', vim.log.levels.INFO)
end, { desc = 'Test: Agent Mode' })

vim.keymap.set('n', '<leader>t3', ':NvimAgentChangesStats<CR>', { desc = 'Test: Stats' })

print("✅ nvim-agent test config loaded!")
print("🎯 Hotkeys: <leader>cc (chat), <leader>cm (mode), <leader>t1/t2/t3 (tests)")
```

### 2. Запуск Neovim з тестовою конфігурацією

```powershell
# У PowerShell
cd d:\work\nvim-agent

# Запустити Neovim з тестовою конфігурацією
nvim -u test_config.lua

# Або створити alias для зручності
function Test-NvimAgent {
    nvim -u "d:\work\nvim-agent\test_config.lua" $args
}

# Використання:
Test-NvimAgent test_file.js
```

### 3. Базові тести

#### Тест 1: Перевірка завантаження

```vim
" У Neovim виконайте:
:lua print(require('nvim-agent').version or 'loaded')

" Має вивести 'loaded' або версію
```

#### Тест 2: Відкрити чат

```vim
:NvimAgentChat

" або
<leader>cc

" Має відкритися вікно чату справа
```

#### Тест 3: Перевірка режимів

```vim
" Переключити режим
<leader>cm

" Або
:NvimAgentMode agent

" Перевірити поточний режим
:lua print(require('nvim-agent.modes').get_current_mode())
```

#### Тест 4: Review Mode

```vim
" Увімкнути review mode
<leader>t1
" або
:NvimAgentReviewMode on

" Перевірити статус
:lua print(require('nvim-agent.mcp').review_mode)
" Має вивести: true
```

#### Тест 5: Inline кнопки (mock)

Створіть тестовий файл для демонстрації:

```vim
" Відкрийте новий файл
:e test_demo.lua

" Вставте тестовий код
function test()
    print("test")
end

" У чаті (якщо є API ключ) або вручну протестуйте:
:lua require('nvim-agent.ui.inline_buttons').setup()

" Створіть mock кнопки
:lua local buttons = require('nvim-agent.ui.inline_buttons')
:lua buttons.show_buttons(vim.api.nvim_get_current_buf(), 5, {1, 2, 3})

" Підведіть курсор до рядка 5 і натисніть ga/gd
```

### 4. Тестування без API ключа

Якщо немає API ключа, можна протестувати UI та базову функціональність:

```lua
-- У test_config.lua використайте mock provider:
require('nvim-agent').setup({
    api = {
        provider = "mock",  -- Mock провайдер для тестування
    },
    -- ... решта конфігурації
})
```

Створіть файл `lua/nvim-agent/api/mock.lua`:

```lua
-- Mock API провайдер для тестування
local M = {}

function M.chat(messages, options, callback)
    -- Симулюємо затримку API
    vim.defer_fn(function()
        local mock_response = {
            content = "Це mock відповідь від AI. API провайдер не налаштований.",
            tool_calls = nil
        }
        callback(mock_response, nil)
    end, 500)
end

function M.supports_tools()
    return true
end

return M
```

### 5. Автоматичні тести

Створіть `tests/basic_test.lua`:

```lua
-- Базові автоматичні тести
local nvim_agent = require('nvim-agent')
local chat_window = require('nvim-agent.ui.chat_window')
local inline_buttons = require('nvim-agent.ui.inline_buttons')
local change_manager = require('nvim-agent.change_manager')

print("\n=== Running nvim-agent tests ===\n")

-- Тест 1: Ініціалізація
print("Test 1: Initialization...")
local ok = pcall(function()
    nvim_agent.setup({
        api = { provider = "mock" }
    })
end)
assert(ok, "❌ Failed to initialize nvim-agent")
print("✅ Initialization passed")

-- Тест 2: Chat window
print("\nTest 2: Chat window...")
local ok = pcall(function()
    chat_window.create_window()
    assert(chat_window.is_open(), "Chat window not open")
    chat_window.close()
    assert(not chat_window.is_open(), "Chat window still open")
end)
assert(ok, "❌ Chat window test failed")
print("✅ Chat window test passed")

-- Тест 3: Change manager
print("\nTest 3: Change manager...")
local change = change_manager.create_change(
    change_manager.CHANGE_TYPE.FILE_MODIFY,
    { path = "/tmp/test.txt", content = "test" }
)
assert(change.id, "Change ID not created")
assert(change.type == "file_modify", "Wrong change type")
print("✅ Change manager test passed")
print("   Change ID: " .. change.id)

-- Тест 4: Inline buttons (visual only)
print("\nTest 4: Inline buttons...")
local ok = pcall(function()
    inline_buttons.setup()
end)
assert(ok, "❌ Inline buttons setup failed")
print("✅ Inline buttons test passed")

-- Тест 5: Highlight groups
print("\nTest 5: Highlight groups...")
local highlights = {
    'NvimAgentButtonAccept',
    'NvimAgentButtonDiscard',
    'NvimAgentButtonAcceptAll',
    'NvimAgentButtonDiscardAll',
}
for _, hl in ipairs(highlights) do
    local ok = pcall(vim.api.nvim_get_hl, 0, { name = hl })
    assert(ok, "❌ Highlight group " .. hl .. " not found")
end
print("✅ Highlight groups test passed")

print("\n=== All tests passed! ✅ ===\n")
```

Запустити тести:

```vim
:luafile tests/basic_test.lua
```

### 6. Ручне тестування UI

#### Тест візуального feedback:

```vim
" Запустіть тестовий файл
:luafile test_tool_status.lua

" Має показати 8 прикладів tool execution з іконками
```

#### Тест review mode:

```vim
" Запустіть тестовий файл
:luafile test_review_mode.lua

" Створює mock зміни і показує як працює система
```

#### Тест inline кнопок:

```vim
" У чаті створіть тестову ситуацію:
:NvimAgentReviewMode on
:NvimAgentMode agent

" У чаті напишіть (якщо є API):
> Створи файл test.txt з текстом "Hello"

" Або вручну:
:lua local cm = require('nvim-agent.change_manager')
:lua local change = cm.create_change(cm.CHANGE_TYPE.FILE_CREATE, {path='/tmp/test.txt', content='Hello'})
:lua cm.add_change(change)
:lua local chat_buf = require('nvim-agent.ui.chat_window').get_chat_buffer()
:lua require('nvim-agent.ui.inline_buttons').show_buttons(chat_buf, 10, {change.id})

" Підведіть курсор до рядка 10 і натисніть ga
```

### 7. Перевірка логів

```vim
" Переглянути логи
:messages

" Або детальніше
:lua vim.print(require('nvim-agent.utils').get_logs())

" Або у файлі
:!cat ~/.cache/nvim/nvim-agent.log
```

### 8. Debugging

Якщо щось не працює:

```vim
" 1. Перевірити чи завантажені модулі
:lua print(package.loaded['nvim-agent'])
:lua print(package.loaded['nvim-agent.chat'])
:lua print(package.loaded['nvim-agent.ui.inline_buttons'])

" 2. Перевірити помилки
:checkhealth nvim-agent

" 3. Перезавантажити плагін
:lua package.loaded['nvim-agent'] = nil
:lua require('nvim-agent').setup({...})

" 4. Verbose mode
:set verbose=15
:NvimAgentChat
:set verbose=0
```

### 9. Тестування з Ollama (локально)

Якщо не хочете витрачати API токени:

```powershell
# Встановіть Ollama
winget install Ollama.Ollama

# Запустіть модель
ollama run llama2

# У іншому терміналі запустіть Neovim
nvim -u test_config.lua
```

У `test_config.lua`:

```lua
api = {
    provider = "local",
    endpoint = "http://localhost:11434/v1",
    model = "llama2",
}
```

### 10. Швидкий чеклист тестування

```
□ Neovim відкривається з test_config.lua
□ Команди :NvimAgent* доступні
□ Chat window відкривається (<leader>cc)
□ Режими перемикаються (<leader>cm)
□ Review mode вмикається/вимикається
□ Inline кнопки з'являються (візуально)
□ Highlight groups працюють (кольорові кнопки)
□ ChangesStats показує статистику
□ Логи пишуться (:messages)
□ Немає критичних помилок
```

### 11. GitHub Actions (CI/CD)

Для автоматичного тестування можна створити `.github/workflows/test.yml`:

```yaml
name: Test nvim-agent

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Install Neovim
        run: |
          wget https://github.com/neovim/neovim/releases/download/stable/nvim-linux64.tar.gz
          tar xzf nvim-linux64.tar.gz
          sudo mv nvim-linux64 /opt/nvim
          sudo ln -s /opt/nvim/bin/nvim /usr/local/bin/nvim
      
      - name: Run tests
        run: |
          nvim --headless -u tests/minimal_init.lua -c "luafile tests/basic_test.lua" -c "qall"
```

---

## Готово до тестування! 🚀

**Швидкий старт:**
```powershell
cd d:\work\nvim-agent
nvim -u test_config.lua
```

**У Neovim:**
```vim
<leader>cc    " Відкрити чат
<leader>t1    " Увімкнути review mode
<leader>t2    " Переключити на agent mode
```

Все готово для локального тестування! 🎉
