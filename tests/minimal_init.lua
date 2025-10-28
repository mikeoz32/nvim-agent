-- Мінімальна ініціалізація для тестів
vim.cmd [[set runtimepath=$VIMRUNTIME]]
vim.cmd [[set packpath=/tmp/nvim/site]]

-- Отримуємо абсолютний шлях до проекту
local cwd = vim.fn.getcwd()

-- Додаємо плагін до runtimepath
vim.opt.rtp:prepend(cwd)

-- Додаємо plenary.nvim до runtimepath
local plenary_dir = cwd .. '/deps/plenary.nvim'
vim.opt.rtp:prepend(plenary_dir)

-- Перевіряємо чи plenary існує
local plenary_lua = plenary_dir .. '/lua'
local stat = vim.loop.fs_stat(plenary_lua)
if not stat then
    error('plenary.nvim not found at: ' .. plenary_dir .. '\nRun: ./setup.ps1')
end

-- Додаємо helpers до path
package.path = package.path .. ';' .. cwd .. '/tests/?.lua'

-- Завантажуємо plenary
require('plenary.busted')

-- Базова конфігурація
vim.o.swapfile = false
vim.o.backup = false
vim.o.writebackup = false
