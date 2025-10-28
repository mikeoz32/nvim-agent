-- Inline кнопки для Accept/Discard змін (як у VS Code Copilot)
local M = {}

local change_manager = require('nvim-agent.change_manager')

-- Namespace для віртуального тексту
M.ns_id = vim.api.nvim_create_namespace('nvim_agent_inline_buttons')

-- ID останніх кнопок для cleanup
M.last_buttons = {}

-- Створення віртуального тексту з кнопками
function M.show_buttons(buf, line, change_ids)
    if not vim.api.nvim_buf_is_valid(buf) then
        return
    end
    
    -- Очищаємо старі кнопки
    M.clear_buttons(buf)
    
    local change_count = #change_ids
    
    -- Формуємо текст кнопок
    local buttons_text = string.format(
        "  [Accept (%d)] [Discard (%d)] [Accept All] [Discard All]  ",
        change_count,
        change_count
    )
    
    -- Додаємо віртуальний текст з кнопками
    local extmark_id = vim.api.nvim_buf_set_extmark(buf, M.ns_id, line, 0, {
        virt_text = {
            { "  ", "Normal" },
            { "[Accept (" .. change_count .. ")]", "NvimAgentButtonAccept" },
            { " ", "Normal" },
            { "[Discard (" .. change_count .. ")]", "NvimAgentButtonDiscard" },
            { " ", "Normal" },
            { "[Accept All]", "NvimAgentButtonAcceptAll" },
            { " ", "Normal" },
            { "[Discard All]", "NvimAgentButtonDiscardAll" },
        },
        virt_text_pos = "eol",
    })
    
    -- Зберігаємо інформацію про кнопки
    table.insert(M.last_buttons, {
        buf = buf,
        line = line,
        extmark_id = extmark_id,
        change_ids = change_ids,
    })
    
    -- Встановлюємо keymap для натискання кнопок
    M.setup_button_keymaps(buf, line, change_ids)
    
    return extmark_id
end

-- Очищення всіх кнопок
function M.clear_buttons(buf)
    if buf and vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_clear_namespace(buf, M.ns_id, 0, -1)
    end
    M.last_buttons = {}
end

-- Налаштування keymaps для кнопок
function M.setup_button_keymaps(buf, line, change_ids)
    local opts = { noremap = true, silent = true, buffer = buf }
    
    -- ga - Accept (коли курсор на рядку з кнопками)
    vim.keymap.set('n', 'ga', function()
        local current_line = vim.api.nvim_win_get_cursor(0)[1] - 1
        if current_line == line then
            M.accept_changes(buf, change_ids)
        end
    end, opts)
    
    -- gd - Discard (коли курсор на рядку з кнопками)
    vim.keymap.set('n', 'gd', function()
        local current_line = vim.api.nvim_win_get_cursor(0)[1] - 1
        if current_line == line then
            M.discard_changes(buf, change_ids)
        end
    end, opts)
    
    -- gA - Accept All
    vim.keymap.set('n', 'gA', function()
        local current_line = vim.api.nvim_win_get_cursor(0)[1] - 1
        if current_line == line then
            M.accept_all_changes(buf)
        end
    end, opts)
    
    -- gD - Discard All
    vim.keymap.set('n', 'gD', function()
        local current_line = vim.api.nvim_win_get_cursor(0)[1] - 1
        if current_line == line then
            M.discard_all_changes(buf)
        end
    end, opts)
    
    -- Enter - також Accept (зручніше)
    vim.keymap.set('n', '<CR>', function()
        local current_line = vim.api.nvim_win_get_cursor(0)[1] - 1
        if current_line == line then
            M.accept_changes(buf, change_ids)
            return
        end
        -- Інакше - звичайний Enter
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<CR>', true, false, true), 'n', false)
    end, opts)
    
    -- gp - Preview (відкрити повний preview)
    vim.keymap.set('n', 'gp', function()
        local current_line = vim.api.nvim_win_get_cursor(0)[1] - 1
        if current_line == line then
            require('nvim-agent.commands').review_changes()
        end
    end, opts)
end

