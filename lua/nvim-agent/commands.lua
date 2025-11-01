-- Модуль команд для nvim-agent
local M = {}

local config = require('nvim-agent.config')
local api = require('nvim-agent.api')
local utils = require('nvim-agent.utils')
local chat = require('nvim-agent.chat')
local modes = require('nvim-agent.modes')

-- Реєстрація всіх команд
function M.register()
    local cfg = config.get()
    
    -- Основні команди плагіна
    vim.api.nvim_create_user_command('NvimAgentChat', function()
        chat.toggle()
    end, {
        desc = 'Відкрити/закрити чат з AI'
    })
    
    vim.api.nvim_create_user_command('NvimAgentExplain', function()
        M.explain_code()
    end, {
        desc = 'Пояснити вибраний код',
        range = true
    })
    
    vim.api.nvim_create_user_command('NvimAgentGenerate', function(opts)
        M.generate_code(opts.args)
    end, {
        desc = 'Згенерувати код за описом',
        nargs = '*'
    })
    
    vim.api.nvim_create_user_command('NvimAgentRefactor', function()
        M.refactor_code()
    end, {
        desc = 'Покращити вибраний код',
        range = true
    })
    
    vim.api.nvim_create_user_command('NvimAgentTest', function()
        M.generate_tests()
    end, {
        desc = 'Створити тести для коду',
        range = true
    })
    
    vim.api.nvim_create_user_command('NvimAgentDoc', function()
        M.generate_docs()
    end, {
        desc = 'Створити документацію для коду',
        range = true
    })
    
    vim.api.nvim_create_user_command('NvimAgentReview', function()
        M.review_code()
    end, {
        desc = 'Провести код-рев\'ю',
        range = true
    })
    
    vim.api.nvim_create_user_command('NvimAgentFix', function()
        M.fix_code()
    end, {
        desc = 'Знайти та виправити помилки в коді',
        range = true
    })
    
    -- Утилітарні команди
    vim.api.nvim_create_user_command('NvimAgentClear', function()
        chat.clear()
    end, {
        desc = 'Очистити історію поточного чату'
    })
    
    -- Команди для управління сесіями
    vim.api.nvim_create_user_command('NvimAgentSessions', function()
        local session_picker = require('nvim-agent.ui.session_picker')
        session_picker.show_picker(function(session_id)
            -- Перемикаємося на обрану сесію
            local sessions = require('nvim-agent.chat_sessions')
            sessions.switch_session(session_id)
            
            -- Закриваємо поточний чат якщо відкритий
            chat.close()
            
            -- Відкриваємо чат з новою сесією
            chat.open()
        end)
    end, {
        desc = 'Показати список чатів (сесій)'
    })
    
    vim.api.nvim_create_user_command('NvimAgentNewChat', function(opts)
        local name = opts.args ~= '' and opts.args or nil
        chat.new_session(name)
        vim.notify("Створено новий чат" .. (name and (": " .. name) or ""), vim.log.levels.INFO)
    end, {
        desc = 'Створити новий чат',
        nargs = '?',
    })
    
    vim.api.nvim_create_user_command('NvimAgentListChats', function()
        local all_sessions = chat.get_sessions()
        
        if #all_sessions == 0 then
            vim.notify("Немає активних чатів", vim.log.levels.INFO)
            return
        end
        
        -- Використовуємо vim.ui.select для вибору
        local items = {}
        for _, session in ipairs(all_sessions) do
            local current_marker = session.is_current and "► " or "  "
            local mode_icons = {ask = "💬", edit = "✏️", agent = "🤖"}
            local mode_icon = mode_icons[session.mode] or "❓"
            local item_text = string.format("%s%s %s (%d повідомлень)", 
                current_marker, mode_icon, session.name, session.message_count)
            table.insert(items, {
                text = item_text,
                id = session.id,
                session = session
            })
        end
        
        vim.ui.select(items, {
            prompt = "Виберіть чат:",
            format_item = function(item) return item.text end,
        }, function(choice)
            if choice then
                chat.switch_session(choice.id)
                vim.notify("Переключено на: " .. choice.session.name, vim.log.levels.INFO)
            end
        end)
    end, {
        desc = 'Показати список чатів'
    })
    
    vim.api.nvim_create_user_command('NvimAgentDeleteChat', function(opts)
        if opts.args == '' then
            -- Показуємо список для вибору
            local all_sessions = chat.get_sessions()
            if #all_sessions <= 1 then
                vim.notify("Не можна видалити останній чат", vim.log.levels.WARN)
                return
            end
            
            local items = {}
            for _, session in ipairs(all_sessions) do
                if not session.is_current then  -- Не показуємо поточний
                    table.insert(items, {
                        text = string.format("%s (%d повідомлень)", session.name, session.message_count),
                        id = session.id
                    })
                end
            end
            
            vim.ui.select(items, {
                prompt = "Видалити чат:",
                format_item = function(item) return item.text end,
            }, function(choice)
                if choice then
                    chat.delete_session(choice.id)
                end
            end)
        else
            -- Видаляємо поточний чат
            local session = chat.get_sessions()[1]  -- Поточний завжди перший
            if session then
                chat.delete_session(session.id)
            end
        end
    end, {
        desc = 'Видалити чат',
        nargs = '?',
    })
    
    vim.api.nvim_create_user_command('NvimAgentRenameChat', function(opts)
        if opts.args == '' then
            vim.notify("Введіть нову назву чату", vim.log.levels.WARN)
            return
        end
        
        local all_sessions = chat.get_sessions()
        local current_session = nil
        for _, s in ipairs(all_sessions) do
            if s.is_current then
                current_session = s
                break
            end
        end
        
        if current_session then
            chat.rename_session(current_session.id, opts.args)
            vim.notify("Чат перейменовано на: " .. opts.args, vim.log.levels.INFO)
        end
    end, {
        desc = 'Перейменувати поточний чат',
        nargs = 1,
    })
    
    vim.api.nvim_create_user_command('NvimAgentExport', function(opts)
        local format = opts.args and opts.args ~= '' and opts.args or 'markdown'
        chat.export_chat(format)
    end, {
        desc = 'Експортувати чат',
        nargs = '?',
        complete = function() return {'markdown', 'json'} end
    })
    
    vim.api.nvim_create_user_command('NvimAgentStats', function()
        local stats = chat.get_stats()
        local msg = string.format(
            "Статистика чату:\n" ..
            "📊 Всього повідомлень: %d\n" ..
            "👤 Від користувача: %d\n" .. 
            "🤖 Від AI: %d\n" ..
            "📝 Всього символів: %d\n" ..
            "📏 Середня довжина: %d символів",
            stats.total_messages, stats.user_messages, 
            stats.ai_messages, stats.total_characters, 
            stats.average_message_length
        )
        vim.notify(msg, vim.log.levels.INFO)
    end, {
        desc = 'Показати статистику використання'
    })
    
    vim.api.nvim_create_user_command('NvimAgentTestConnection', function()
        api.test_connection(function(success, message)
            if success then
                vim.notify("✅ " .. message, vim.log.levels.INFO)
            else
                vim.notify("❌ " .. message, vim.log.levels.ERROR)
            end
        end)
    end, {
        desc = 'Перевірити з\'єднання з API'
    })
    
    vim.api.nvim_create_user_command('NvimAgentProvider', function(opts)
        local provider = opts.args
        if provider == "" then
            local cfg = config.get()
            vim.notify("Поточний провайдер: " .. cfg.api.provider, vim.log.levels.INFO)
            return
        end
        
        local valid_providers = {"openai", "anthropic", "github-copilot", "local"}
        if not vim.tbl_contains(valid_providers, provider) then
            vim.notify("Невідомий провайдер: " .. provider .. ". Доступні: " .. table.concat(valid_providers, ", "), vim.log.levels.ERROR)
            return
        end
        
        config.set_option("api.provider", provider)
        vim.notify("Провайдер змінено на: " .. provider, vim.log.levels.INFO)
    end, {
        desc = 'Змінити AI провайдера',
        nargs = '?',
        complete = function() 
            return {'openai', 'anthropic', 'github-copilot', 'local'} 
        end
    })
    
    vim.api.nvim_create_user_command('NvimAgentCopilot', function(opts)
        local action = opts.args
        local cfg = config.get()
        
        if action == "status" or action == "" then
            local has_copilot = config.check_copilot_integration()
            local status = has_copilot and "встановлено" or "не встановлено"
            local provider_status = cfg.api.provider == "github-copilot" and "активний" or "неактивний"
            
            vim.notify(string.format(
                "GitHub Copilot:\n" ..
                "📦 Плагін: %s\n" ..
                "🔌 nvim-agent провайдер: %s\n" ..
                "🔗 Інтеграція: %s",
                status, provider_status,
                cfg.behavior.disable_copilot_when_active and "увімкнена" or "вимкнена"
            ), vim.log.levels.INFO)
        elseif action == "enable" then
            config.set_option("api.provider", "github-copilot")
            vim.notify("GitHub Copilot провайдер увімкнено", vim.log.levels.INFO)
        elseif action == "disable" then
            config.set_option("api.provider", "openai")
            vim.notify("GitHub Copilot провайдер вимкнено", vim.log.levels.INFO)
        end
    end, {
        desc = 'Керування інтеграцією з GitHub Copilot',
        nargs = '?',
        complete = function() return {'status', 'enable', 'disable'} end
    })
    
    -- Команда для вибору моделі
    vim.api.nvim_create_user_command('NvimAgentModel', function(opts)
        local model = opts.args
        local cfg = config.get()
        
        if model == "" then
            -- Показуємо поточну модель
            vim.notify("Поточна модель: " .. (cfg.api.model or "не встановлено"), vim.log.levels.INFO)
            
            -- Якщо використовуємо GitHub Copilot, показуємо доступні моделі
            if cfg.api.provider == "github-copilot" then
                local api = require('nvim-agent.api')
                api.get_models(function(models, err)
                    if err then
                        vim.notify("Помилка отримання моделей: " .. err, vim.log.levels.ERROR)
                        return
                    end
                    
                    if models and #models > 0 then
                        local msg = "Доступні моделі GitHub Copilot:\n\n"
                        
                        -- Групуємо моделі за категоріями
                        local by_category = {}
                        for _, m in ipairs(models) do
                            local cat = m.category or "other"
                            if not by_category[cat] then
                                by_category[cat] = {}
                            end
                            table.insert(by_category[cat], m)
                        end
                        
                        -- Спочатку показуємо основні категорії
                        local categories = {"versatile", "powerful", "lightweight", "speed", "reasoning", "other"}
                        local cat_names = {
                            versatile = "🎯 Універсальні",
                            powerful = "💪 Потужні",
                            lightweight = "🪶 Легкі",
                            speed = "⚡ Швидкі",
                            reasoning = "🧠 Розмірковування",
                            other = "📦 Інші"
                        }
                        
                        for _, cat in ipairs(categories) do
                            if by_category[cat] then
                                msg = msg .. (cat_names[cat] or cat) .. ":\n"
                                for _, m in ipairs(by_category[cat]) do
                                    local current = m.id == cfg.api.model and " ✓" or ""
                                    msg = msg .. string.format("  • %s - %s%s\n", m.id, m.name, current)
                                end
                                msg = msg .. "\n"
                            end
                        end
                        
                        msg = msg .. "Щоб змінити: :NvimAgentModel <model_id>"
                        vim.notify(msg, vim.log.levels.INFO)
                    end
                end)
            else
                vim.notify("Для перегляду моделей використовуйте провайдер 'github-copilot'", vim.log.levels.INFO)
            end
        else
            -- Встановлюємо модель
            config.set_option("api.model", model)
            vim.notify("Модель змінено на: " .. model, vim.log.levels.INFO)
        end
    end, {
        desc = 'Встановити або показати модель AI',
        nargs = '?',
        complete = function()
            local cfg = config.get()
            if cfg.api.provider == "github-copilot" then
                -- Повертаємо основні моделі для автодоповнення
                return {
                    -- Versatile
                    'gpt-4o',
                    'gpt-5',
                    'gpt-4.1',
                    'claude-sonnet-4.5',
                    'claude-sonnet-4',
                    'claude-3.5-sonnet',
                    'claude-haiku-4.5',
                    -- Powerful
                    'gemini-2.5-pro',
                    'gpt-5-codex',
                    -- Lightweight
                    'gpt-5-mini',
                    'gpt-4o-mini',
                    'grok-code-fast-1',
                    -- Other
                    'o3-mini-paygo',
                }
            end
            return {'gpt-4', 'gpt-4o', 'gpt-3.5-turbo', 'claude-3-opus', 'claude-3-sonnet'}
        end
    })
    
    -- Команда для інтерактивного вибору моделі
    vim.api.nvim_create_user_command('NvimAgentSelectModel', function()
        local cfg = config.get()
        local api = require('nvim-agent.api')
        
        api.get_models(function(models, err)
            if err then
                vim.notify("Помилка отримання моделей: " .. err, vim.log.levels.ERROR)
                return
            end
            
            if not models or #models == 0 then
                vim.notify("Моделі не знайдено", vim.log.levels.WARN)
                return
            end
            
            -- Групуємо за категоріями для красивого відображення
            local by_category = {}
            for _, m in ipairs(models) do
                local cat = m.category or "other"
                if not by_category[cat] then
                    by_category[cat] = {}
                end
                table.insert(by_category[cat], m)
            end
            
            -- Створюємо відформатований список
            local items = {}
            local cat_icons = {
                versatile = "🎯",
                powerful = "💪",
                lightweight = "🪶",
                speed = "⚡",
                reasoning = "🧠",
                other = "📦"
            }
            
            local categories = {"versatile", "powerful", "lightweight", "speed", "reasoning", "other"}
            for _, cat in ipairs(categories) do
                if by_category[cat] then
                    -- Додаємо заголовок категорії
                    table.insert(items, {
                        display = string.format("━━━ %s %s ━━━", cat_icons[cat] or "📦", cat:upper()),
                        id = nil,
                        category_header = true
                    })
                    
                    -- Додаємо моделі
                    for _, m in ipairs(by_category[cat]) do
                        local current = m.id == cfg.api.model and " ✓" or ""
                        table.insert(items, {
                            display = string.format("  %s%s", m.name, current),
                            id = m.id,
                            name = m.name
                        })
                    end
                end
            end
            
            -- Показуємо селектор
            vim.ui.select(items, {
                prompt = "Оберіть модель:",
                format_item = function(item)
                    return item.display
                end
            }, function(choice)
                if not choice or choice.category_header then
                    return
                end
                
                config.set_option("api.model", choice.id)
                vim.notify(string.format("✓ Модель змінено на: %s (%s)", choice.name, choice.id), vim.log.levels.INFO)
            end)
        end)
    end, {
        desc = 'Інтерактивний вибір моделі AI'
    })
    
    -- Команди для режимів
    vim.api.nvim_create_user_command('NvimAgentMode', function(opts)
        local mode = opts.args
        
        if mode == "" then
            -- Показуємо поточний режим та доступні режими
            local current_mode = chat.get_mode()
            local mode_info = chat.get_mode_info()
            local all_modes = modes.get_all_modes()
            
            local msg = string.format("Поточний режим: %s\n\nДоступні режими:\n", mode_info.name)
            for _, m in ipairs(all_modes) do
                msg = msg .. string.format("%s %s - %s\n", 
                    m.current and "►" or " ",
                    m.name, 
                    m.description
                )
            end
            
            vim.notify(msg, vim.log.levels.INFO)
        else
            chat.set_mode(mode)
        end
    end, {
        desc = 'Встановити або показати режим роботи',
        nargs = '?',
        complete = function() 
            return {'ask', 'edit', 'agent'} 
        end
    })
    
    vim.api.nvim_create_user_command('NvimAgentModeHelp', function()
        local help = modes.get_mode_help()
        vim.notify(help, vim.log.levels.INFO)
    end, {
        desc = 'Показати довідку по поточному режиму'
    })
    
    -- Прикріпити файл до чату
    vim.api.nvim_create_user_command('NvimAgentAttachFile', function(opts)
        local message = opts.args ~= "" and opts.args or nil
        chat.attach_current_file(message)
    end, {
        desc = 'Прикріпити поточний файл до чату (як #file в VS Code)',
        nargs = '?'
    })
    
    -- Команди для керування змінами
    vim.api.nvim_create_user_command('NvimAgentReviewChanges', function()
        M.review_changes()
    end, {
        desc = 'Переглянути та прийняти/відхилити зміни від AI'
    })
    
    vim.api.nvim_create_user_command('NvimAgentAcceptAll', function()
        M.accept_all_changes()
    end, {
        desc = 'Прийняти всі зміни від AI'
    })
    
    vim.api.nvim_create_user_command('NvimAgentDiscardAll', function()
        M.discard_all_changes()
    end, {
        desc = 'Відхилити всі зміни від AI'
    })
    
    vim.api.nvim_create_user_command('NvimAgentReviewMode', function(opts)
        M.toggle_review_mode(opts.args == 'on')
    end, {
        desc = 'Увімкнути/вимкнути режим перегляду змін',
        nargs = '?',
        complete = function() return {'on', 'off'} end
    })
    
    vim.api.nvim_create_user_command('NvimAgentChangesStats', function()
        M.show_changes_stats()
    end, {
        desc = 'Показати статистику змін'
    })
    
    -- Команда для перезавантаження плагіна
    vim.api.nvim_create_user_command('NvimAgentReload', function()
        -- Очищаємо кеш всіх модулів плагіна
        for name, _ in pairs(package.loaded) do
            if name:match('^nvim%-agent') then
                package.loaded[name] = nil
            end
        end
        
        -- Перезавантажуємо плагін
        vim.notify("🔄 Перезавантажую nvim-agent...", vim.log.levels.INFO)
        require('nvim-agent').setup(config.get())
        vim.notify("✅ nvim-agent перезавантажено!", vim.log.levels.INFO)
    end, {
        desc = 'Перезавантажити плагін (корисно при розробці)'
    })
    
    -- Налаштовуємо хоткеї
    M.setup_keymaps()
