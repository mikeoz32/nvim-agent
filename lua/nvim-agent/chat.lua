-- Основний модуль чату для nvim-agent
local M = {}

local config = require('nvim-agent.config')
local api = require('nvim-agent.api')
local utils = require('nvim-agent.utils')
local chat_window = require('nvim-agent.ui.chat_window')
local modes = require('nvim-agent.modes')
local mcp = require('nvim-agent.mcp')
local tool_status = require('nvim-agent.ui.tool_status')
local inline_buttons = require('nvim-agent.ui.inline_buttons')
local sessions = require('nvim-agent.chat_sessions')

-- Історія чату (тепер використовуємо sessions)
local current_request = nil

-- Ініціалізація модуля
function M.setup()
    -- Ініціалізуємо сесії
    sessions.setup()
    
    -- Ініціалізуємо режими
    local cfg = config.get()
    modes.setup({
        default_mode = cfg.behavior.default_mode
    })
    
    -- Ініціалізуємо MCP
    mcp.setup(cfg.mcp or {})
    
    -- Ініціалізуємо inline кнопки
    inline_buttons.setup()
    
    return true
end

-- Відкриття чат-вікна
function M.open()
    if chat_window.is_open() then
        chat_window.focus_input()
        return true
    end
    
    local success = chat_window.create_window()
    if success then
        -- Відновлюємо історію в UI
        M.restore_chat_in_ui()
        
        -- Показуємо який файл буде автоматично доданий в контекст
        local cfg = config.get()
        if cfg.behavior.include_file_context then
            local file_context = utils.get_active_file_context()
            if file_context then
                local msg = string.format("📄 %s (%d %s)", 
                    file_context.filename,
                    file_context.total_lines,
                    file_context.total_lines == 1 and "рядок" or 
                    (file_context.total_lines < 5 and "рядки" or "рядків")
                )
                if file_context.partial then
                    msg = msg .. string.format(" — показую рядки %d-%d", 
                        file_context.lines[1], file_context.lines[2])
                end
                chat_window.add_system_message(msg)
            end
        end
        
        chat_window.focus_input()
        
        -- Відправляємо подію для інтеграції з Copilot
        vim.api.nvim_exec_autocmds("User", {
            pattern = "NvimAgentChatOpened"
        })
    end
    
    return success
end

-- Закриття чат-вікна
function M.close()
    -- Зберігаємо історію якщо потрібно
    local cfg = config.get()
    if cfg.behavior.auto_save_chat then
        M.save_history()
    end
    
    chat_window.close()
    
    -- Відправляємо подію для інтеграції з Copilot
    vim.api.nvim_exec_autocmds("User", {
        pattern = "NvimAgentChatClosed"
    })
    
    return true
end

-- Переключення чат-вікна
function M.toggle()
    if chat_window.is_open() then
        return M.close()
    else
        return M.open()
    end
end

-- Надсилання повідомлення
function M.send_message(message, context)
    if not message or message:match("^%s*$") then
        vim.notify("Повідомлення не може бути порожнім", vim.log.levels.WARN)
        return false
    end
    
    -- Скасовуємо попередній запит якщо він ще виконується
    if current_request then
        api.cancel_request()
        current_request = nil
        chat_window.add_system_message("Попередній запит скасовано")
    end
    
    -- Додаємо повідомлення користувача в історію сесії
    sessions.add_message({
        role = "user",
        content = message,
        timestamp = os.time(),
        context = context
    })
    
    -- Показуємо повідомлення в UI
    chat_window.add_user_message(message)
    
    -- Показуємо індикатор завантаження
    chat_window.add_system_message("🔄 Обробляю запит...")
    
    -- Викликаємо обробку запиту з можливістю tool calls
    M.process_chat_request(message, context)
    
    return true
end

