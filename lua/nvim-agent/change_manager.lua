-- Менеджер змін для перегляду та прийняття/відхилення змін від агента
local M = {}

local config = require('nvim-agent.config')
local utils = require('nvim-agent.utils')

-- Стек змін для undo/redo
M.change_stack = {}
M.current_index = 0

-- Типи змін
M.CHANGE_TYPE = {
    FILE_CREATE = "file_create",
    FILE_MODIFY = "file_modify",
    FILE_DELETE = "file_delete",
    TEXT_INSERT = "text_insert",
    TEXT_DELETE = "text_delete",
    TEXT_REPLACE = "text_replace",
}

-- Буфер для preview змін
local preview_buf = nil
local preview_win = nil
local original_content = {}

-- Додавання зміни до стеку
function M.add_change(change)
    -- Видаляємо всі зміни після поточної позиції
    for i = M.current_index + 1, #M.change_stack do
        M.change_stack[i] = nil
    end
    
    table.insert(M.change_stack, change)
    M.current_index = #M.change_stack
    
    utils.log("debug", "Додано зміну до стеку", {
        type = change.type,
        index = M.current_index
    })
end

-- Створення зміни
function M.create_change(change_type, params)
    local change = {
        id = vim.fn.localtime() .. "_" .. math.random(1000, 9999), -- унікальний ID
        type = change_type,
        timestamp = os.time(),
        params = params,
        applied = false,
        backup = nil
    }
    
    -- Зберігаємо оригінальний стан
    if change_type == M.CHANGE_TYPE.FILE_MODIFY then
        local bufnr = params.buffer or 0
        if bufnr == 0 then
            bufnr = vim.api.nvim_get_current_buf()
        end
        
        change.backup = {
            buffer = bufnr,
            lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        }
    elseif change_type == M.CHANGE_TYPE.FILE_CREATE then
        change.backup = {
            existed = vim.fn.filereadable(params.path) == 1
        }
    elseif change_type == M.CHANGE_TYPE.FILE_DELETE then
        change.backup = {
            path = params.path,
            content = vim.fn.readfile(params.path)
        }
    end
    
    return change
end

-- Застосування зміни
function M.apply_change(change)
    if change.applied then
        return true
    end
    
    local success = false
    
    if change.type == M.CHANGE_TYPE.FILE_CREATE then
        local lines = vim.split(change.params.content or "", "\n")
        success = pcall(vim.fn.writefile, lines, change.params.path)
        
    elseif change.type == M.CHANGE_TYPE.FILE_MODIFY then
        local bufnr = change.params.buffer or 0
        if bufnr == 0 then
            bufnr = vim.api.nvim_get_current_buf()
        end
        
        if change.params.lines then
            success = pcall(vim.api.nvim_buf_set_lines, 
                bufnr, 0, -1, false, change.params.lines)
        end
        
    elseif change.type == M.CHANGE_TYPE.FILE_DELETE then
        success = pcall(vim.fn.delete, change.params.path)
        
    elseif change.type == M.CHANGE_TYPE.TEXT_INSERT then
        local bufnr = change.params.buffer or 0
        if bufnr == 0 then
            bufnr = vim.api.nvim_get_current_buf()
        end
        
        local line = change.params.line or vim.api.nvim_win_get_cursor(0)[1]
        local lines = vim.split(change.params.text, "\n")
        success = pcall(vim.api.nvim_buf_set_lines, 
            bufnr, line, line, false, lines)
            
    elseif change.type == M.CHANGE_TYPE.TEXT_REPLACE then
        local bufnr = change.params.buffer or 0
        if bufnr == 0 then
            bufnr = vim.api.nvim_get_current_buf()
        end
        
        local start_line = change.params.start_line - 1
        local end_line = change.params.end_line
        local lines = vim.split(change.params.new_text, "\n")
        success = pcall(vim.api.nvim_buf_set_lines, 
            bufnr, start_line, end_line, false, lines)
    end
    
    if success then
        change.applied = true
        utils.log("info", "Зміну застосовано", {type = change.type})
    end
    
    return success
end

-- Відміна зміни
function M.revert_change(change)
    if not change.applied then
        return true
    end
    
    local success = false
    
    if change.type == M.CHANGE_TYPE.FILE_CREATE then
        if not change.backup.existed then
            success = pcall(vim.fn.delete, change.params.path)
        end
        
    elseif change.type == M.CHANGE_TYPE.FILE_MODIFY then
        if change.backup and change.backup.lines then
            success = pcall(vim.api.nvim_buf_set_lines,
                change.backup.buffer, 0, -1, false, change.backup.lines)
        end
        
    elseif change.type == M.CHANGE_TYPE.FILE_DELETE then
        if change.backup and change.backup.content then
            success = pcall(vim.fn.writefile, 
                change.backup.content, change.backup.path)
        end
    end
    
    if success then
        change.applied = false
        utils.log("info", "Зміну відмінено", {type = change.type})
    end
    
    return success
