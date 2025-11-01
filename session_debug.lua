local sessions = require("nvim-agent.chat_sessions")

-- Логування помилок
local status, session = pcall(sessions.get_current_session)
if not status then
    vim.api.nvim_err_writeln("Помилка завантаження сесії: " .. tostring(session))
    return
end

-- Якщо сесія відсутня
if not session then
    vim.api.nvim_err_writeln("Немає активної сесії.")
    return
end

-- Створюємо новий буфер із вмістом сесії
local buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_option(buf, "filetype", "json")
vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.fn.split(vim.inspect(session), "\n"))

-- Відкриваємо буфер у новому вікні
vim.api.nvim_command("vsplit")
vim.api.nvim_set_current_buf(buf)
