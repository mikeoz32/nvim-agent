-- Plugin ініціалізація для Neovim
-- Цей файл автоматично завантажується Neovim при старті

if vim.g.loaded_nvim_agent == 1 then
    return
end
vim.g.loaded_nvim_agent = 1

-- Перевіряємо версію Neovim
if vim.fn.has('nvim-0.7.0') == 0 then
    vim.api.nvim_err_writeln("nvim-agent потребує Neovim 0.7.0 або новішу версію")
    return
end

-- Створюємо глобальну команду для налаштування плагіна
vim.api.nvim_create_user_command('NvimAgentSetup', function()
    require('nvim-agent').setup()
end, {
    desc = 'Ініціалізувати nvim-agent плагін'
})

-- Автоматична ініціалізація (можна відключити через змінну)
if vim.g.nvim_agent_auto_setup ~= 0 then
    -- Відкладаємо ініціалізацію до завершення завантаження
    vim.schedule(function()
        require('nvim-agent').setup()
    end)
end