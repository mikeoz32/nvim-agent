-- Тестова ініціалізація для запуску nvim-agent
-- Використання: nvim -u tests/test_init.lua

-- ВАЖЛИВО: Встановлюємо leader key ПЕРШИМ
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Отримуємо абсолютний шлях до проекту
local cwd = vim.fn.getcwd()

-- Встановлюємо lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  print("Installing lazy.nvim...")
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
  print("lazy.nvim installed!")
end
vim.opt.rtp:prepend(lazypath)

-- Встановлюємо плагіни через lazy.nvim
require("lazy").setup({
  -- nui.nvim - базова бібліотека
  {
    "MunifTanjim/nui.nvim",
    lazy = false,
    priority = 1000,
  },
  
  -- nui-components.nvim - розширені компоненти
  {
    "grapp-dev/nui-components.nvim",
    dependencies = { "MunifTanjim/nui.nvim" },
    lazy = false,
    priority = 900,
  },
  
  -- nvim-agent (локальний)
  {
    dir = cwd,
    name = "nvim-agent",
    dependencies = {
      "MunifTanjim/nui.nvim",
      "grapp-dev/nui-components.nvim",
    },
    lazy = false,
  },
}, {
  install = { colorscheme = { "habamax" } },
  ui = { border = "rounded" },
})

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
print("\n" .. string.rep("=", 60))
print("nvim-agent тестова конфігурація завантажена!")
print(string.rep("=", 60))
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
print("Команди:")
print("  :NvimAgentChat")
print("  :lua require('nvim-agent.ui.chat_nui').create_window()")
print("")
print("Тестування chat_nui.lua:")
print("  1. Відкрийте чат вище вказаною командою")
print("  2. Введіть багаторядковий текст - має автоматично розтягнутись")
print("  3. Ctrl+Enter - відправка, Esc - закриття")
print(string.rep("=", 60) .. "\n")
