-- Утиліти для nvim-agent
local M = {}

-- Функція логування
function M.log(level, message, data)
    -- Safe config loading with fallback
    local ok, config = pcall(require, 'nvim-agent.config')
    if not ok then
        -- Fallback: просто виводимо в stderr якщо конфіг недоступний
        if level == "error" or level == "warn" then
            io.stderr:write(string.format("[%s] %s\n", level:upper(), message))
            if data then
                io.stderr:write(vim.inspect(data) .. "\n")
            end
        end
        return
    end
    
    local cfg = config.get()
    
    if not cfg.debug or not cfg.debug.enabled then
        return
    end
    
    local levels = {
        error = 1,
        warn = 2, 
        info = 3,
        debug = 4,
        trace = 5
    }
    
    local current_level = levels[cfg.debug.log_level] or 3
    local log_level = levels[level] or 3
    
    if log_level > current_level then
        return
    end
    
    -- Форматуємо повідомлення
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local log_entry = string.format("[%s] [%s] %s", timestamp, level:upper(), message)
    
    if data then
        log_entry = log_entry .. " | " .. vim.inspect(data)
    end
    
    -- Записуємо в файл
    local file = io.open(cfg.debug.log_file, "a")
    if file then
        file:write(log_entry .. "\n")
        file:close()
    end
    
    -- Виводимо в повідомлення якщо це помилка або попередження
    if level == "error" or level == "warn" then
        local vim_level = level == "error" and vim.log.levels.ERROR or vim.log.levels.WARN
        vim.notify("nvim-agent: " .. message, vim_level)
    end
end