end

-- Налаштування гарячих клавіш
function M.setup_keymaps()
    local cfg = config.get()
    local keymaps = cfg.keymaps
    
    -- Глобальні хоткеї
    if keymaps.toggle_chat then
        vim.keymap.set('n', keymaps.toggle_chat, chat.toggle, {
            desc = 'Відкрити/закрити чат nvim-agent'
        })
    end
    
    if keymaps.explain_code then
        vim.keymap.set('v', keymaps.explain_code, M.explain_code, {
            desc = 'Пояснити вибраний код'
        })
    end
    
    if keymaps.generate_code then
        vim.keymap.set('n', keymaps.generate_code, function()
            local prompt = vim.fn.input("Опишіть код який потрібно згенерувати: ")
            if prompt ~= "" then
                M.generate_code(prompt)
            end
        end, {
            desc = 'Згенерувати код'
        })
    end
    
    if keymaps.refactor_code then
        vim.keymap.set('v', keymaps.refactor_code, M.refactor_code, {
            desc = 'Покращити вибраний код'
        })
    end
    
    if keymaps.generate_tests then
        vim.keymap.set('v', keymaps.generate_tests, M.generate_tests, {
            desc = 'Створити тести'
        })
    end
    
    if keymaps.generate_docs then
        vim.keymap.set('v', keymaps.generate_docs, M.generate_docs, {
            desc = 'Створити документацію'
        })
    end
    
    if keymaps.cycle_mode then
        vim.keymap.set('n', keymaps.cycle_mode, function()
            chat.cycle_mode()
        end, {
            desc = 'Переключити режим (Ask/Edit/Agent)'
        })
    end
    
    if keymaps.sessions then
        vim.keymap.set('n', keymaps.sessions, function()
            local session_picker = require('nvim-agent.ui.session_picker')
            session_picker.show_picker(function(session_id)
                local sessions = require('nvim-agent.chat_sessions')
                sessions.switch_session(session_id)
                chat.close()
                chat.open()
            end)
        end, {
            desc = 'Список чатів (сесій)'
        })
    end
