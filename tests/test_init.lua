-- Тестова ініціалізація для запуску nvim-agent
-- Використання: nvim -u tests/test_init.lua

-- ВАЖЛИВО: Встановлюємо leader key ПЕРШИМ
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Отримуємо абсолютний шлях до проекту
local cwd = vim.fn.getcwd()

-- Встановлюємо runtimepath (включаємо стандартний runtime)
vim.opt.runtimepath:prepend(cwd)
vim.opt.runtimepath:append(vim.fn.stdpath('data') .. '/site')

-- Додаємо плагін до runtimepath
-- (вже зроблено вище через prepend)

-- Додаємо plenary.nvim до runtimepath (якщо є)
local plenary_dir = cwd .. '/deps/plenary.nvim'
local plenary_lua = plenary_dir .. '/lua'
local stat = vim.loop.fs_stat(plenary_lua)
if stat then
    vim.opt.rtp:prepend(plenary_dir)
end

-- Базова конфігурація
vim.o.swapfile = false
vim.o.backup = false
vim.o.writebackup = false
vim.o.termguicolors = true

-- Leader key вже встановлений на початку файлу

-- Налаштування nvim-agent
require('nvim-agent').setup({
    api = {
        provider = "github-copilot",
        model = "gpt-4o",
    },
    ui = {
        show_help = true,
    },
    keymaps = {
        toggle_chat = "<leader>aa",      -- Змінено з <leader>cc на <leader>aa
        explain_code = "<leader>ae",     -- explain
        generate_code = "<leader>ag",    -- generate
        refactor_code = "<leader>ar",    -- refactor
        generate_tests = "<leader>at",   -- tests
        generate_docs = "<leader>ad",    -- docs
        cycle_mode = "<leader>am",       -- cycle mode
    },
})

-- Виводимо повідомлення
print("nvim-agent тестова конфігурація завантажена!")
print("Leader key: " .. vim.g.mapleader)
print("")
print("Доступні кеймапи:")
print("  <Space>aa - Відкрити/закрити чат")
print("  <Space>ae - Пояснити код (visual mode)")
print("  <Space>ag - Згенерувати код")
print("  <Space>ar - Рефакторинг (visual mode)")
print("  <Space>at - Створити тести (visual mode)")
print("  <Space>ad - Створити документацію (visual mode)")
print("  <Space>am - Змінити режим (Ask/Edit/Agent)")
print("")
print("Або використовуйте команду: :NvimAgentChat")
