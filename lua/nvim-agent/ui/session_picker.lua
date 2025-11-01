-- Session picker UI using nui.nvim components
local Menu = require("nui.menu")
local event = require("nui.utils.autocmd").event

local M = {}

local sessions = require('nvim-agent.chat_sessions')

-- Форматування дати
local function format_date(timestamp)
    local now = os.time()
    local diff = now - timestamp
    
    if diff < 60 then
        return "щойно"
    elseif diff < 3600 then
        return string.format("%d хв тому", math.floor(diff / 60))
    elseif diff < 86400 then
        return string.format("%d год тому", math.floor(diff / 3600))
    else
        return os.date("%d.%m.%Y", timestamp)
    end
end

-- Іконки режимів
local mode_icons = {
    ask = "💬",
    edit = "✏️",
    agent = "🤖"
}

-- Створення меню вибору сесій
function M.show_picker(on_select)
    local session_list = sessions.list_sessions()
    
    if #session_list == 0 then
        vim.notify("Немає доступних чатів", vim.log.levels.WARN)
        return
    end
    
    -- Створюємо menu items
    local menu_items = {}
    for _, session in ipairs(session_list) do
        local icon = mode_icons[session.mode] or "💬"
        local current_marker = session.is_current and "▶ " or "  "
        
        -- Формат: ▶ 💬 Chat Name (5 msg) • 2 хв тому
        local text = string.format(
            "%s%s %s (%d) • %s",
            current_marker,
            icon,
            session.name,
            session.message_count,
            format_date(session.updated_at)
        )
        
        table.insert(menu_items, Menu.item(text, {
            id = session.id,
            name = session.name,
            mode = session.mode,
            message_count = session.message_count
        }))
    end
    
    -- Створюємо NUI Menu
    local menu = Menu({
        position = "50%",
        size = {
            width = 60,
            height = math.min(#menu_items + 4, 20),
        },
        border = {
            style = "rounded",
            text = {
                top = " 📚 Оберіть чат ",
                top_align = "center",
            },
        },
        win_options = {
            winblend = 0,
            winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
        },
    }, {
        lines = menu_items,
        max_width = 58,
        keymap = {
            focus_next = { "j", "<Down>", "<Tab>" },
            focus_prev = { "k", "<Up>", "<S-Tab>" },
            close = { "<Esc>", "<C-c>", "q" },
            submit = { "<CR>", "<Space>" },
        },
        on_close = function()
            -- Нічого не робимо при закритті
        end,
        on_submit = function(item)
            if on_select then
                on_select(item.id)
            end
        end,
    })
    
    -- Відображаємо меню
    menu:mount()
    
    -- Додаємо підказки внизу
    vim.api.nvim_buf_call(menu.bufnr, function()
        vim.bo.modifiable = true
        vim.bo.readonly = false
        vim.api.nvim_buf_set_lines(menu.bufnr, -1, -1, false, {
            "",
            "  <Enter> - відкрити  <n> - новий  <d> - видалити  <Esc> - закрити"
        })
        vim.bo.modifiable = false
        vim.bo.readonly = true
    end)
    
    -- Додаткові кнопки
    menu:map("n", "n", function()
        menu:unmount()
        
        -- Запитуємо назву нового чату
        vim.ui.input({ prompt = "Назва нового чату: " }, function(name)
            if name and name ~= "" then
                local new_id = sessions.create_session(name)
                sessions.switch_session(new_id)
                if on_select then
                    on_select(new_id)
                end
            end
        end)
    end, {})
    
    menu:map("n", "d", function()
        local item = menu.tree:get_node()
        if item then
            local session_id = item.id
            
            -- Підтвердження видалення
            vim.ui.select(
                { "Так", "Ні" },
                { prompt = string.format("Видалити чат '%s'?", item.name) },
                function(choice)
                    if choice == "Так" then
                        local success, err = sessions.delete_session(session_id)
                        if success then
                            vim.notify("Чат видалено", vim.log.levels.INFO)
                            menu:unmount()
                            -- Показуємо меню знову
                            M.show_picker(on_select)
                        else
                            vim.notify("Помилка: " .. err, vim.log.levels.ERROR)
                        end
                    end
                end
            )
        end
    end, {})
    
    return menu
end

return M