-- Обробка запиту до API з підтримкою tool calls
function M.process_chat_request(message, context, previous_messages)
    local cfg = config.get()
    
    -- Підготовлюємо повідомлення для API
    local messages = previous_messages or {}
    
    -- Завжди додаємо системний промпт на початку (для нових та відновлених сесій)
    if #messages == 0 then
        table.insert(messages, {
            role = "system",
            content = M.get_system_prompt()
        })
        
        -- Додаємо контекст коду якщо є
        if context and context.code then
            local context_header = "Активний файл"
            if context.filename then
                if context.auto_attached then
                    context_header = "� Активний файл: " .. context.filename
                else
                    context_header = "�📎 Прикріплений файл: " .. context.filename
                end
            end
            
            local context_info = ""
            if context.total_lines then
                if context.partial then
                    -- Частина файлу
                    context_info = string.format(" (показано рядки %d-%d з %d)", 
                        context.lines[1], context.lines[2], context.total_lines)
                elseif context.total_lines > 300 then
                    -- Весь файл прикріплений явно
                    context_info = string.format(" (%d рядків)", context.total_lines)
                else
                    -- Маленький файл - автоматично весь
                    context_info = string.format(" (%d рядків)", context.total_lines)
                end
            end
            
            table.insert(messages, {
                role = "user",
                content = context_header .. context_info .. ":\n```" .. (context.filetype or "") .. "\n" .. context.code .. "\n```"
            })
        end
        
        -- Додаємо інформацію про проект для режиму Agent
        local current_mode = sessions.get_mode()
        if current_mode == "agent" then
            local cwd = vim.fn.getcwd()
            local project_name = vim.fn.fnamemodify(cwd, ":t")
            table.insert(messages, {
                role = "system",
                content = string.format("📁 Поточний проект: %s\n📍 Шлях: %s\n\nВикористовуй get_project_structure, find_files та read_file для дослідження проекту.", project_name, cwd)
            })
        end
        
        -- Додаємо історію повідомлень з сесії (останні N повідомлень)
        local history = sessions.get_history()
        local history_limit = 10
        local history_start = math.max(1, #history - history_limit)
        for i = history_start, #history do
            local msg = history[i]
            if msg.role ~= "tool" then  -- Пропускаємо tool повідомлення з історії
                table.insert(messages, {
                    role = msg.role,
                    content = msg.content
                })
            end
        end
    else
        -- Якщо це повторний виклик (після tool call), додаємо тільки нове повідомлення
        table.insert(messages, {
            role = "user",
            content = message
        })
    end
    
    -- Визначаємо чи потрібні tools (тільки в режимі Agent)
    local options = {}
    local current_mode = sessions.get_mode()  -- Отримуємо режим з сесії
    
    if current_mode == "agent" and cfg.mcp and cfg.mcp.enabled ~= false then
        options.tools = mcp.get_tools_schema()
        utils.log("debug", "Використовуємо MCP tools", {count = #options.tools})
    end
    
    -- Надсилаємо запит до API
    current_request = api.chat_completion(messages, function(err, response, tool_calls)
        current_request = nil
        
        if err then
            local error_msg = type(err) == "string" and err or vim.inspect(err)
            utils.log("error", "Помилка API запиту", { error = error_msg })
            chat_window.add_system_message("❌ Помилка: " .. error_msg)
            return
        end
        
        -- Обробляємо tool calls якщо є
        if tool_calls and #tool_calls > 0 then
            -- Додаємо повідомлення assistant з tool_calls
            -- OpenAI API: якщо є tool_calls, content може бути null або порожній рядок
            local assistant_msg = {
                role = "assistant",
                tool_calls = tool_calls
            }
            -- Додаємо content тільки якщо response не nil
            if response and response ~= "" then
                assistant_msg.content = response
            end
            table.insert(messages, assistant_msg)
            
            -- Показуємо що виконуємо tools з детальною інформацією (як у VS Code)
            if #tool_calls == 1 then
                local tool_call = tool_calls[1]
                local params = tool_call["function"].arguments
                
                -- Парсимо параметри якщо це JSON string
                if type(params) == "string" then
                    local success, parsed = pcall(vim.json.decode, params)
                    if success then
                        params = parsed
                    else
                        params = {}
                    end
                end
                
                local message = tool_status.format_tool_start(tool_call["function"].name, params)
                chat_window.add_system_message(message)
            else
                chat_window.add_system_message("🔧 Виконую " .. #tool_calls .. " " .. 
                    (#tool_calls <= 4 and "операції" or "операцій") .. ":")
                for i, tool_call in ipairs(tool_calls) do
                    local params = tool_call["function"].arguments
                    
                    -- Парсимо параметри якщо це JSON string
                    if type(params) == "string" then
                        local success, parsed = pcall(vim.json.decode, params)
                        if success then
                            params = parsed
                        else
                            params = {}
                        end
                    end
                    
                    local message = tool_status.format_tool_start(tool_call["function"].name, params)
                    chat_window.add_system_message("   " .. i .. ". " .. message)
                end
            end
            
            -- Виконуємо всі tool calls
            mcp.handle_tool_calls(tool_calls, function(tool_results)
                utils.log("debug", "Tool calls завершено", {
                    results_count = #tool_results
                })
                
                -- Додаємо результати tools в messages
                for _, result in ipairs(tool_results) do
                    table.insert(messages, result)
                end
                
                -- Збираємо ID змін для inline кнопок
                local change_ids = {}
                local has_changes = false
                
                -- Показуємо результати в UI (компактно, як у VS Code)
                chat_window.add_system_message("")
                for i, result in ipairs(tool_results) do
                    local tool_call = tool_calls[i]
                    local parsed = vim.json.decode(result.content)
                    
                    local result_msg = tool_status.format_tool_result(
                        tool_call["function"].name,
                        parsed,
                        parsed.success or false
                    )
                    
                    -- Додаємо номер якщо tools більше одного
                    if #tool_results > 1 then
                        chat_window.add_system_message("   " .. i .. ". " .. result_msg)
                    else
                        chat_window.add_system_message("✓ " .. result_msg)
                    end
                    
                    -- Якщо є pending_review, додаємо до списку змін
                    if parsed.pending_review and parsed.change_id then
                        table.insert(change_ids, parsed.change_id)
                        has_changes = true
                    end
                end
                
                -- Якщо є зміни в review mode, показуємо кнопки
                if has_changes and mcp.review_mode then
                    chat_window.add_system_message("")
                    chat_window.add_system_message(
                        string.format("📋 Є %d змін для перегляду. Натисніть Enter або ga щоб прийняти, gd щоб відхилити.", 
                        #change_ids)
                    )
                    
                    -- Показуємо inline кнопки в чат буфері
                    local chat_buf = chat_window.get_chat_buffer()
                    if chat_buf then
                        local line_count = vim.api.nvim_buf_line_count(chat_buf)
                        inline_buttons.show_buttons(chat_buf, line_count - 1, change_ids)
                    end
                end
                
                -- Надсилаємо повторний запит з результатами tools
                chat_window.add_system_message("")
                M.process_chat_request("", context, messages)
            end)
            
            return
        end
        
        -- Якщо є звичайна відповідь
        if response then
            -- Додаємо відповідь в історію сесії
            sessions.add_message({
                role = "assistant", 
                content = response,
                timestamp = os.time()
            })
            
            -- Показуємо відповідь в UI
            chat_window.add_ai_message(response)
        end
    end, options)
    
    return true
end

-- Обробка повідомлення від UI
function M.handle_user_message(message)
    local context = {}
    
    -- Отримуємо контекст активного файлу (як в VS Code)
    local cfg = config.get()
    if cfg.behavior.include_file_context then
        local file_context = utils.get_active_file_context()
        if file_context then
            context.code = file_context.content
            context.filetype = file_context.filetype
            context.filename = file_context.filename
            context.lines = file_context.lines
            context.line_count = file_context.line_count
            context.total_lines = file_context.total_lines
            context.auto_attached = true  -- Автоматично прикріплений
        end
    end
    
    return M.send_message(message, context)
end

-- Прикріпити поточний файл повністю (для Agent mode)
function M.attach_current_file(message)
    local buf = vim.api.nvim_get_current_buf()
    local filename = vim.api.nvim_buf_get_name(buf)
    
    if filename == "" then
        utils.log("warn", "Не можу прикріпити файл - буфер без імені")
        vim.notify("Не можу прикріпити файл - буфер без імені", vim.log.levels.WARN)
        return false
    end
    
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local total_lines = #lines
    local content = table.concat(lines, "\n")
    local short_name = vim.fn.fnamemodify(filename, ":t")
    
    -- Попередження якщо файл великий
    if total_lines > 500 then
        local choice = vim.fn.confirm(
            string.format("Файл %s містить %d рядків. Прикріпити весь файл?", short_name, total_lines),
            "&Так\n&Ні\n&Перші 200",
            1
        )
        
        if choice == 2 then
            return false
        elseif choice == 3 then
            -- Беремо тільки перші 200 рядків
            lines = vim.list_slice(lines, 1, 200)
            content = table.concat(lines, "\n")
            total_lines = 200
        end
    end
    
    local context = {
        code = content,
        filetype = vim.bo.filetype,
        filename = short_name,
        lines = {1, total_lines},
        line_count = total_lines,
        total_lines = vim.api.nvim_buf_line_count(buf),
        attached = true  -- Позначаємо що файл явно прикріплений
    }
    
    return M.send_message(message or "", context)
end

-- Отримання системного промпту
function M.get_system_prompt()
    local cfg = config.get()
    
    local system_prompt = [[Ти - AI помічник програміста для Neovim. Твоє завдання:

1. Допомагати з написанням, поясненням та покращенням коду
2. Відповідати українською мовою (якщо не попросили іншою)
3. Давати практичні та корисні поради
4. Пояснювати складні концепції простою мовою
5. Пропонувати найкращі практики програмування

Коли тобі надають код:
- Аналізуй його ретельно
- Вказуй на потенційні проблеми
- Пропонуй покращення
- Поясни як працює код якщо потрібно

Коли генеруєш код:
- Використовуй найкращі практики
- Додавай коментарі де потрібно
- Роби код читабельним та зрозумілим
- Пропонуй альтернативні рішення якщо є

Будь корисним, дружелюбним та професійним.]]

    -- Додаємо інформацію про режим з поточної сесії
    local current_mode = sessions.get_mode()
    local mode_suffix = modes.get_prompt_suffix(current_mode)
    system_prompt = system_prompt .. mode_suffix

    return system_prompt
end

-- Очищення чату
function M.clear()
    sessions.clear_current_session()
    
    if chat_window.is_open() then
        chat_window.clear()
    end
    
    return true
end

-- Отримання історії чату
function M.get_history()
    return vim.deepcopy(sessions.get_history())
end

-- Збереження історії (тепер автоматично через sessions)
function M.save_history()
    -- Deprecated - sessions зберігаються автоматично
    return true
end

-- Завантаження історії (тепер автоматично через sessions)
function M.load_history()
    -- Deprecated - sessions завантажуються автоматично
    return true
end

-- Відновлення чату в UI
function M.restore_chat_in_ui()
    if not chat_window.is_open() then
        return false
    end
    
    -- Показуємо останні повідомлення з поточної сесії (максимум 50)
    local history = sessions.get_history()
    local recent_messages = {}
    local start_idx = math.max(1, #history - 49)
    
    for i = start_idx, #history do
        table.insert(recent_messages, history[i])
    end
    
    -- Додаємо повідомлення в UI
    for _, msg in ipairs(recent_messages) do
        if msg.role == "user" then
            chat_window.add_user_message(msg.content)
        elseif msg.role == "assistant" then
            -- Перевіряємо тип content (може бути таблиця зі старої сесії)
            local content = msg.content
            if type(content) == "table" then
                -- Якщо це повний JSON response, витягуємо текст
                if content.choices and content.choices[1] and content.choices[1].message then
                    content = content.choices[1].message.content or "[порожня відповідь]"
                else
                    content = vim.inspect(content)
                end
            end
            chat_window.add_ai_message(content or "")
        end
    end
    
    if #recent_messages > 0 then
        chat_window.add_system_message("Відновлено " .. #recent_messages .. " повідомлень з історії")
    end
    
    return true
end

-- Експорт чату
function M.export_chat(format, filename)
    format = format or "markdown"
    filename = filename or ("nvim-agent-chat-" .. os.date("%Y%m%d-%H%M%S") .. "." .. format)
    
    local content = {}
    local history = sessions.get_history()
    
    if format == "markdown" then
        table.insert(content, "# nvim-agent Chat Export")
        table.insert(content, "")
        table.insert(content, "Дата експорту: " .. os.date("%Y-%m-%d %H:%M:%S"))
        table.insert(content, "")
        
        for _, msg in ipairs(history) do
            local timestamp = os.date("%H:%M:%S", msg.timestamp)
            local role_name = msg.role == "user" and "Користувач" or 
                             msg.role == "assistant" and "AI" or "Система"
            
            table.insert(content, "## [" .. timestamp .. "] " .. role_name)
            table.insert(content, "")
            table.insert(content, msg.content)
            table.insert(content, "")
        end
    elseif format == "json" then
        content = vim.json.encode({
            export_date = os.date("%Y-%m-%d %H:%M:%S"),
            version = "1.0",
            messages = history
        })
    end
    
    -- Зберігаємо файл
    local filepath = vim.fn.expand("~/" .. filename)
    local file = io.open(filepath, "w")
    
    if file then
        if type(content) == "table" then
            file:write(table.concat(content, "\n"))
        else
            file:write(content)
        end
        file:close()
        
        vim.notify("Чат експортовано в: " .. filepath, vim.log.levels.INFO)
        return true
    else
        vim.notify("Не вдалося зберегти файл: " .. filepath, vim.log.levels.ERROR)
        return false
    end
end

-- Статистика чату
function M.get_stats()
    local user_messages = 0
    local ai_messages = 0
    local total_chars = 0
    local history = sessions.get_history()
    
    for _, msg in ipairs(history) do
        if msg.role == "user" then
            user_messages = user_messages + 1
        elseif msg.role == "assistant" then
            ai_messages = ai_messages + 1
        end
        total_chars = total_chars + string.len(msg.content)
    end
    
    return {
        total_messages = #history,
        user_messages = user_messages,
        ai_messages = ai_messages,
        total_characters = total_chars,
        average_message_length = #history > 0 and math.floor(total_chars / #history) or 0
    }
end

-- Переключення режиму
function M.cycle_mode()
    local current = sessions.get_mode()
    local modes_list = {"ask", "edit", "agent"}
    local next_mode = nil
    
    for i, mode in ipairs(modes_list) do
        if mode == current then
            next_mode = modes_list[(i % #modes_list) + 1]
            break
        end
    end
    
    if next_mode then
        sessions.set_mode(next_mode)
        if chat_window.is_open() then
            chat_window.add_system_message("Режим змінено на: " .. mode_name)
            chat_window.update_mode_indicator()
        end
        vim.notify("Режим: " .. next_mode, vim.log.levels.INFO)
        return true, next_mode
    end
    return false
end

-- Встановлення режиму
function M.set_mode(mode)
    if not vim.tbl_contains({"ask", "edit", "agent"}, mode) then
        vim.notify("Невідомий режим: " .. mode, vim.log.levels.ERROR)
        return false
    end
    
    sessions.set_mode(mode)
    if chat_window.is_open() then
        local mode_names = {ask = "Ask", edit = "Edit", agent = "Agent"}
        chat_window.add_system_message("Режим змінено на: " .. mode_names[mode])
        chat_window.update_mode_indicator()
    end
    vim.notify("Режим: " .. mode, vim.log.levels.INFO)
    return true
end

-- Отримати поточний режим
function M.get_mode()
    return sessions.get_mode()
end

-- Отримати інформацію про режим
function M.get_mode_info()
    local mode = sessions.get_mode()
    local mode_info = {
        ask = {name = "Ask", icon = "💬", description = "Запитання без змін коду"},
        edit = {name = "Edit", icon = "✏️", description = "Редагування коду"},
        agent = {name = "Agent", icon = "🤖", description = "Автономна робота з інструментами"}
    }
    return mode_info[mode] or mode_info.ask
end

-- === Функції для роботи з сесіями ===

-- Створити нову сесію
function M.new_session(name)
    local session_id = sessions.create_session(name)
    sessions.switch_session(session_id)
    
    if chat_window.is_open() then
        chat_window.clear()
        chat_window.add_system_message("Створено нову сесію: " .. (name or "Chat"))
    end
    
    return session_id
end

-- Перемкнутися на іншу сесію
function M.switch_session(session_id)
    local success, err = sessions.switch_session(session_id)
    if not success then
        vim.notify("Помилка: " .. err, vim.log.levels.ERROR)
        return false
    end
    
    if chat_window.is_open() then
        chat_window.clear()
        M.restore_chat_in_ui()
    end
    
    return true
end

-- Видалити сесію
function M.delete_session(session_id)
    local success, err = sessions.delete_session(session_id)
    if not success then
        vim.notify("Помилка: " .. err, vim.log.levels.ERROR)
        return false
    end
    
    if chat_window.is_open() then
        chat_window.clear()
        M.restore_chat_in_ui()
    end
    
    vim.notify("Сесію видалено", vim.log.levels.INFO)
    return true
end

-- Отримати список сесій
function M.get_sessions()
    return sessions.get_all_sessions()
end

-- Перейменувати сесію
function M.rename_session(session_id, new_name)
    return sessions.rename_session(session_id, new_name)
end

return M