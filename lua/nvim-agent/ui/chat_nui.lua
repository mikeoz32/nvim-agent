-- Модуль для відображення чату як нативних vim splits
-- Використовує звичайні буфери та вікна nvim + nui.split для input

local Split = require("nui.split")
local event = require("nui.utils.autocmd").event
local config = require("nvim-agent.config")
local modes = require("nvim-agent.modes")
local utils = require("nvim-agent.utils")

local M = {}

-- Локальні змінні
local renderer = nil  -- {chat_win}
local input_split = nil  -- nui Split для input (з'являється на вимогу)
local signal = nil
local chat_buffer = nil

-- Ініціалізація
function M.init()
    -- Створюємо буфер для історії чату
    chat_buffer = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(chat_buffer, 'filetype', 'markdown')
    vim.api.nvim_buf_set_option(chat_buffer, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(chat_buffer, 'bufhidden', 'hide')
    vim.api.nvim_buf_set_option(chat_buffer, 'swapfile', false)
    vim.api.nvim_buf_set_option(chat_buffer, 'modifiable', false)
    
    -- Створюємо простий state об'єкт
    -- Отримуємо режим і модель з поточної сесії
    local sessions = require('nvim-agent.chat_sessions')
    signal = {
        messages = {},
        mode = sessions.get_mode() or "ask",
        model = sessions.get_model() or config.get().api.model or "gpt-4"
    }
    
    return M
end

-- Створення вікна
function M.create_window()
    if renderer and vim.api.nvim_win_is_valid(renderer.chat_win) then
        vim.api.nvim_set_current_win(renderer.chat_win)
        return true
    end
    
    M.init()
    
    local cfg = config.get()
    local ui_cfg = cfg.ui.chat
    
    -- Визначаємо тип split та розмір
    local split_cmd
    local size
    
    if ui_cfg.position == "right" then
        size = math.floor(vim.o.columns * ui_cfg.width / 100)
        split_cmd = "botright vsplit"
    elseif ui_cfg.position == "left" then
        size = math.floor(vim.o.columns * ui_cfg.width / 100)
        split_cmd = "topleft vsplit"
    elseif ui_cfg.position == "bottom" then
        size = math.floor(vim.o.lines * ui_cfg.height / 100)
        split_cmd = "botright split"
    else
        -- default: right
        size = math.floor(vim.o.columns * 50 / 100)
        split_cmd = "botright vsplit"
    end
    
    -- Створюємо split та відкриваємо буфер
    vim.cmd(split_cmd)
    vim.cmd("resize " .. size)
    vim.api.nvim_win_set_buf(0, chat_buffer)
    
    -- Зберігаємо window id
    local win = vim.api.nvim_get_current_win()
    
    -- Налаштування вікна
    vim.api.nvim_win_set_option(win, 'number', false)
    vim.api.nvim_win_set_option(win, 'relativenumber', false)
    vim.api.nvim_win_set_option(win, 'signcolumn', 'no')
    vim.api.nvim_win_set_option(win, 'wrap', true)
    vim.api.nvim_win_set_option(win, 'linebreak', true)
    vim.api.nvim_win_set_option(win, 'cursorline', true)
    
    -- Налаштовуємо statusline з інформацією про режим і модель
    M._update_statusline(win)
    
    -- Зберігаємо інформацію про вікно
    renderer = {
        chat_win = win,
    }
    
    -- Налаштування keymaps для чат вікна
    local keymap_opts = { noremap = true, silent = true, nowait = true }
    
    vim.api.nvim_buf_set_keymap(chat_buffer, 'n', '<C-q>', 
        '<cmd>lua require("nvim-agent.ui.chat_nui").close()<CR>', 
        keymap_opts)
    vim.api.nvim_buf_set_keymap(chat_buffer, 'n', 'i', 
        '<cmd>lua require("nvim-agent.ui.chat_nui").show_input()<CR>', 
        keymap_opts)
    vim.api.nvim_buf_set_keymap(chat_buffer, 'n', 'a', 
        '<cmd>lua require("nvim-agent.ui.chat_nui").show_input()<CR>', 
        keymap_opts)
    vim.api.nvim_buf_set_keymap(chat_buffer, 'n', 'o', 
        '<cmd>lua require("nvim-agent.ui.chat_nui").show_input()<CR>', 
        keymap_opts)
    
    -- Autocmd для cleanup при закритті вікна
    vim.api.nvim_create_autocmd("WinClosed", {
        callback = function(ev)
            if renderer and tonumber(ev.match) == renderer.chat_win then
                M.close()
            end
        end,
    })
    
    M.setup_markdown_rendering()
    M._update_chat_buffer()
    
    -- Переміщуємо курсор в кінець після відкриття
    vim.schedule(function()
        if renderer and renderer.chat_win and vim.api.nvim_win_is_valid(renderer.chat_win) then
            local line_count = vim.api.nvim_buf_line_count(chat_buffer)
            vim.api.nvim_win_set_cursor(renderer.chat_win, {line_count, 0})
        end
    end)
    
    return true
end

-- Показати input split для введення повідомлення
function M.show_input()
    if not renderer or not vim.api.nvim_win_is_valid(renderer.chat_win) then
        return
    end
    
    -- Якщо input вже відкритий, просто фокусуємося на ньому
    if input_split and input_split.winid and vim.api.nvim_win_is_valid(input_split.winid) then
        vim.api.nvim_set_current_win(input_split.winid)
        return
    end
    
    -- Створюємо nui Split для input з корисною інформацією в заголовку
    local mode_name = signal.mode == "ask" and "Ask" or signal.mode == "edit" and "Edit" or "Agent"
    local title = string.format(" 💬 %s | %s | Ctrl+S для відправки ", mode_name, signal.model)
    
    input_split = Split({
        relative = "win",
        position = "bottom",
        size = 3,  -- Початковий розмір 3 рядки
        buf_options = {
            modifiable = true,
            readonly = false,
            filetype = "markdown",
        },
        win_options = {
            winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
            wrap = true,
            linebreak = true,
        },
        border = {
            style = "rounded",
            text = {
                top = title,
                top_align = "center",
            },
        },
    })
    
    -- Монтуємо split
    input_split:mount()
    
    -- Буфер залишаємо порожнім для введення
    vim.api.nvim_buf_set_lines(input_split.bufnr, 0, -1, false, {""})
    
    -- Встановлюємо початковий statusline для input
    M._update_input_statusline(input_split.winid)
    
    -- Autocmd для оновлення statusline при зміні тексту
    vim.api.nvim_create_autocmd({"TextChanged", "TextChangedI"}, {
        buffer = input_split.bufnr,
        callback = function()
            if input_split and input_split.winid and vim.api.nvim_win_is_valid(input_split.winid) then
                M._update_input_statusline(input_split.winid)
            end
        end,
    })
    
    -- Налаштування keymaps для input split
    input_split:map("i", "<C-s>", function()
        M._send_and_close_input()
    end, { noremap = true })
    
    input_split:map("n", "<C-s>", function()
        M._send_and_close_input()
    end, { noremap = true })
    
    -- Esc просто виходить з insert mode, не закриваючи input
    -- (стандартна поведінка vim)
    
    -- Auto-close при втраті фокуса (опціонально)
    input_split:on(event.BufLeave, function()
        -- Можна додати auto-close, але краще залишити відкритим
    end)
    
    -- Переходимо в insert mode
    vim.schedule(function()
        if input_split and input_split.winid and vim.api.nvim_win_is_valid(input_split.winid) then
            vim.api.nvim_set_current_win(input_split.winid)
            vim.cmd("startinsert")
        end
    end)
end

-- Закрити input split
function M._close_input()
    if input_split then
        input_split:unmount()
        input_split = nil
    end
    
    -- Повертаємо фокус на чат
    if renderer and renderer.chat_win and vim.api.nvim_win_is_valid(renderer.chat_win) then
        vim.api.nvim_set_current_win(renderer.chat_win)
    end
end

-- Відправити повідомлення і закрити input
function M._send_and_close_input()
    if not input_split or not input_split.bufnr then
        return
    end
    
    local lines = vim.api.nvim_buf_get_lines(input_split.bufnr, 0, -1, false)
    local message = table.concat(lines, "\n")
    
    -- Закриваємо input
    M._close_input()
    
    -- Відправляємо повідомлення
    M._send_message(message)
end

-- Внутрішня функція для відправки повідомлення
function M._send_message(message)
    message = message:gsub("^%s+", ""):gsub("%s+$", "")
    
    if message == "" or message:match("^%s*$") then
        vim.notify("Введіть повідомлення перед надсиланням", vim.log.levels.WARN)
        return
    end
    
    -- Викликаємо обробку повідомлення
    local chat = require('nvim-agent.chat')
    chat.handle_user_message(message)
    
    return true
end

-- Налаштування markdown rendering
function M.setup_markdown_rendering()
    if not chat_buffer or not vim.api.nvim_buf_is_valid(chat_buffer) then
        return
    end
    
    -- Встановлюємо treesitter підсвітку для markdown
    vim.api.nvim_buf_call(chat_buffer, function()
        vim.cmd('setlocal wrap')
        vim.cmd('setlocal linebreak')
        vim.cmd('setlocal breakindent')
    end)
    
    -- Налаштування concealing для markdown
    vim.api.nvim_buf_set_option(chat_buffer, 'conceallevel', 2)
    vim.api.nvim_buf_set_option(chat_buffer, 'concealcursor', 'nc')
    
    -- Спроба використати render-markdown.nvim якщо доступний
    local has_render_markdown = pcall(require, 'render-markdown')
    if has_render_markdown then
        vim.api.nvim_buf_call(chat_buffer, function()
            vim.cmd('RenderMarkdown enable')
        end)
    end
    
    -- Додаємо підсвітку для code blocks через treesitter
    vim.schedule(function()
        if vim.treesitter and vim.treesitter.start then
            pcall(vim.treesitter.start, chat_buffer, 'markdown')
        end
    end)
end

-- Додавання повідомлення користувача
function M.add_user_message(content)
    table.insert(signal.messages, {
        role = "user",
        content = content,
        timestamp = os.date("%H:%M:%S")
    })
    M._update_chat_buffer()
    M._update_statusline()
end

-- Додавання повідомлення AI
function M.add_ai_message(content)
    table.insert(signal.messages, {
        role = "assistant",
        content = content,
        timestamp = os.date("%H:%M:%S")
    })
    M._update_chat_buffer()
    M._update_statusline()
end

-- Додавання системного повідомлення
function M.add_system_message(content)
    table.insert(signal.messages, {
        role = "system",
        content = content,
        timestamp = os.date("%H:%M:%S")
    })
    M._update_chat_buffer()
    M._update_statusline()
end

-- Замінити останнє системне повідомлення (як у VS Code)
function M.replace_last_system_message(content)
    -- Шукаємо останнє системне повідомлення з кінця
    for i = #signal.messages, 1, -1 do
        if signal.messages[i].role == "system" then
            signal.messages[i].content = content
            signal.messages[i].timestamp = os.date("%H:%M:%S")
            M._update_chat_buffer()
            M._update_statusline()
            return true
        end
    end
    
    -- Якщо не знайдено системних повідомлень, додаємо нове
    M.add_system_message(content)
    return false
end

-- Оновлення буфера чату
function M._update_chat_buffer()
    if not chat_buffer or not vim.api.nvim_buf_is_valid(chat_buffer) then
        return
    end
    
    local messages = signal.messages
    local lines = {}
    
    -- Якщо немає повідомлень, показуємо привітання
    if #messages == 0 then
        table.insert(lines, "")
        table.insert(lines, "# 👋 Вітаємо в nvim-agent!")
        table.insert(lines, "")
        table.insert(lines, "Введіть повідомлення, натисніть `i` для відкриття input.")
        table.insert(lines, "Натисніть **Ctrl+S** для відправки, **Ctrl+Q** або **:q** для закриття.")
        table.insert(lines, "")
        table.insert(lines, "**Доступні команди:**")
        table.insert(lines, "- `/ask` - Задати питання")
        table.insert(lines, "- `/edit` - Редагувати код")
        table.insert(lines, "- `/agent` - Режим агента")
        table.insert(lines, "")
    end
    
    for i, msg in ipairs(messages) do
        -- Форматування залежно від ролі
        if msg.role == "user" then
            table.insert(lines, "### 💬 Ви `" .. msg.timestamp .. "`")
            table.insert(lines, "")
        elseif msg.role == "assistant" then
            table.insert(lines, "### 🤖 Асистент `" .. msg.timestamp .. "`")
            table.insert(lines, "")
        elseif msg.role == "system" then
            -- Системні повідомлення компактно (без пустих рядків)
            for line in msg.content:gmatch("[^\r\n]+") do
                table.insert(lines, "> " .. line)
            end
            goto continue
        end
        
        -- Додаємо вміст повідомлення
        for line in msg.content:gmatch("[^\r\n]+") do
            table.insert(lines, line)
        end
        
        ::continue::
    end
    
    -- Додаємо один порожній рядок в кінці для кращого скролінгу
    table.insert(lines, "")
    
    -- Оновлюємо буфер
    vim.api.nvim_buf_set_option(chat_buffer, 'modifiable', true)
    vim.api.nvim_buf_set_lines(chat_buffer, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(chat_buffer, 'modifiable', false)
    
    -- Переміщуємо курсор в кінець буфера
    if renderer and renderer.chat_win and vim.api.nvim_win_is_valid(renderer.chat_win) then
        local line_count = vim.api.nvim_buf_line_count(chat_buffer)
        vim.api.nvim_win_set_cursor(renderer.chat_win, {line_count, 0})
        -- Прокручуємо вікно, щоб останній рядок був видно
        vim.api.nvim_win_call(renderer.chat_win, function()
            vim.cmd("normal! zb")
        end)
    end
end

-- Відправка поточного повідомлення (для сумісності, тепер використовуємо show_input)
function M.send_current_message()
    M.show_input()
end

-- Отримання поточного input (для сумісності)
function M.get_current_input()
    return ""
end

-- Очистка input (для сумісності)
function M.clear_input()
    if input_split and input_split.bufnr and vim.api.nvim_buf_is_valid(input_split.bufnr) then
        vim.api.nvim_buf_set_lines(input_split.bufnr, 0, -1, false, {""})
    end
end

-- Очистка чату
function M.clear()
    if not signal then
        return
    end
    signal.messages = {}
    M._update_chat_buffer()
end

-- Оновлення statusline вікна
function M._update_statusline(win)
    win = win or (renderer and renderer.chat_win)
    if not win or not vim.api.nvim_win_is_valid(win) then
        return
    end
    
    local mode_name = signal.mode == "ask" and "💬 Ask" or signal.mode == "edit" and "✏️  Edit" or "🤖 Agent"
    local model_name = signal.model or "gpt-4"
    local statusline = string.format(" %s | 🧠 %s ", mode_name, model_name)
    
    vim.api.nvim_win_set_option(win, 'statusline', statusline)
end

-- Оновлення statusline для input вікна зі статистикою
function M._update_input_statusline(win)
    if not win or not vim.api.nvim_win_is_valid(win) then
        return
    end
    
    if not input_split or not input_split.bufnr or not vim.api.nvim_buf_is_valid(input_split.bufnr) then
        return
    end
    
    -- Отримуємо вміст буфера
    local lines = vim.api.nvim_buf_get_lines(input_split.bufnr, 0, -1, false)
    local line_count = #lines
    
    -- Рахуємо символи (без порожніх рядків в кінці)
    local text = table.concat(lines, "\n")
    local char_count = #text
    
    -- Рахуємо слова
    local word_count = 0
    for _ in text:gmatch("%S+") do
        word_count = word_count + 1
    end
    
    -- Формуємо statusline
    local statusline = string.format(
        " 📝 Insert | Рядків: %d | Слів: %d | Символів: %d | Ctrl+S відправити ",
        line_count,
        word_count,
        char_count
    )
    
    vim.api.nvim_win_set_option(win, 'statusline', statusline)
end

-- Оновлення індикатора режиму
function M.update_mode_indicator()
    signal.mode = modes.get_current_mode()
    
    -- Отримуємо модель з поточної сесії
    local sessions = require('nvim-agent.chat_sessions')
    signal.model = sessions.get_model() or config.get().api.model or "gpt-4"
    
    -- Оновлюємо statusline
    M._update_statusline()
end

-- Закриття вікна
function M.close()
    if not renderer then
        return
    end
    
    -- Закриваємо input split якщо відкритий
    if input_split then
        input_split:unmount()
        input_split = nil
    end
    
    -- Зберігаємо локальну копію
    local chat_win = renderer.chat_win
    
    -- Очищуємо renderer одразу
    renderer = nil
    
    -- Закриваємо вікно
    if chat_win and vim.api.nvim_win_is_valid(chat_win) then
        pcall(vim.api.nvim_win_close, chat_win, true)
    end
end

-- Перевірка чи відкрите вікно
function M.is_open()
    if not renderer then
        return false
    end
    
    return renderer.chat_win and vim.api.nvim_win_is_valid(renderer.chat_win)
end

-- Отримання буфера чату
function M.get_chat_buffer()
    return chat_buffer
end

-- Фокус на input (тепер показує popup)
function M.focus_input()
    M.show_input()
end

-- Прокрутка до низу
function M.scroll_to_bottom()
    if renderer and renderer.chat_win and vim.api.nvim_win_is_valid(renderer.chat_win) then
        vim.api.nvim_win_call(renderer.chat_win, function()
            vim.cmd('normal! G')
        end)
    end
end

-- Отримання буферів (для сумісності)
function M.get_buffers()
    return {
        chat = chat_buffer,
        input = nil  -- input тепер popup
    }
end

-- Resize (nui-components керує розміром автоматично)
function M.resize()
    -- Не потрібно - nui-components керує цим
end

return M