-- Accept конкретних змін
function M.accept_changes(buf, change_ids)
    local accepted = 0
    local failed = 0
    
    for _, change_id in ipairs(change_ids) do
        local success, err = change_manager.apply_change_by_id(change_id)
        if success then
            accepted = accepted + 1
        else
            failed = failed + 1
        end
    end
    
    -- Очищаємо кнопки
    M.clear_buttons(buf)
    
    -- Показуємо результат
    if failed == 0 then
        M.show_result_message(buf, string.format("✅ Прийнято %d змін", accepted))
    else
        M.show_result_message(buf, string.format("⚠️  Прийнято %d, помилок: %d", accepted, failed))
    end
end

-- Discard конкретних змін
function M.discard_changes(buf, change_ids)
    local discarded = 0
    
    for _, change_id in ipairs(change_ids) do
        local success = change_manager.discard_change_by_id(change_id)
        if success then
            discarded = discarded + 1
        end
    end
    
    -- Очищаємо кнопки
    M.clear_buttons(buf)
    
    -- Показуємо результат
    M.show_result_message(buf, string.format("🗑️  Відхилено %d змін", discarded))
end

-- Accept всіх змін
function M.accept_all_changes(buf)
    local stats = change_manager.get_changes_stats()
    local success, failed = change_manager.accept_all_changes()
    
    M.clear_buttons(buf)
    
    if failed == 0 then
        M.show_result_message(buf, string.format("✅ Прийнято всі зміни (%d)", success))
    else
        M.show_result_message(buf, string.format("⚠️  Прийнято %d, помилок: %d", success, failed))
    end
end

-- Discard всіх змін
function M.discard_all_changes(buf)
    local stats = change_manager.get_changes_stats()
    change_manager.discard_all_changes()
    
    M.clear_buttons(buf)
    M.show_result_message(buf, string.format("🗑️  Відхилено всі зміни (%d)", stats.pending))
end

-- Показати результат як віртуальний текст
function M.show_result_message(buf, message)
    if not vim.api.nvim_buf_is_valid(buf) then
        return
    end
    
    local line_count = vim.api.nvim_buf_line_count(buf)
    
    -- Додаємо віртуальний текст з результатом
    vim.api.nvim_buf_set_extmark(buf, M.ns_id, line_count - 1, 0, {
        virt_text = { { "  " .. message, "NvimAgentSuccess" } },
        virt_text_pos = "eol",
    })
    
    -- Автоматично прибираємо через 3 секунди
    vim.defer_fn(function()
        if vim.api.nvim_buf_is_valid(buf) then
            vim.api.nvim_buf_clear_namespace(buf, M.ns_id, 0, -1)
        end
    end, 3000)
end

-- Створення highlight groups для кнопок
function M.setup_highlights()
    -- Accept кнопка - зелена
    vim.api.nvim_set_hl(0, 'NvimAgentButtonAccept', {
        fg = '#98c379',  -- зелений
        bg = '#2d4d2d',  -- темно-зелений фон
        bold = true,
    })
    
    -- Discard кнопка - червона
    vim.api.nvim_set_hl(0, 'NvimAgentButtonDiscard', {
        fg = '#e06c75',  -- червоний
        bg = '#4d2d2d',  -- темно-червоний фон
        bold = true,
    })
    
    -- Accept All - яскраво-зелена
    vim.api.nvim_set_hl(0, 'NvimAgentButtonAcceptAll', {
        fg = '#56b6c2',  -- cyan
        bg = '#2d3d4d',  -- темно-синій фон
        bold = true,
    })
    
    -- Discard All - помаранчева
    vim.api.nvim_set_hl(0, 'NvimAgentButtonDiscardAll', {
        fg = '#e5c07b',  -- жовтий/помаранчевий
        bg = '#4d3d2d',  -- темно-жовтий фон
        bold = true,
    })
    
    -- Success message - зелений
    vim.api.nvim_set_hl(0, 'NvimAgentSuccess', {
        fg = '#98c379',
        bold = true,
    })
end

-- Ініціалізація
function M.setup()
    M.setup_highlights()
end

return M