end

-- Показ diff preview
function M.show_preview(change)
    -- Створюємо preview вікно якщо не існує
    if not preview_win or not vim.api.nvim_win_is_valid(preview_win) then
        M.create_preview_window()
    end
    
    local preview_lines = {}
    local ft = "diff"
    
    if change.type == M.CHANGE_TYPE.FILE_CREATE then
        table.insert(preview_lines, "=== Новий файл: " .. change.params.path .. " ===")
        table.insert(preview_lines, "")
        
        local content_lines = vim.split(change.params.content or "", "\n")
        for _, line in ipairs(content_lines) do
            table.insert(preview_lines, "+ " .. line)
        end
        
    elseif change.type == M.CHANGE_TYPE.FILE_MODIFY then
        local bufnr = change.backup.buffer
        local buf_name = vim.api.nvim_buf_get_name(bufnr)
        
        table.insert(preview_lines, "=== Зміни у файлі: " .. buf_name .. " ===")
        table.insert(preview_lines, "")
        
        -- Показуємо diff
        local old_lines = change.backup.lines
        local new_lines = change.params.lines
        
        -- Простий diff (можна покращити)
        local max_lines = math.max(#old_lines, #new_lines)
        for i = 1, max_lines do
            local old_line = old_lines[i] or ""
            local new_line = new_lines[i] or ""
            
            if old_line ~= new_line then
                if old_lines[i] then
                    table.insert(preview_lines, "- " .. old_line)
                end
                if new_lines[i] then
                    table.insert(preview_lines, "+ " .. new_line)
                end
            else
                table.insert(preview_lines, "  " .. old_line)
            end
        end
        
    elseif change.type == M.CHANGE_TYPE.FILE_DELETE then
        table.insert(preview_lines, "=== Видалення файлу: " .. change.params.path .. " ===")
        table.insert(preview_lines, "")
        table.insert(preview_lines, "⚠️  Файл буде видалено")
        
    elseif change.type == M.CHANGE_TYPE.TEXT_INSERT then
        table.insert(preview_lines, "=== Вставка тексту на лінії " .. change.params.line .. " ===")
        table.insert(preview_lines, "")
        
        local lines = vim.split(change.params.text, "\n")
        for _, line in ipairs(lines) do
            table.insert(preview_lines, "+ " .. line)
        end
        
    elseif change.type == M.CHANGE_TYPE.TEXT_REPLACE then
        table.insert(preview_lines, "=== Заміна тексту (лінії " .. 
            change.params.start_line .. "-" .. change.params.end_line .. ") ===")
        table.insert(preview_lines, "")
        
        -- Показуємо old -> new
        table.insert(preview_lines, "Старий текст:")
        table.insert(preview_lines, "- " .. change.params.old_text)
        table.insert(preview_lines, "")
        table.insert(preview_lines, "Новий текст:")
        table.insert(preview_lines, "+ " .. change.params.new_text)
    end
    
    -- Встановлюємо вміст preview буфера
    vim.api.nvim_buf_set_option(preview_buf, "modifiable", true)
    vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, preview_lines)
    vim.api.nvim_buf_set_option(preview_buf, "modifiable", false)
    vim.api.nvim_buf_set_option(preview_buf, "filetype", ft)
    
    -- Підсвічування для diff
    M.apply_diff_highlights()
end

-- Підсвічування diff
function M.apply_diff_highlights()
    local ns_id = vim.api.nvim_create_namespace("nvim-agent-diff")
    vim.api.nvim_buf_clear_namespace(preview_buf, ns_id, 0, -1)
    
    local lines = vim.api.nvim_buf_get_lines(preview_buf, 0, -1, false)
    
    for i, line in ipairs(lines) do
        if line:match("^%+ ") then
            vim.api.nvim_buf_add_highlight(preview_buf, ns_id, "DiffAdd", i - 1, 0, -1)
        elseif line:match("^%- ") then
            vim.api.nvim_buf_add_highlight(preview_buf, ns_id, "DiffDelete", i - 1, 0, -1)
        elseif line:match("^===") then
            vim.api.nvim_buf_add_highlight(preview_buf, ns_id, "Title", i - 1, 0, -1)
        elseif line:match("^⚠️") then
            vim.api.nvim_buf_add_highlight(preview_buf, ns_id, "WarningMsg", i - 1, 0, -1)
        end
    end