-- Отримання вибраного тексту
function M.get_visual_selection()
    local start_pos = vim.fn.getpos("'<")
    local end_pos = vim.fn.getpos("'>")
    
    if start_pos[2] == 0 or end_pos[2] == 0 then
        return nil
    end
    
    local start_line, start_col = start_pos[2], start_pos[3]
    local end_line, end_col = end_pos[2], end_pos[3]
    
    local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
    
    if #lines == 0 then
        return nil
    end
    
    -- Обрізаємо текст відповідно до колонок
    if #lines == 1 then
        lines[1] = string.sub(lines[1], start_col, end_col)
    else
        lines[1] = string.sub(lines[1], start_col)
        lines[#lines] = string.sub(lines[#lines], 1, end_col)
    end
    
    return table.concat(lines, "\n")
end

-- Отримання контексту поточного файлу
function M.get_file_context()
    local ok, config = pcall(require, 'nvim-agent.config')
    if not ok then
        return nil
    end
    
    local cfg = config.get()
    
    if not cfg.behavior.include_file_context then
        return nil
    end
    
    local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
    local total_lines = vim.api.nvim_buf_line_count(0)
    local context_lines = cfg.behavior.context_lines
    
    local start_line = math.max(1, cursor_line - context_lines)
    local end_line = math.min(total_lines, cursor_line + context_lines)
    
    local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
    local content = table.concat(lines, "\n")
    
    local filename = vim.api.nvim_buf_get_name(0)
    local short_name = vim.fn.fnamemodify(filename, ":t")  -- Тільки ім'я файлу
    
    return {
        content = content,
        start_line = start_line,
        end_line = end_line,
        cursor_line = cursor_line,
        filename = short_name,
        full_path = filename,
        filetype = vim.bo.filetype,
        line_count = #lines,
        lines = {start_line, end_line},
        total_lines = total_lines
    }
end

-- Отримання контексту активного файлу (весь файл, як в VS Code)
function M.get_active_file_context()
    local ok, config = pcall(require, 'nvim-agent.config')
    if not ok then
        return nil
    end
    
    local cfg = config.get()
    
    if not cfg.behavior.include_file_context then
        return nil
    end
    
    local buf = vim.api.nvim_get_current_buf()
    local filename = vim.api.nvim_buf_get_name(buf)
    
    -- Пропускаємо якщо це не файл
    if filename == "" or vim.bo.buftype ~= "" then
        return nil
    end
    
    -- Пропускаємо спеціальні буфери
    local ft = vim.bo.filetype
    local skip_filetypes = {"help", "qf", "netrw", "fugitive", "gitcommit"}
    for _, skip_ft in ipairs(skip_filetypes) do
        if ft == skip_ft then
            return nil
        end
    end
    
    local total_lines = vim.api.nvim_buf_line_count(buf)
    local short_name = vim.fn.fnamemodify(filename, ":t")
    
    -- Якщо файл маленький (<300 рядків) - додаємо весь
    if total_lines <= 300 then
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        local content = table.concat(lines, "\n")
        
        return {
            content = content,
            filename = short_name,
            full_path = filename,
            filetype = ft,
            line_count = total_lines,
            lines = {1, total_lines},
            total_lines = total_lines
        }
    end
    
    -- Для великих файлів - додаємо контекст навколо курсору (розширений)
    local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
    local context_size = 150  -- Більше ніж дефолтні context_lines
    
    local start_line = math.max(1, cursor_line - context_size)
    local end_line = math.min(total_lines, cursor_line + context_size)
    
    local lines = vim.api.nvim_buf_get_lines(buf, start_line - 1, end_line, false)
    local content = table.concat(lines, "\n")
    
    -- Додаємо примітку що це частина файлу
    local note_before = string.format("// ... (пропущено рядки 1-%d) ...\n", start_line - 1)
    local note_after = string.format("\n// ... (пропущено рядки %d-%d) ...", end_line + 1, total_lines)
    
    if start_line > 1 then
        content = note_before .. content
    end
    if end_line < total_lines then
        content = content .. note_after
    end
    
    return {
        content = content,
        filename = short_name,
        full_path = filename,
        filetype = ft,
        line_count = #lines,
        lines = {start_line, end_line},
        total_lines = total_lines,
        partial = start_line > 1 or end_line < total_lines
    }
end

-- Отримання інформації про поточний буфер
function M.get_buffer_info()
    local buf = vim.api.nvim_get_current_buf()
    local filename = vim.api.nvim_buf_get_name(buf)
    
    return {
        buffer = buf,
        filename = filename,
        filetype = vim.api.nvim_buf_get_option(buf, "filetype"),
        line_count = vim.api.nvim_buf_line_count(buf),
        modified = vim.api.nvim_buf_get_option(buf, "modified"),
        readonly = vim.api.nvim_buf_get_option(buf, "readonly")
    }
end

-- Вставка тексту в поточну позицію
function M.insert_text(text, replace_selection)
    if replace_selection then
        -- Замінюємо вибрану область
        local start_pos = vim.fn.getpos("'<")
        local end_pos = vim.fn.getpos("'>")
        
        if start_pos[2] > 0 and end_pos[2] > 0 then
            local start_line, start_col = start_pos[2] - 1, start_pos[3] - 1
            local end_line, end_col = end_pos[2] - 1, end_pos[3]
            
            local lines = vim.split(text, "\n")
            vim.api.nvim_buf_set_text(0, start_line, start_col, end_line, end_col, lines)
            return
        end
    end
    
    -- Вставляємо в поточну позицію
    local cursor = vim.api.nvim_win_get_cursor(0)
    local line, col = cursor[1] - 1, cursor[2]
    
    local lines = vim.split(text, "\n")
    vim.api.nvim_buf_set_text(0, line, col, line, col, lines)
end

-- Створення плаваючого вікна
function M.create_floating_window(content, opts)
    opts = opts or {}
    
    -- Розміри екрана
    local screen_width = vim.o.columns
    local screen_height = vim.o.lines
    
    -- Розміри вікна
    local width = opts.width or math.floor(screen_width * 0.8)
    local height = opts.height or math.floor(screen_height * 0.8)
    
    -- Позиція вікна
    local col = math.floor((screen_width - width) / 2)
    local row = math.floor((screen_height - height) / 2)
    
    -- Створюємо буфер
    local buf = vim.api.nvim_create_buf(false, true)
    
    -- Налаштовуємо вміст
    if type(content) == "string" then
        local lines = vim.split(content, "\n")
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    elseif type(content) == "table" then
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)
    end
    
    -- Налаштування вікна
    local win_config = {
        relative = opts.relative or "editor",
        width = width,
        height = height,
        col = col,
        row = row,
        style = "minimal",
        border = opts.border or "rounded",
        title = opts.title,
        title_pos = opts.title_pos or "center"
    }
    
    -- Створюємо вікно
    local win = vim.api.nvim_open_win(buf, true, win_config)
    
    -- Налаштовуємо опції буфера
    vim.api.nvim_buf_set_option(buf, "modifiable", opts.modifiable ~= false)
    vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
    vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
    
    if opts.filetype then
        vim.api.nvim_buf_set_option(buf, "filetype", opts.filetype)
    end
    
    -- Додаємо хоткей для закриття
    if opts.close_on_escape ~= false then
        vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", "<cmd>close<CR>", {
            noremap = true, 
            silent = true
        })
    end
    
    return {
        buffer = buf,
        window = win,
        close = function()
            if vim.api.nvim_win_is_valid(win) then
                vim.api.nvim_win_close(win, true)
            end
        end
    }
