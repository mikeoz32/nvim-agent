-- UI компонент для чат-вікна
local M = {}

local config = require('nvim-agent.config')
local utils = require('nvim-agent.utils')
local modes = require('nvim-agent.modes')

-- Локальні змінні для вікна
local chat_buf = nil
local chat_win = nil
local input_buf = nil
local input_win = nil
local is_open = false

-- Створення чат-вікна
function M.create_window()
    if is_open then
        return false
    end
    
    local cfg = config.get()
    local ui_config = cfg.ui.chat
    
    -- Розміри екрана
    local screen_width = vim.o.columns
    local screen_height = vim.o.lines - vim.o.cmdheight - 1 -- віднімаємо командний рядок
    
    -- Розраховуємо розміри вікна
    local width = math.floor(screen_width * ui_config.width / 100)
    local height = math.floor(screen_height * ui_config.height / 100)
    
    -- Позиція залежно від налаштувань
    local col, row
    if ui_config.position == "right" then
        col = screen_width - width
        row = 0
    elseif ui_config.position == "left" then
        col = 0
        row = 0
    elseif ui_config.position == "bottom" then
        col = math.floor((screen_width - width) / 2)
        row = screen_height - height
    else -- float
        col = math.floor((screen_width - width) / 2)
        row = math.floor((screen_height - height) / 2)
    end
    
    -- Висота для чату та input
    local chat_height = height - 3  -- залишаємо місце для input
    local input_height = 1
    
    -- Створюємо буфери
    chat_buf = vim.api.nvim_create_buf(false, true)
    input_buf = vim.api.nvim_create_buf(false, true)
    
    -- Налаштування чат-буфера
    vim.api.nvim_buf_set_option(chat_buf, "buftype", "nofile")
    vim.api.nvim_buf_set_option(chat_buf, "bufhidden", "wipe")
    vim.api.nvim_buf_set_option(chat_buf, "modifiable", false)
    vim.api.nvim_buf_set_option(chat_buf, "filetype", "markdown")
    vim.api.nvim_buf_set_option(chat_buf, "wrap", true)
    vim.api.nvim_buf_set_option(chat_buf, "linebreak", true)
    
    -- Увімкнути conceal для кращого відображення markdown
    vim.api.nvim_win_set_option(chat_win or 0, "conceallevel", 2)
    vim.api.nvim_win_set_option(chat_win or 0, "concealcursor", "nc")
    
    -- Налаштування input-буфера
    vim.api.nvim_buf_set_option(input_buf, "buftype", "nofile")
    vim.api.nvim_buf_set_option(input_buf, "bufhidden", "wipe")
    vim.api.nvim_buf_set_option(input_buf, "filetype", "markdown")
    
    -- Конфігурація чат-вікна
    local mode_display = modes.format_mode_display()
    local chat_win_config = {
        relative = "editor",
        width = width,
        height = chat_height,
        col = col,
        row = row,
        style = "minimal",
        border = ui_config.border,
        title = ui_config.title .. " [" .. mode_display .. "]",
        title_pos = "center"
    }
    
    -- Конфігурація input-вікна
    local input_win_config = {
        relative = "editor",
        width = width,
        height = input_height,
        col = col,
        row = row + chat_height + 1, -- +1 для border
        style = "minimal",
        border = ui_config.border,
        title = "Введіть повідомлення",
        title_pos = "left"
    }
    
    -- Створюємо вікна
    chat_win = vim.api.nvim_open_win(chat_buf, false, chat_win_config)
    input_win = vim.api.nvim_open_win(input_buf, true, input_win_config)
    
    -- Налаштовуємо опції вікон
    vim.api.nvim_win_set_option(chat_win, "scrolloff", 3)
    vim.api.nvim_win_set_option(chat_win, "wrap", true)
    vim.api.nvim_win_set_option(chat_win, "conceallevel", 2)
    vim.api.nvim_win_set_option(chat_win, "concealcursor", "nc")
    vim.api.nvim_win_set_option(input_win, "wrap", false)
    
    -- Встановлюємо підсвічування
    M.setup_highlights()
    
    -- Встановлюємо хоткеї
    M.setup_keymaps()
    
    -- Налаштовуємо markdown rendering
    M.setup_markdown_rendering()
    
    -- Додаємо початкове повідомлення
    if ui_config.show_help then
        M.add_system_message("Привіт! Я nvim-agent, ваш AI помічник для коду. Як можу допомогти?")
        M.add_system_message("Гарячі клавіші: <Enter> - надіслати, <Shift+Enter> - новий рядок, <Ctrl+L> - очистити, q - закрити (normal mode)")
    end
    
    is_open = true
    return true