end

-- Пояснення коду
function M.explain_code()
    local selected_text = utils.get_visual_selection()
    
    if not selected_text then
        vim.notify("Виберіть код для пояснення", vim.log.levels.WARN)
        return
    end
    
    local cfg = config.get()
    local prompt = cfg.prompts.explain .. "\n\n" .. selected_text
    
    -- Отримуємо контекст файлу
    local context = {
        code = selected_text,
        filetype = vim.bo.filetype
    }
    
    M.send_request_with_popup(prompt, context, "Пояснення коду")
end

-- Генерація коду
function M.generate_code(description)
    if not description or description == "" then
        description = vim.fn.input("Опишіть код який потрібно згенерувати: ")
        if description == "" then
            return
        end
    end
    
    local cfg = config.get()
    local prompt = cfg.prompts.generate .. "\n\n" .. description
    
    local context = {
        filetype = vim.bo.filetype
    }
    
    M.send_request_with_popup(prompt, context, "Генерація коду", true)
end

-- Рефакторинг коду
function M.refactor_code()
    local selected_text = utils.get_visual_selection()
    
    if not selected_text then
        vim.notify("Виберіть код для рефакторингу", vim.log.levels.WARN)
        return
    end
    
    local cfg = config.get()
    local prompt = cfg.prompts.refactor .. "\n\n" .. selected_text
    
    local context = {
        code = selected_text,
        filetype = vim.bo.filetype
    }
    
    M.send_request_with_popup(prompt, context, "Рефакторинг коду", true)
