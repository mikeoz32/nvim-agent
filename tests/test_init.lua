-- Тестова ініціалізація для запуску nvim-agent
-- Використання: nvim -u tests/test_init.lua

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

-- Встановлюємо leader key
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Налаштування nvim-agent
require('nvim-agent').setup({
    api = {
        provider = "github-copilot",
        model = "gpt-4o",
    },
    ui = {
        show_help = true,
    },
})

-- Виводимо повідомлення
print("nvim-agent тестова конфігурація завантажена!")
print("Використовуйте :NvimAgentChat для відкриття чату")
print("Або натисніть <leader>aa")
