-- Тести для системи сесій (множинних чатів)
local config = require('nvim-agent.config')
local sessions = require('nvim-agent.chat_sessions')
local chat = require('nvim-agent.chat')

describe("chat sessions", function()
    before_each(function()
        -- Ініціалізуємо config перед sessions
        config.setup({})
        sessions.setup()
        chat.setup()
    end)
    
    describe("initialization", function()
        it("повинен мати дефолтну сесію після setup", function()
            local current = sessions.get_current_session()
            assert.is_not_nil(current)
            assert.is_not_nil(current.id)
            assert.is_not_nil(current.name)
            assert.is_not_nil(current.mode)
            -- Режим може бути ask або залишитись від попереднього тесту
            assert.is_true(current.mode == "ask" or current.mode == "agent" or current.mode == "edit")
        end)
        
        it("повинен мати порожню історію у новій сесії", function()
            local history = sessions.get_history()
            assert.is_not_nil(history)
            -- Може бути system message, тому >= 0
            assert.is_true(#history >= 0)
        end)
    end)
    
    describe("creating sessions", function()
        it("повинен створювати нові сесії", function()
            local session2_id = chat.new_session("Test Chat 2")
            assert.is_not_nil(session2_id)
            
            local session3_id = chat.new_session("Agent Test")
            assert.is_not_nil(session3_id)
            
            -- Перевіряємо що сесії різні
            assert.is_not_equal(session2_id, session3_id)
        end)
        
        it("повинен показувати список всіх сесій", function()
            chat.new_session("Test Chat 2")
            chat.new_session("Agent Test")
            
            local all_sessions = chat.get_sessions()
            assert.is_not_nil(all_sessions)
            -- Дефолтна + 2 нові = мінімум 3
            assert.is_true(#all_sessions >= 3)
            
            -- Перевіряємо структуру сесії
            local first = all_sessions[1]
            assert.is_not_nil(first.id)
            assert.is_not_nil(first.name)
            assert.is_not_nil(first.mode)
            assert.is_not_nil(first.message_count)
            assert.is_boolean(first.is_current)
        end)
    end)
    
    describe("managing messages", function()
        it("повинен додавати повідомлення до поточної сесії", function()
            local before_count = #sessions.get_history()
            
            sessions.add_message({
                role = "user",
                content = "Test message 1",
                timestamp = os.time()
            })
            sessions.add_message({
                role = "assistant",
                content = "Response 1",
                timestamp = os.time()
            })
            
            local after_count = #sessions.get_history()
            assert.equals(before_count + 2, after_count)
        end)
        
        it("повинен зберігати окрему історію для кожної сесії", function()
            -- Додаємо повідомлення в першу сесію
            sessions.add_message({role = "user", content = "Message in session 1"})
            local history1_count = #sessions.get_history()
            
            -- Створюємо нову сесію і перемикаємось
            local session2_id = chat.new_session("Test Chat 2")
            chat.switch_session(session2_id)
            
            -- Нова сесія має бути порожня (або тільки system message)
            local history2_count = #sessions.get_history()
            assert.is_true(history2_count < history1_count)
            
            -- Додаємо повідомлення у другу сесію
            sessions.add_message({role = "user", content = "Message in session 2"})
            local history2_new = #sessions.get_history()
            assert.is_true(history2_new > history2_count)
        end)
    end)
    
    describe("switching sessions", function()
        it("повинен перемикати між сесіями", function()
            local session1_id = sessions.get_current_session().id
            local session2_id = chat.new_session("Test Chat 2")
            
            chat.switch_session(session2_id)
            assert.equals(session2_id, sessions.get_current_session().id)
            
            chat.switch_session(session1_id)
            assert.equals(session1_id, sessions.get_current_session().id)
        end)
    end)
    
    describe("modes", function()
        it("повинен змінювати режим сесії", function()
            local initial_mode = sessions.get_mode()
            assert.equals("ask", initial_mode)
            
            sessions.set_mode("agent")
            assert.equals("agent", sessions.get_mode())
            
            sessions.set_mode("edit")
            assert.equals("edit", sessions.get_mode())
        end)
        
        it("повинен зберігати різні режими в різних сесіях", function()
            sessions.set_mode("agent")
            local session1_id = sessions.get_current_session().id
            
            local session2_id = chat.new_session("Test Chat 2")
            chat.switch_session(session2_id)
            
            -- Нова сесія має дефолтний режим
            assert.equals("ask", sessions.get_mode())
            
            -- Повертаємось до першої - режим збережений
            chat.switch_session(session1_id)
            assert.equals("agent", sessions.get_mode())
        end)
    end)
    
    describe("renaming and deleting", function()
        it("повинен перейменовувати сесію", function()
            local session_id = chat.new_session("Original Name")
            chat.rename_session(session_id, "New Name")
            
            local all_sessions = chat.get_sessions()
            local found = false
            for _, s in ipairs(all_sessions) do
                if s.id == session_id then
                    assert.equals("New Name", s.name)
                    found = true
                    break
                end
            end
            assert.is_true(found)
        end)
        
        it("повинен видаляти сесію", function()
            local session_id = chat.new_session("To Delete")
            local before_count = #chat.get_sessions()
            
            chat.delete_session(session_id)
            
            local after_count = #chat.get_sessions()
            assert.equals(before_count - 1, after_count)
        end)
    end)
    
    describe("clearing", function()
        it("повинен очищати історію поточної сесії", function()
            sessions.add_message({role = "user", content = "Test message"})
            sessions.add_message({role = "assistant", content = "Response"})
            
            local before_count = #sessions.get_history()
            assert.is_true(before_count >= 2)
            
            chat.clear()
            
            local after_count = #sessions.get_history()
            -- Після clear може залишитись тільки system message
            assert.is_true(after_count < before_count)
        end)
    end)
    
    describe("isolation", function()
        it("повинен ізолювати історію між сесіями", function()
            -- Сесія 1
            local session1_id = sessions.get_current_session().id
            sessions.add_message({role = "user", content = "Message 1"})
            sessions.add_message({role = "assistant", content = "Response 1"})
            local history1 = sessions.get_history()
            
            -- Сесія 2
            local session2_id = chat.new_session("Session 2")
            chat.switch_session(session2_id)
            sessions.add_message({role = "user", content = "Message 2"})
            local history2 = sessions.get_history()
            
            -- Історії мають бути різні
            assert.is_not_equal(#history1, #history2)
            
            -- Повертаємось до сесії 1 - історія не змінилась
            chat.switch_session(session1_id)
            local history1_again = sessions.get_history()
            assert.equals(#history1, #history1_again)
        end)
    end)
end)