end

-- Генерація тестів
function M.generate_tests()
    local selected_text = utils.get_visual_selection()
    
    if not selected_text then
        -- Якщо нічого не вибрано, берем всю функцію під курсором
        selected_text = M.get_current_function()
        if not selected_text then
            vim.notify("Виберіть код або встановіть курсор на функцію", vim.log.levels.WARN)
            return
        end
    end
    
    local cfg = config.get()
    local prompt = cfg.prompts.test .. "\n\n" .. selected_text
    
    local context = {
        code = selected_text,
        filetype = vim.bo.filetype
    }
    
    M.send_request_with_popup(prompt, context, "Генерація тестів", true)
end

-- Генерація документації
function M.generate_docs()
    local selected_text = utils.get_visual_selection()
    
    if not selected_text then
        selected_text = M.get_current_function()
        if not selected_text then
            vim.notify("Виберіть код або встановіть курсор на функцію", vim.log.levels.WARN)
            return
        end
    end
    
    local cfg = config.get()
    local prompt = cfg.prompts.document .. "\n\n" .. selected_text
    
    local context = {
        code = selected_text,
        filetype = vim.bo.filetype
    }
    
    M.send_request_with_popup(prompt, context, "Генерація документації", false)
end

-- Код-рев'ю
function M.review_code()
    local selected_text = utils.get_visual_selection()
    
    if not selected_text then
        -- Берем весь файл якщо нічого не вибрано
        local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
        selected_text = table.concat(lines, "\n")
    end
    
    local cfg = config.get()
    local prompt = cfg.prompts.review .. "\n\n" .. selected_text
    
    local context = {
        code = selected_text,
        filetype = vim.bo.filetype
    }
    
    M.send_request_with_popup(prompt, context, "Код-рев'ю")
