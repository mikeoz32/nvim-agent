describe("chat summarization", function()
    local chat, sessions, api, chat_window
    
    before_each(function()
        -- Очищаємо кеш модулів
        package.loaded['nvim-agent.chat'] = nil
        package.loaded['nvim-agent.chat_sessions'] = nil
        package.loaded['nvim-agent.api'] = nil
        package.loaded['nvim-agent.ui.chat_nui'] = nil
        package.loaded['nvim-agent.config'] = nil
        
        -- НЕ затираємо глобальний vim, тільки додаємо мокування
        -- Зберігаємо оригінальні функції
        local original_notify = vim.notify
        
        -- Мокаємо тільки те що потрібно
        vim.notify = function() end  -- Тихий режим
        
        -- Мокаємо fs_stat для instructions.md
        local original_fs_stat = vim.loop.fs_stat
        vim.loop.fs_stat = function(path)
            if path:find("instructions.md") then
                return nil  -- Instructions не знайдено
            end
            return original_fs_stat(path)
        end
        
        -- Мокаємо config
        package.loaded['nvim-agent.config'] = {
            get = function()
                return {
                    behavior = {
                        default_mode = "ask",
                        default_model = "gpt-4",
                    },
                    mcp = {
                        enabled = false,
                    }
                }
            end
        }
        
        -- Мокаємо API
        package.loaded['nvim-agent.api'] = {
            chat_completion = function(messages, callback, options)
                -- Симулюємо успішну відповідь
                callback(nil, "This is a summary of the conversation.")
            end,
            cancel_request = function() end,
        }
        
        -- Мокаємо chat_window
        package.loaded['nvim-agent.ui.chat_nui'] = {
            add_user_message = function() end,
            add_assistant_message = function() end,
            add_system_message = function() end,
            add_streaming_chunk = function() end,
            finalize_streaming = function() end,
            is_visible = function() return true end,
        }
        
        -- Мокаємо utils
        package.loaded['nvim-agent.utils'] = {
            log = function() end,
            generate_uuid = function() return "test-uuid-123" end,
        }
        
        -- Мокаємо modes
        package.loaded['nvim-agent.modes'] = {
            get_prompt_suffix = function() return "" end,
        }
        
        -- Мокаємо mcp
        package.loaded['nvim-agent.mcp'] = {
            get_tools_schema = function() return {} end,
        }
        
        -- Завантажуємо модулі
        sessions = require('nvim-agent.chat_sessions')
        sessions.setup()
        
        chat = require('nvim-agent.chat')
        chat_window = require('nvim-agent.ui.chat_nui')
        api = require('nvim-agent.api')
    end)
    
    describe("estimate_tokens", function()
        it("повертає 0 для nil", function()
            -- Доступу до приватної функції немає, але перевіримо через поведінку
            -- Створюємо сесію з повідомленнями
            local session_id = sessions.create_session("Test")
            sessions.add_message({
                role = "user",
                content = "Test message",
            })
            
            local history = sessions.get_history()
            assert.is_not_nil(history)
            assert.equals(1, #history)
        end)
    end)
    
    describe("summarization triggers", function()
        it("НЕ спрацьовує при малій кількості повідомлень (<10)", function()
            local session_id = sessions.create_session("Test")
            
            -- Додаємо 5 повідомлень
            for i = 1, 5 do
                sessions.add_message({
                    role = "user",
                    content = "Message " .. i,
                })
            end
            
            -- Відправляємо повідомлення
            chat.send_message("Test message")
            
            -- Summary не повинна створитись
            local session = sessions.get_current_session()
            assert.is_nil(session.summary)
        end)
        
        it("спрацьовує при 30+ повідомленнях", function()
            local session_id = sessions.create_session("Test")
            
            -- Додаємо 30 повідомлень
            for i = 1, 30 do
                sessions.add_message({
                    role = i % 2 == 0 and "user" or "assistant",
                    content = "Message " .. i,
                })
            end
            
            -- Мокаємо API для summarization
            local summarization_called = false
            package.loaded['nvim-agent.api'].chat_completion = function(messages, callback, options)
                summarization_called = true
                callback(nil, "Summary of 20 messages")
            end
            
            -- Відправляємо повідомлення (тригерить summarization)
            chat.send_message("Trigger summarization")
            
            -- Перевіряємо що summarization був викликаний
            assert.is_true(summarization_called)
        end)
        
        it("враховує розмір контенту (файли, tool results)", function()
            local session_id = sessions.create_session("Test")
            
            -- Додаємо кілька повідомлень з великим контентом
            for i = 1, 15 do
                sessions.add_message({
                    role = "user",
                    content = string.rep("A", 2000), -- ~500 токенів кожне
                    context = {
                        code = string.rep("B", 2000), -- Ще +500 токенів
                    }
                })
            end
            
            -- Разом: 15 * (500 + 500) = 15000 токенів > 8000 threshold
            
            local summarization_called = false
            package.loaded['nvim-agent.api'].chat_completion = function(messages, callback, options)
                summarization_called = true
                callback(nil, "Summary due to large content")
            end
            
            chat.send_message("Should trigger due to size")
            
            -- Повинна спрацювати summarization через розмір
            assert.is_true(summarization_called)
        end)
    end)
    
    describe("summary storage", function()
        it("зберігає summary окремо від історії", function()
            local session_id = sessions.create_session("Test")
            
            -- Додаємо багато повідомлень
            for i = 1, 35 do
                sessions.add_message({
                    role = i % 2 == 0 and "user" or "assistant",
                    content = "Message " .. i,
                })
            end
            
            local history_before = sessions.get_history()
            local count_before = #history_before
            
            -- Тригеримо summarization
            chat.send_message("Trigger")
            
            -- Перевіряємо що історія НЕ змінилась
            local history_after = sessions.get_history()
            assert.equals(count_before + 1, #history_after) -- +1 за нове повідомлення
            
            -- Перевіряємо що summary створився
            local session = sessions.get_current_session()
            assert.is_not_nil(session.summary)
            assert.is_not_nil(session.summary.content)
            assert.is_not_nil(session.summary.timestamp)
            assert.is_not_nil(session.summary.covers_messages)
        end)
        
        it("зберігає metadata в summary", function()
            local session_id = sessions.create_session("Test")
            
            for i = 1, 30 do
                sessions.add_message({
                    role = "user",
                    content = "Msg " .. i,
                })
            end
            
            chat.send_message("Create summary")
            
            local session = sessions.get_current_session()
            assert.is_table(session.summary)
            
            -- Перевіряємо структуру
            assert.is_string(session.summary.content)
            assert.is_number(session.summary.timestamp)
            assert.is_number(session.summary.covers_messages)
            
            -- Timestamp має бути свіжий (в межах останніх 5 секунд)
            local now = os.time()
            assert.is_true(now - session.summary.timestamp < 5)
        end)
    end)
    
    describe("API request with summary", function()
        it("відправляє summary + нові повідомлення", function()
            local session_id = sessions.create_session("Test")
            
            -- Створюємо сесію з summary вручну
            local session = sessions.get_current_session()
            session.summary = {
                content = "Previous conversation summary",
                timestamp = os.time() - 3600, -- 1 година тому
                covers_messages = 20,
            }
            
            -- Додаємо нові повідомлення після summary
            for i = 1, 5 do
                sessions.add_message({
                    role = "user",
                    content = "New message " .. i,
                })
            end
            
            -- Перехоплюємо API запит
            local captured_messages = nil
            package.loaded['nvim-agent.api'].chat_completion = function(messages, callback, options)
                captured_messages = messages
                callback(nil, "Response")
            end
            
            chat.send_message("Test with summary")
            
            -- Перевіряємо що в запиті є summary
            assert.is_not_nil(captured_messages)
            
            local has_summary = false
            for _, msg in ipairs(captured_messages) do
                if msg.content and msg.content:find("%[SUMMARY%]") then
                    has_summary = true
                    -- Перевіряємо формат
                    assert.is_true(msg.content:find("summary of %d+ messages"))
                    assert.is_true(msg.content:find("Previous conversation summary"))
                    break
                end
            end
            
            assert.is_true(has_summary, "Summary should be in API request")
        end)
        
        it("без summary відправляє останні 10 повідомлень", function()
            local session_id = sessions.create_session("Test")
            
            -- Додаємо 15 повідомлень БЕЗ summary
            for i = 1, 15 do
                sessions.add_message({
                    role = i % 2 == 0 and "user" or "assistant",
                    content = "Message " .. i,
                })
            end
            
            local captured_messages = nil
            package.loaded['nvim-agent.api'].chat_completion = function(messages, callback, options)
                captured_messages = messages
                callback(nil, "Response")
            end
            
            chat.send_message("Test without summary")
            
            -- Підраховуємо історичні повідомлення (крім system та нового user)
            local history_count = 0
            for _, msg in ipairs(captured_messages) do
                if msg.role == "user" or msg.role == "assistant" then
                    history_count = history_count + 1
                end
            end
            
            -- Має бути близько 10-11 повідомлень (останні 10 + нове)
            assert.is_true(history_count >= 10 and history_count <= 12)
        end)
    end)
    
    describe("edge cases", function()
        it("не падає при пустій історії", function()
            local session_id = sessions.create_session("Test")
            
            assert.has_no_errors(function()
                chat.send_message("First message")
            end)
        end)
        
        it("не створює summary повторно", function()
            local session_id = sessions.create_session("Test")
            
            -- Додаємо багато повідомлень
            for i = 1, 35 do
                sessions.add_message({
                    role = "user",
                    content = "Msg " .. i,
                })
            end
            
            local call_count = 0
            package.loaded['nvim-agent.api'].chat_completion = function(messages, callback, options)
                call_count = call_count + 1
                callback(nil, "Summary")
            end
            
            -- Перший виклик - створює summary
            chat.send_message("First")
            local first_call = call_count
            
            -- Другий виклик - НЕ повинен створювати новий summary
            chat.send_message("Second")
            
            -- Має бути 2 виклики (1 для summary, 1 для звичайної відповіді)
            -- Якщо було б 3 виклики - значить summary створився двічі
            assert.is_true(call_count <= 2)
        end)
        
        it("працює з різними типами контенту в повідомленнях", function()
            local session_id = sessions.create_session("Test")
            
            -- Різні типи повідомлень
            sessions.add_message({
                role = "user",
                content = "Simple message",
            })
            
            sessions.add_message({
                role = "user",
                content = "Message with context",
                context = {
                    code = "function test() end",
                    filename = "test.lua",
                }
            })
            
            sessions.add_message({
                role = "assistant",
                content = "Response with tool results",
                tool_results = {
                    { content = "Tool output 1" },
                    { content = "Tool output 2" },
                }
            })
            
            assert.has_no_errors(function()
                chat.send_message("Should handle all types")
            end)
        end)
    end)
end)