end

-- Форматування коду блоку
function M.format_code_block(code, language)
    -- Визначаємо мову якщо не передано
    if not language then
        local filetype = vim.bo.filetype
        if filetype and filetype ~= "" then
            language = filetype
        else
            language = "text"
        end
    end
    
    return "```" .. language .. "\n" .. code .. "\n```"
end

-- Парсинг коду з відповіді AI
function M.extract_code_blocks(text)
    local blocks = {}
    local pattern = "```([%w]*)\n(.-)\n```"
    
    for lang, code in text:gmatch(pattern) do
        table.insert(blocks, {
            language = lang == "" and "text" or lang,
            code = code
        })
    end
    
    return blocks
end

-- Перевірка чи є текст кодом
function M.looks_like_code(text)
    -- Прості евристики для визначення коду
    local code_indicators = {
        "function", "class", "def ", "var ", "let ", "const ",
        "import ", "from ", "#include", "package ", "public ",
        "private ", "protected ", "static ", "void ", "int ",
        "string ", "bool ", "return ", "if ", "else ", "for ",
        "while ", "switch ", "case ", "{", "}", "(", ")",
        "[", "]", ";", "=>", "->", "::", ".", "="
    }
    
    local code_count = 0
    local total_chars = string.len(text)
    
    for _, indicator in ipairs(code_indicators) do
        if string.find(text, indicator, 1, true) then
            code_count = code_count + string.len(indicator)
        end
    end
    
    -- Якщо більше 10% тексту схоже на код
    return (code_count / total_chars) > 0.1
end

-- Збереження та завантаження даних
function M.save_data(filename, data)
    local filepath = vim.fn.stdpath("data") .. "/" .. filename
    local file = io.open(filepath, "w")
    
    if file then
        file:write(vim.json.encode(data))
        file:close()
        return true
    end
    
    return false
end

function M.load_data(filename, default)
    local filepath = vim.fn.stdpath("data") .. "/" .. filename
    local file = io.open(filepath, "r")
    
    if file then
        local content = file:read("*all")
        file:close()
        
        local success, data = pcall(vim.json.decode, content)
        if success then
            return data
        end
    end
    
    return default or {}
end

-- Перевірка доступності команд
function M.has_command(cmd)
    return vim.fn.executable(cmd) == 1
end

-- Escape спеціальних символів для regex
function M.escape_pattern(str)
    return str:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
end

-- Обрізання тексту до максимальної довжини
function M.truncate_text(text, max_length, suffix)
    suffix = suffix or "..."
    
    if string.len(text) <= max_length then
        return text
    end
    
    return string.sub(text, 1, max_length - string.len(suffix)) .. suffix
end

-- Отримання відносного шляху файлу
function M.get_relative_path(filepath)
    local cwd = vim.fn.getcwd()
    if filepath:sub(1, #cwd) == cwd then
        return filepath:sub(#cwd + 2)  -- +2 для пропуску слешу
    end
    return filepath
end

return M