end

-- Виправлення коду
function M.fix_code()
    local selected_text = utils.get_visual_selection()
    
    if not selected_text then
        vim.notify("Виберіть код з помилками для виправлення", vim.log.levels.WARN)
        return
    end
    
    local cfg = config.get()
    local prompt = cfg.prompts.fix .. "\n\n" .. selected_text
    
    local context = {
        code = selected_text,
        filetype = vim.bo.filetype
    }
    
    M.send_request_with_popup(prompt, context, "Виправлення коду", true)
end

-- Надсилання запиту з показом результату в popup
function M.send_request_with_popup(prompt, context, title, allow_insert)
    allow_insert = allow_insert or false
    
    -- Показуємо індикатор завантаження
    vim.notify("🔄 " .. title .. "...", vim.log.levels.INFO)
    
    api.quick_chat(prompt, context, function(err, response)
        if err then
            utils.log("error", "Помилка запиту", { error = err })
            vim.notify("❌ Помилка: " .. err, vim.log.levels.ERROR)
            return
        end
        
        if response then
            M.show_response_popup(response, title, allow_insert)
        end
    end)
end

-- Показ відповіді в popup вікні
function M.show_response_popup(content, title, allow_insert)
    local cfg = config.get()
    
    -- Створюємо popup вікно
    local popup = utils.create_floating_window(content, {
        title = title or "AI Відповідь",
        border = cfg.ui.popup.border,
        modifiable = false,
        filetype = "markdown"
    })
    
    -- Додаємо хоткеї для popup
    local buf = popup.buffer
    
    -- Закриття на Escape
    vim.api.nvim_buf_set_keymap(buf, 'n', '<Esc>', '<cmd>close<CR>', {
        noremap = true, silent = true
    })
    
    -- Копіювання в clipboard
    vim.api.nvim_buf_set_keymap(buf, 'n', 'yy', function()
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        local text = table.concat(lines, "\n")
        vim.fn.setreg('+', text)
        vim.notify("Скопійовано в буфер обміну", vim.log.levels.INFO)
    end, {
        noremap = true, silent = true, callback = true
    })
    
    -- Вставка коду якщо дозволено
    if allow_insert then
        vim.api.nvim_buf_set_keymap(buf, 'n', '<CR>', function()
            -- Витягуємо код блоки з відповіді
            local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
            local text = table.concat(lines, "\n")
            local code_blocks = utils.extract_code_blocks(text)
            
            if #code_blocks > 0 then
                -- Якщо є кодові блоки, вставляємо перший
                local code_to_insert = code_blocks[1].code
                popup.close()
                
                -- Повертаємось до оригінального буфера та вставляємо код
                vim.schedule(function()
                    utils.insert_text(code_to_insert, true)  -- заміняємо вибрану область
                    vim.notify("Код вставлено", vim.log.levels.INFO)
                end)
            else
                vim.notify("Код блоки не знайдено у відповіді", vim.log.levels.WARN)
            end
        end, {
            noremap = true, silent = true, callback = true
        })
        
        -- Додаємо підказку
        local help_text = "Натисніть <Enter> для вставки коду, 'yy' для копіювання, <Esc> для закриття"
        vim.api.nvim_echo({{help_text, "Comment"}}, false, {})
    end
