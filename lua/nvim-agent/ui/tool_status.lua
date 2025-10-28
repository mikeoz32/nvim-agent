-- Модуль для відображення статусу виконання MCP інструментів
local M = {}

-- Іконки для різних типів інструментів
M.icons = {
    -- Файлові операції
    read_file = "📖",
    write_file = "💾",
    open_file = "📂",
    find_files = "🔍",
    grep_search = "🔎",
    
    -- Проект
    get_project_context = "📦",
    get_project_structure = "🌳",
    
    -- LSP
    get_diagnostics = "🔍",
    goto_definition = "➡️",
    find_references = "🔗",
    get_signature_help = "📝",
    get_hover_info = "💡",
    get_document_symbols = "📋",
    rename_symbol = "✏️",
    get_code_actions = "🔧",
    format_code = "✨",
    
    -- Редагування
    insert_text = "➕",
    delete_lines = "➖",
    replace_text = "🔄",
    get_selection = "📌",
    
    -- Буфери
    list_buffers = "📚",
    create_buffer = "📄",
    save_buffer = "💾",
    close_buffer = "❌",
    
    -- Treesitter
    get_treesitter_nodes = "🌲",
    
    -- Команди
    execute_command = "⚡",
    execute_shell = "🖥️",
    execute_macro = "🎬",
    
    -- Статуси
    loading = "⏳",
    success = "✅",
    error = "❌",
    warning = "⚠️",
    info = "ℹ️",
}

-- Отримати іконку для інструменту
function M.get_tool_icon(tool_name)
    return M.icons[tool_name] or "🔧"
end

-- Форматування повідомлення про початок виконання
function M.format_tool_start(tool_name, params)
    local icon = M.get_tool_icon(tool_name)
    local formatted = icon .. " " .. M.format_tool_name(tool_name)
    
    -- Додаємо ключові параметри
    local details = M.get_tool_details(tool_name, params)
    if details then
        formatted = formatted .. ": " .. details
    end
    
    return formatted
end

-- Форматування назви інструменту (читабельно)
function M.format_tool_name(tool_name)
    local names = {
        read_file = "Читаю файл",
        write_file = "Записую файл",
        open_file = "Відкриваю файл",
        find_files = "Шукаю файли",
        grep_search = "Шукаю текст",
        get_project_context = "Завантажую контекст проекту",
        get_project_structure = "Аналізую структуру проекту",
        get_diagnostics = "Перевіряю помилки",
        goto_definition = "Шукаю визначення",
        find_references = "Шукаю посилання",
        get_signature_help = "Отримую сигнатуру",
        get_hover_info = "Отримую документацію",
        get_document_symbols = "Аналізую символи",
        rename_symbol = "Перейменовую символ",
        get_code_actions = "Шукаю дії",
        format_code = "Форматую код",
        insert_text = "Вставляю текст",
        delete_lines = "Видаляю рядки",
        replace_text = "Замінюю текст",
        get_selection = "Отримую виділення",
        list_buffers = "Переглядаю буфери",
        create_buffer = "Створюю буфер",
        save_buffer = "Зберігаю буфер",
        close_buffer = "Закриваю буфер",
        get_treesitter_nodes = "Аналізую AST",
        execute_command = "Виконую команду",
        execute_shell = "Виконую shell",
        execute_macro = "Виконую макрос",
    }
    
    return names[tool_name] or tool_name
end