end

-- Налаштування markdown rendering
function M.setup_markdown_rendering()
    -- Перевіряємо чи є render-markdown.nvim
    local ok, render_markdown = pcall(require, 'render-markdown')
    
    if ok and chat_buf then
        -- Увімкнути render-markdown для чат-буфера
        -- render-markdown автоматично застосується до markdown buffers
        -- з правильними conceallevel налаштуваннями
        utils.log("info", "render-markdown.nvim доступний для чат-вікна")
    else
        -- Базове markdown відображення через conceal вже налаштовано
        -- (conceallevel=2 встановлено вище)
        utils.log("debug", "Використовується базове markdown rendering (conceallevel)")
    end
end

-- Налаштування підсвічування
function M.setup_highlights()
    local cfg = config.get()
    local highlights = cfg.ui.highlights
    
    -- Встановлюємо хайлайти для чат-вікна
    vim.api.nvim_win_set_option(chat_win, "winhl", 
        "Normal:Normal,FloatBorder:" .. highlights.chat_border)
    
    -- Хайлайти для різних типів повідомлень
    vim.cmd("highlight NvimAgentUser guifg=#61AFEF gui=bold")
    vim.cmd("highlight NvimAgentAI guifg=#98C379 gui=bold") 
    vim.cmd("highlight NvimAgentSystem guifg=#E5C07B gui=italic")
    vim.cmd("highlight NvimAgentCode guifg=#D19A66")
    
    -- Хайлайти для статусів інструментів
    vim.cmd("highlight NvimAgentToolStart guifg=#61AFEF")
    vim.cmd("highlight NvimAgentToolSuccess guifg=#98C379")
    vim.cmd("highlight NvimAgentToolError guifg=#E06C75")
    vim.cmd("highlight NvimAgentToolInfo guifg=#56B6C2")
end

-- Налаштування гарячих клавіш
function M.setup_keymaps()
    local cfg = config.get()
    local keymaps = cfg.keymaps.chat
    
    -- Хоткеї для input-вікна
    vim.api.nvim_buf_set_keymap(input_buf, "i", keymaps.send_message, 
        "<cmd>lua require('nvim-agent.ui.chat_window').send_current_message()<CR>", 
        { noremap = true, silent = true })
    
    vim.api.nvim_buf_set_keymap(input_buf, "n", keymaps.send_message,
        "<cmd>lua require('nvim-agent.ui.chat_window').send_current_message()<CR>",
        { noremap = true, silent = true })
    
    vim.api.nvim_buf_set_keymap(input_buf, "i", keymaps.new_line,
        "<CR>", { noremap = true, silent = true })
    
    -- Закриття чату тільки в normal mode (q) та force close (Ctrl-C)
    vim.api.nvim_buf_set_keymap(input_buf, "n", keymaps.close_chat,
        "<cmd>lua require('nvim-agent.ui.chat_window').close()<CR>",
        { noremap = true, silent = true })
    
    if keymaps.close_chat_force then
        vim.api.nvim_buf_set_keymap(input_buf, "i", keymaps.close_chat_force,
            "<cmd>lua require('nvim-agent.ui.chat_window').close()<CR>",
            { noremap = true, silent = true })
        
        vim.api.nvim_buf_set_keymap(input_buf, "n", keymaps.close_chat_force,
            "<cmd>lua require('nvim-agent.ui.chat_window').close()<CR>",
            { noremap = true, silent = true })
    end
    
    -- Хоткей для переключення режиму в чаті
    if keymaps.cycle_mode then
        vim.api.nvim_buf_set_keymap(input_buf, "n", keymaps.cycle_mode,
            "<cmd>lua require('nvim-agent.chat').cycle_mode()<CR>",
            { noremap = true, silent = true })
        
        vim.api.nvim_buf_set_keymap(input_buf, "i", keymaps.cycle_mode,
            "<cmd>lua require('nvim-agent.chat').cycle_mode()<CR>",
            { noremap = true, silent = true })
    end
    
    -- Хоткеї для чат-вікна  
    vim.api.nvim_buf_set_keymap(chat_buf, "n", keymaps.close_chat,
        "<cmd>lua require('nvim-agent.ui.chat_window').close()<CR>",
        { noremap = true, silent = true })
    
    if keymaps.close_chat_force then
        vim.api.nvim_buf_set_keymap(chat_buf, "n", keymaps.close_chat_force,
            "<cmd>lua require('nvim-agent.ui.chat_window').close()<CR>",
            { noremap = true, silent = true })
    end
    
    vim.api.nvim_buf_set_keymap(chat_buf, "n", keymaps.clear_chat,
        "<cmd>lua require('nvim-agent.ui.chat_window').clear()<CR>",
        { noremap = true, silent = true })
    
    vim.api.nvim_buf_set_keymap(chat_buf, "n", keymaps.focus_input,
        "<cmd>lua require('nvim-agent.ui.chat_window').focus_input()<CR>",
        { noremap = true, silent = true })
    
    if keymaps.cycle_mode then
        vim.api.nvim_buf_set_keymap(chat_buf, "n", keymaps.cycle_mode,
            "<cmd>lua require('nvim-agent.chat').cycle_mode()<CR>",
            { noremap = true, silent = true })
    end