end

-- Створення preview вікна
function M.create_preview_window()
    -- Створюємо буфер
    preview_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(preview_buf, "bufhidden", "wipe")
    vim.api.nvim_buf_set_option(preview_buf, "buftype", "nofile")
    
    -- Розміри вікна
    local width = math.floor(vim.o.columns * 0.6)
    local height = math.floor(vim.o.lines * 0.6)
    local col = math.floor((vim.o.columns - width) / 2)
    local row = math.floor((vim.o.lines - height) / 2)
    
    -- Створюємо вікно
    preview_win = vim.api.nvim_open_win(preview_buf, true, {
        relative = "editor",
        width = width,
        height = height,
        col = col,
        row = row,
        style = "minimal",
        border = "rounded",
        title = " Перегляд змін ",
        title_pos = "center"
    })
    
    -- Налаштування
    vim.api.nvim_win_set_option(preview_win, "wrap", false)
    vim.api.nvim_win_set_option(preview_win, "cursorline", true)
    
    -- Кнопки внизу
    M.show_action_buttons()
    
    -- Хоткеї
    M.setup_preview_keymaps()
end

-- Показ кнопок дій
function M.show_action_buttons()
    local ns_id = vim.api.nvim_create_namespace("nvim-agent-buttons")
    
    -- Створюємо віртуальний текст з кнопками
    local buttons = {
        "[a]ccept  [d]iscard  [A]ccept All  [D]iscard All  [q]uit"
    }
    
    local line_count = vim.api.nvim_buf_line_count(preview_buf)
    
    for i, text in ipairs(buttons) do
        vim.api.nvim_buf_set_extmark(preview_buf, ns_id, line_count - 1, 0, {
            virt_text = {{text, "Comment"}},
            virt_text_pos = "below"
        })
    end
end

-- Налаштування хоткеїв для preview
function M.setup_preview_keymaps()
    local opts = {noremap = true, silent = true, buffer = preview_buf}
    
    -- Accept зміну
    vim.keymap.set('n', 'a', function()
        M.accept_current_change()
    end, opts)
    
    -- Discard зміну
    vim.keymap.set('n', 'd', function()
        M.discard_current_change()
    end, opts)
    
    -- Accept all
    vim.keymap.set('n', 'A', function()
        M.accept_all_changes()
    end, opts)
    
    -- Discard all
    vim.keymap.set('n', 'D', function()
        M.discard_all_changes()
    end, opts)
    
    -- Quit
    vim.keymap.set('n', 'q', function()
        M.close_preview()
    end, opts)
    
    vim.keymap.set('n', '<Esc>', function()
        M.close_preview()
    end, opts)
    
    -- Навігація
    vim.keymap.set('n', 'n', function()
        M.show_next_change()
    end, opts)
    
    vim.keymap.set('n', 'p', function()
        M.show_previous_change()
    end, opts)
end

-- Прийняти поточну зміну
function M.accept_current_change()
    if M.current_index > 0 and M.current_index <= #M.change_stack then
        local change = M.change_stack[M.current_index]
        
        if M.apply_change(change) then
            vim.notify("✅ Зміну прийнято", vim.log.levels.INFO)
            M.show_next_change()
        else
            vim.notify("❌ Помилка застосування зміни", vim.log.levels.ERROR)
        end
    end
end

-- Відхилити поточну зміну
function M.discard_current_change()
    if M.current_index > 0 and M.current_index <= #M.change_stack then
        local change = M.change_stack[M.current_index]
        
        vim.notify("🗑️  Зміну відхилено", vim.log.levels.INFO)
        M.show_next_change()
    end
end

-- Знайти зміну за ID
function M.find_change_by_id(change_id)
    for i, change in ipairs(M.change_stack) do
        if change.id == change_id then
            return change, i
        end
    end
    return nil, nil
end

-- Застосувати зміну за ID
function M.apply_change_by_id(change_id)
    local change, index = M.find_change_by_id(change_id)
    if not change then
        return false, "Зміну не знайдено"
    end
    
    local success = M.apply_change(change)
    if success then
        change.applied = true
        return true
    end
    return false, "Помилка застосування"
end

-- Відхилити зміну за ID
function M.discard_change_by_id(change_id)
    local change, index = M.find_change_by_id(change_id)
    if not change then
        return false, "Зміну не знайдено"
    end
    
    table.remove(M.change_stack, index)
    if M.current_index >= index then
        M.current_index = math.max(0, M.current_index - 1)
    end
    
    return true