-- Отримання деталей для відображення
function M.get_tool_details(tool_name, params)
    if not params then return nil end
    
    -- Файлові операції
    if tool_name == "read_file" then
        local path = params.path or ""
        local filename = vim.fn.fnamemodify(path, ":t")
        if params.start_line and params.end_line then
            return filename .. ", lines " .. params.start_line .. "-" .. params.end_line
        else
            return filename
        end
    
    elseif tool_name == "write_file" then
        local path = params.path or ""
        return vim.fn.fnamemodify(path, ":t")
    
    elseif tool_name == "open_file" then
        local path = params.path or ""
        local filename = vim.fn.fnamemodify(path, ":t")
        if params.line then
            return filename .. ":" .. params.line
        else
            return filename
        end
    
    elseif tool_name == "find_files" then
        return params.pattern or ""
    
    elseif tool_name == "grep_search" then
        local query = params.query or ""
        if #query > 30 then
            query = query:sub(1, 27) .. "..."
        end
        return '"' .. query .. '"'
    
    -- Проект
    elseif tool_name == "get_project_context" then
        local parts = {}
        if params.include_content == false then
            table.insert(parts, "без вмісту")
        end
        if params.max_files then
            table.insert(parts, "max " .. params.max_files .. " файлів")
        end
        return #parts > 0 and table.concat(parts, ", ") or nil
    
    elseif tool_name == "get_project_structure" then
        if params.max_depth then
            return "глибина " .. params.max_depth
        end
    
    -- LSP
    elseif tool_name == "rename_symbol" then
        if params.old_name and params.new_name then
            return params.old_name .. " → " .. params.new_name
        end
    
    elseif tool_name == "format_code" then
        if params.start_line and params.end_line then
            return "lines " .. params.start_line .. "-" .. params.end_line
        end
    
    -- Редагування
    elseif tool_name == "insert_text" then
        if params.line then
            return "line " .. params.line
        end
    
    elseif tool_name == "delete_lines" then
        if params.start_line and params.end_line then
            return "lines " .. params.start_line .. "-" .. params.end_line
        end
    
    elseif tool_name == "replace_text" then
        return params.pattern or ""
    
    -- Команди
    elseif tool_name == "execute_command" then
        local cmd = params.command or ""
        if #cmd > 40 then
            cmd = cmd:sub(1, 37) .. "..."
        end
        return cmd
    
    elseif tool_name == "execute_shell" then
        local cmd = params.command or ""
        if #cmd > 40 then
            cmd = cmd:sub(1, 37) .. "..."
        end
        return cmd
    
    elseif tool_name == "execute_macro" then
        return "register " .. (params.register or "")
    end
    
    return nil
end

-- Форматування результату виконання
function M.format_tool_result(tool_name, result, success)
    local icon = success and M.icons.success or M.icons.error
    local summary = M.get_result_summary(tool_name, result, success)
    
    return icon .. " " .. summary
end