end

-- Отримання поточної функції під курсором
function M.get_current_function()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local current_line = cursor[1]
    
    -- Проста евристика для знаходження функції
    -- Шукаємо назад до початку функції
    local function_start = current_line
    local function_end = current_line
    
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local filetype = vim.bo.filetype
    
    -- Паттерни для різних мов програмування
    local function_patterns = {
        lua = { "^%s*function", "^%s*local%s+function", "^%s*M%.%w+%s*=" },
        python = { "^%s*def%s", "^%s*async%s+def%s", "^%s*class%s" },
        javascript = { "^%s*function", "^%s*const%s+%w+%s*=", "^%s*%w+%s*:%s*function" },
        typescript = { "^%s*function", "^%s*const%s+%w+%s*=", "^%s*%w+%s*:%s*function" },
        go = { "^%s*func%s" },
        rust = { "^%s*fn%s", "^%s*pub%s+fn%s" },
        c = { "^%w+.*{$", "^%s*%w+%s+%w+%s*%(.*%)%s*{" },
        cpp = { "^%w+.*{$", "^%s*%w+%s+%w+%s*%(.*%)%s*{" }
    }
    
    local patterns = function_patterns[filetype] or {}
    
    if #patterns == 0 then
        return nil
    end
    
    -- Шукаємо початок функції
    for i = current_line, 1, -1 do
        local line = lines[i]
        if line then
            for _, pattern in ipairs(patterns) do
                if line:match(pattern) then
                    function_start = i
                    break
                end
            end
        end
    end
    
    -- Шукаємо кінець функції (проста евристика - знаходимо відповідний end або })
    local brace_count = 0
    local found_opening = false
    
    for i = function_start, #lines do
        local line = lines[i]
        if line then
            -- Рахуємо фігурні дужки для мов типу C/JS
            for char in line:gmatch(".") do
                if char == "{" then
                    brace_count = brace_count + 1
                    found_opening = true
                elseif char == "}" then
                    brace_count = brace_count - 1
                    if found_opening and brace_count == 0 then
                        function_end = i
                        break
                    end
                end
            end
            
            -- Для Lua шукаємо end
            if filetype == "lua" and line:match("^%s*end%s*$") then
                function_end = i
                break
            end
            
            -- Для Python шукаємо зменшення відступу
            if filetype == "python" and i > function_start then
                local current_indent = line:match("^%s*")
                local start_indent = lines[function_start]:match("^%s*")
                if #current_indent <= #start_indent and line:match("%S") then
                    function_end = i - 1
                    break
                end
            end
        end
        
        if found_opening and brace_count == 0 then
            break
        end
    end
    
    -- Повертаємо текст функції
    local function_lines = {}
    for i = function_start, function_end do
        if lines[i] then
            table.insert(function_lines, lines[i])
        end
    end
    
    return table.concat(function_lines, "\n")