end

-- Прийняти всі зміни
function M.accept_all_changes()
    local success_count = 0
    local failed_count = 0
    
    for _, change in ipairs(M.change_stack) do
        if not change.applied then
            if M.apply_change(change) then
                change.applied = true
                success_count = success_count + 1
            else
                failed_count = failed_count + 1
            end
        end
    end
    
    vim.notify(string.format("✅ Прийнято %d змін", success_count), vim.log.levels.INFO)
    M.close_preview()
    
    return success_count, failed_count
end

-- Знайти зміну по ID
function M.find_change_by_id(change_id)
    for _, change in ipairs(M.change_stack) do
        if change.id == change_id then
            return change
        end
    end
    return nil
end

-- Прийняти зміну по ID
function M.apply_change_by_id(change_id)
    local change = M.find_change_by_id(change_id)
    
    if not change then
        utils.log("error", "Change not found", { change_id = change_id })
        return false, "Зміну не знайдено"
    end
    
    if change.applied then
        utils.log("warning", "Change already applied", { change_id = change_id })
        return false, "Зміна вже застосована"
    end
    
    local success = M.apply_change(change)
    if success then
        change.applied = true
        utils.log("info", "Change applied", { change_id = change_id, type = change.type })
        return true, nil
    else
        utils.log("error", "Failed to apply change", { change_id = change_id })
        return false, "Помилка застосування зміни"
    end
end

-- Відхилити зміну по ID
function M.discard_change_by_id(change_id)
    local index = nil
    
    for i, change in ipairs(M.change_stack) do
        if change.id == change_id then
            index = i
            break
        end
    end
    
    if not index then
        utils.log("error", "Change not found", { change_id = change_id })
        return false, "Зміну не знайдено"
    end
    
    table.remove(M.change_stack, index)
    
    -- Оновлюємо current_index якщо потрібно
    if M.current_index >= index then
        M.current_index = math.max(0, M.current_index - 1)
    end
    
    utils.log("info", "Change discarded", { change_id = change_id })
    return true, nil
end

-- Відхилити всі зміни
function M.discard_all_changes()
    local count = #M.change_stack
    
    vim.notify("🗑️  Відхилено " .. count .. " змін", vim.log.levels.INFO)
    M.change_stack = {}
    M.current_index = 0
    M.close_preview()
end

-- Наступна зміна
function M.show_next_change()
    if M.current_index < #M.change_stack then
        M.current_index = M.current_index + 1
        M.show_preview(M.change_stack[M.current_index])
        M.update_progress_title()
    else
        vim.notify("ℹ️  Це остання зміна", vim.log.levels.INFO)
        M.close_preview()
    end
end

-- Попередня зміна
function M.show_previous_change()
    if M.current_index > 1 then
        M.current_index = M.current_index - 1
        M.show_preview(M.change_stack[M.current_index])
        M.update_progress_title()
    else
        vim.notify("ℹ️  Це перша зміна", vim.log.levels.INFO)
    end
end

-- Оновлення заголовку з прогресом
function M.update_progress_title()
    if preview_win and vim.api.nvim_win_is_valid(preview_win) then
        local title = string.format(" Перегляд змін (%d/%d) ", 
            M.current_index, #M.change_stack)
        
        vim.api.nvim_win_set_config(preview_win, {
            title = title,
            title_pos = "center"
        })
    end
end

-- Закриття preview
function M.close_preview()
    if preview_win and vim.api.nvim_win_is_valid(preview_win) then
        vim.api.nvim_win_close(preview_win, true)
    end
    
    preview_win = nil
    preview_buf = nil
end

-- Показ всіх змін
function M.show_changes_list()
    if #M.change_stack == 0 then
        vim.notify("ℹ️  Немає змін для перегляду", vim.log.levels.INFO)
        return
    end
    
    M.current_index = 1
    M.show_preview(M.change_stack[1])
    M.update_progress_title()
end

-- Очистка стеку змін
function M.clear_changes()
    M.change_stack = {}
    M.current_index = 0
    vim.notify("ℹ️  Стек змін очищено", vim.log.levels.INFO)
end

-- Отримання статистики змін
function M.get_changes_stats()
    local stats = {
        total = #M.change_stack,
        applied = 0,
        pending = 0,
        by_type = {}
    }
    
    for _, change in ipairs(M.change_stack) do
        if change.applied then
            stats.applied = stats.applied + 1
        else
            stats.pending = stats.pending + 1
        end
        
        stats.by_type[change.type] = (stats.by_type[change.type] or 0) + 1
    end
    
    return stats
end

return M