-- Отримання короткого опису результату
function M.get_result_summary(tool_name, result, success)
    if not success then
        local error_msg = result.error or "Помилка виконання"
        if #error_msg > 60 then
            error_msg = error_msg:sub(1, 57) .. "..."
        end
        return M.format_tool_name(tool_name) .. ": " .. error_msg
    end
    
    -- Файлові операції
    if tool_name == "read_file" then
        if result.lines then
            local line_count = type(result.lines) == "table" and #result.lines or result.lines
            return "Прочитано " .. line_count .. " рядків"
        end
        return "Файл прочитано"
    
    elseif tool_name == "write_file" then
        return "Файл збережено"
    
    elseif tool_name == "open_file" then
        return "Файл відкрито"
    
    elseif tool_name == "find_files" then
        local count = result.count or (result.files and #result.files) or 0
        return "Знайдено " .. count .. " " .. M.plural(count, "файл", "файли", "файлів")
    
    elseif tool_name == "grep_search" then
        local count = result.total_matches or 0
        return "Знайдено " .. count .. " " .. M.plural(count, "збіг", "збіги", "збігів")
    
    -- Проект
    elseif tool_name == "get_project_context" then
        if result.statistics then
            local stats = result.statistics
            return "Завантажено " .. stats.total_files .. " файлів (" .. stats.size_mb .. "MB)"
        end
        return "Контекст завантажено"
    
    elseif tool_name == "get_project_structure" then
        if result.statistics then
            local stats = result.statistics
            return stats.files .. " файлів, " .. stats.directories .. " директорій"
        end
        return "Структура отримана"
    
    -- LSP
    elseif tool_name == "get_diagnostics" then
        local count = result.count or (result.diagnostics and #result.diagnostics) or 0
        return "Знайдено " .. count .. " " .. M.plural(count, "проблему", "проблеми", "проблем")
    
    elseif tool_name == "goto_definition" then
        local count = result.count or (result.definitions and #result.definitions) or 0
        return "Знайдено " .. count .. " " .. M.plural(count, "визначення", "визначення", "визначень")
    
    elseif tool_name == "find_references" then
        local count = result.count or (result.references and #result.references) or 0
        return "Знайдено " .. count .. " " .. M.plural(count, "посилання", "посилання", "посилань")
    
    elseif tool_name == "get_document_symbols" then
        local count = result.count or (result.symbols and #result.symbols) or 0
        return "Знайдено " .. count .. " " .. M.plural(count, "символ", "символи", "символів")
    
    elseif tool_name == "rename_symbol" then
        local count = result.changes or 0
        return "Перейменовано в " .. count .. " " .. M.plural(count, "місці", "місцях", "місцях")
    
    elseif tool_name == "get_code_actions" then
        local count = result.count or (result.actions and #result.actions) or 0
        return "Знайдено " .. count .. " " .. M.plural(count, "дію", "дії", "дій")
    
    elseif tool_name == "format_code" then
        return "Код відформатовано"
    
    -- Редагування
    elseif tool_name == "insert_text" then
        return "Текст вставлено"
    
    elseif tool_name == "delete_lines" then
        local count = result.deleted_lines or 0
        return "Видалено " .. count .. " " .. M.plural(count, "рядок", "рядки", "рядків")
    
    elseif tool_name == "replace_text" then
        local count = result.replacements or 0
        return "Зроблено " .. count .. " " .. M.plural(count, "заміну", "заміни", "замін")
    
    -- Буфери
    elseif tool_name == "list_buffers" then
        local count = result.count or (result.buffers and #result.buffers) or 0
        return count .. " " .. M.plural(count, "буфер", "буфери", "буферів")
    
    elseif tool_name == "create_buffer" then
        return "Буфер створено"
    
    elseif tool_name == "save_buffer" then
        return "Буфер збережено"
    
    elseif tool_name == "close_buffer" then
        return "Буфер закрито"
    
    -- Treesitter
    elseif tool_name == "get_treesitter_nodes" then
        local count = result.count or (result.nodes and #result.nodes) or 0
        return "Знайдено " .. count .. " " .. M.plural(count, "вузол", "вузли", "вузлів")
    
    -- Команди
    elseif tool_name == "execute_command" or tool_name == "execute_shell" then
        if result.output then
            local lines = vim.split(result.output, "\n")
            return "Виконано (" .. #lines .. " " .. M.plural(#lines, "рядок", "рядки", "рядків") .. ")"
        end
        return "Виконано успішно"
    
    elseif tool_name == "execute_macro" then
        return "Макрос виконано"
    end
    
    return M.format_tool_name(tool_name) .. " виконано"
end

-- Допоміжна функція для множини (українська)
function M.plural(count, one, few, many)
    local mod10 = count % 10
    local mod100 = count % 100
    
    if mod10 == 1 and mod100 ~= 11 then
        return one
    elseif mod10 >= 2 and mod10 <= 4 and (mod100 < 10 or mod100 >= 20) then
        return few
    else
        return many
    end
end

-- Створення progress bar для довгих операцій
function M.create_progress_message(current, total, operation)
    local icon = M.icons.loading
    local percent = math.floor((current / total) * 100)
    local bar_length = 20
    local filled = math.floor((current / total) * bar_length)
    local bar = string.rep("█", filled) .. string.rep("░", bar_length - filled)
    
    return string.format("%s %s [%s] %d/%d (%d%%)", 
        icon, operation, bar, current, total, percent)
end

return M