end

-- Додавання повідомлення в чат
function M.add_message(role, content, timestamp)
    if not is_open or not vim.api.nvim_buf_is_valid(chat_buf) then
        return false
    end
    
    timestamp = timestamp or os.date("%H:%M:%S")
    local prefix
    local highlight = "Normal"
    
    if role == "user" then
        prefix = "🧑 Ви"
        highlight = "NvimAgentUser"
    elseif role == "assistant" then
        prefix = "🤖 AI" 
        highlight = "NvimAgentAI"
    elseif role == "system" then
        prefix = "ℹ️  Система"
        highlight = "NvimAgentSystem"
    else
        prefix = "📝 " .. role
    end
    
    -- Форматуємо повідомлення
    local message_lines = {
        "",
        string.format("[%s] %s:", timestamp, prefix),
        ""
    }
    
    -- Додаємо контент
    local content_lines = vim.split(content, "\n")
    for _, line in ipairs(content_lines) do
        table.insert(message_lines, line)
    end
    
    table.insert(message_lines, "")
    
    -- Додаємо в буфер
    vim.api.nvim_buf_set_option(chat_buf, "modifiable", true)
    
    local line_count = vim.api.nvim_buf_line_count(chat_buf)
    vim.api.nvim_buf_set_lines(chat_buf, line_count, line_count, false, message_lines)
    
    vim.api.nvim_buf_set_option(chat_buf, "modifiable", false)
    
    -- Прокручуємо вниз
    M.scroll_to_bottom()
    
    return true
end

-- Додавання повідомлення користувача
function M.add_user_message(content)
    return M.add_message("user", content)
end

-- Додавання відповіді AI
function M.add_ai_message(content) 
    return M.add_message("assistant", content)
end

-- Додавання системного повідомлення
function M.add_system_message(content)
    if not chat_buf or not vim.api.nvim_buf_is_valid(chat_buf) then
        return false
    end
    
    -- Визначаємо тип системного повідомлення за іконкою
    local highlight = "NvimAgentSystem"
    local first_char = content:sub(1, 4)
    
    -- Іконки для різних статусів
    if first_char:match("^[📖📂🔍🔎📦🌳🔧💾✏️⚡🖥️]") then
        -- Початок виконання інструменту
        highlight = "NvimAgentToolStart"
    elseif first_char:match("^✅") then
        -- Успішне виконання
        highlight = "NvimAgentToolSuccess"
    elseif first_char:match("^❌") or first_char:match("^⚠️") then
        -- Помилка або попередження
        highlight = "NvimAgentToolError"
    elseif first_char:match("^[💭🤖ℹ️]") then
        -- Інформаційне повідомлення
        highlight = "NvimAgentToolInfo"
    end
    
    -- Додаємо в буфер
    vim.api.nvim_buf_set_option(chat_buf, "modifiable", true)
    
    local line_count = vim.api.nvim_buf_line_count(chat_buf)
    local lines = vim.split(content, "\n")
    
    -- Якщо це не порожній рядок, додаємо з відступом
    if content ~= "" then
        for i, line in ipairs(lines) do
            lines[i] = "  " .. line  -- Додаємо відступ
        end
    end
    
    vim.api.nvim_buf_set_lines(chat_buf, line_count, line_count, false, lines)
    
    -- Застосовуємо highlight до доданих рядків
    local ns_id = vim.api.nvim_create_namespace("nvim-agent")
    for i = 0, #lines - 1 do
        vim.api.nvim_buf_add_highlight(chat_buf, ns_id, highlight, 
            line_count + i, 0, -1)
    end
    
    vim.api.nvim_buf_set_option(chat_buf, "modifiable", false)
    
    -- Прокручуємо вниз
    M.scroll_to_bottom()
    
    return true