end

-- Керування змінами (Review Mode)
function M.review_changes()
    local change_manager = require('nvim-agent.change_manager')
    change_manager.show_changes_list()
end

function M.accept_all_changes()
    local change_manager = require('nvim-agent.change_manager')
    change_manager.accept_all_changes()
end

function M.discard_all_changes()
    local change_manager = require('nvim-agent.change_manager')
    change_manager.discard_all_changes()
end

function M.toggle_review_mode(enabled)
    local mcp = require('nvim-agent.mcp')
    
    if enabled == nil then
        -- Toggle
        mcp.review_mode = not mcp.review_mode
    else
        mcp.review_mode = enabled
    end
    
    local status = mcp.review_mode and "увімкнено" or "вимкнено"
    local icon = mcp.review_mode and "👁️" or "⚡"
    
    vim.notify(icon .. " Режим перегляду змін " .. status, vim.log.levels.INFO)
end

function M.show_changes_stats()
    local change_manager = require('nvim-agent.change_manager')
    local stats = change_manager.get_changes_stats()
    
    local msg = string.format(
        "📊 Статистика змін:\n\n" ..
        "Всього: %d\n" ..
        "✅ Застосовано: %d\n" ..
        "⏳ Очікують: %d\n\n" ..
        "За типом:\n",
        stats.total, stats.applied, stats.pending
    )
    
    for type_name, count in pairs(stats.by_type) do
        msg = msg .. string.format("  • %s: %d\n", type_name, count)
    end
    
    vim.notify(msg, vim.log.levels.INFO)
end

return M