end

-- Отримання поточного введення
function M.get_current_input()
    if not input_buf or not vim.api.nvim_buf_is_valid(input_buf) then
        return ""
    end
    
    local lines = vim.api.nvim_buf_get_lines(input_buf, 0, -1, false)
    return table.concat(lines, "\n"):gsub("^%s+", ""):gsub("%s+$", "") -- тримаємо пробіли
end

-- Очищення поля введення
function M.clear_input()
    if input_buf and vim.api.nvim_buf_is_valid(input_buf) then
        vim.api.nvim_buf_set_lines(input_buf, 0, -1, false, {""})
    end
end

-- Надсилання поточного повідомлення
function M.send_current_message()
    local message = M.get_current_input()
    
    if message == "" then
        vim.notify("Введіть повідомлення перед надсиланням", vim.log.levels.WARN)
        return
    end
    
    -- Додаємо повідомлення користувача в чат
    M.add_user_message(message)
    
    -- Очищуємо input
    M.clear_input()
    
    -- Викликаємо функцію обробки повідомлення
    local chat = require('nvim-agent.chat')
    chat.handle_user_message(message)
end

-- Прокрутка вниз
function M.scroll_to_bottom()
    if chat_win and vim.api.nvim_win_is_valid(chat_win) then
        local line_count = vim.api.nvim_buf_line_count(chat_buf)
        vim.api.nvim_win_set_cursor(chat_win, {line_count, 0})
    end
end

-- Очищення чату
function M.clear()
    if chat_buf and vim.api.nvim_buf_is_valid(chat_buf) then
        vim.api.nvim_buf_set_option(chat_buf, "modifiable", true)
        vim.api.nvim_buf_set_lines(chat_buf, 0, -1, false, {})
        vim.api.nvim_buf_set_option(chat_buf, "modifiable", false)
        
        -- Додаємо повідомлення про очищення
        M.add_system_message("Чат очищено")
    end
end

-- Фокус на поле введення
function M.focus_input()
    if input_win and vim.api.nvim_win_is_valid(input_win) then
        vim.api.nvim_set_current_win(input_win)
        vim.cmd("startinsert")
    end
end

-- Закриття чат-вікна
function M.close()
    if chat_win and vim.api.nvim_win_is_valid(chat_win) then
        vim.api.nvim_win_close(chat_win, true)
    end
    
    if input_win and vim.api.nvim_win_is_valid(input_win) then
        vim.api.nvim_win_close(input_win, true)
    end
    
    chat_buf = nil
    chat_win = nil 
    input_buf = nil
    input_win = nil
    is_open = false
end

-- Перевірка чи вікно відкрите
function M.is_open()
    return is_open and 
           chat_win and vim.api.nvim_win_is_valid(chat_win) and
           input_win and vim.api.nvim_win_is_valid(input_win)
end

-- Отримання буферів та вікон
function M.get_buffers()
    return {
        chat_buffer = chat_buf,
        input_buffer = input_buf,
        chat_window = chat_win,
        input_window = input_win
    }
end

-- Отримання chat буфера
function M.get_chat_buffer()
    return chat_buf
end

-- Оновлення розмірів вікна
function M.resize()
    if not M.is_open() then
        return
    end
    
    -- Закриваємо та відкриваємо знову з новими розмірами
    M.close()
    M.create_window()
end

-- Оновлення індикатора режиму в заголовку
function M.update_mode_indicator()
    if not is_open or not vim.api.nvim_win_is_valid(chat_win) then
        return
    end
    
    local cfg = config.get()
    local mode_display = modes.format_mode_display()
    local title = cfg.ui.chat.title .. " [" .. mode_display .. "]"
    
    -- Оновлюємо заголовок вікна
    local win_config = vim.api.nvim_win_get_config(chat_win)
    win_config.title = title
    vim.api.nvim_win_set_config(chat_win, win_config)
end

return M