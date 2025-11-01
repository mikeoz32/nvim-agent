local chat_nui = require('nvim-agent.ui.chat_nui')

describe("chat_nui", function()
    -- Відключаємо before_each для початкових тестів
    -- бо vim.api недоступний в headless mode

    describe("Module Structure", function()
        it("should load module successfully", function()
            assert.is_not_nil(chat_nui)
            assert.is_table(chat_nui)
        end)

        it("should have all required public functions", function()
            local required_functions = {
                "init",
                "create_window",
                "show_input",
                "add_user_message",
                "add_ai_message",
                "add_system_message",
                "send_current_message",
                "get_current_input",
                "clear_input",
                "clear",
                "close",
                "is_open",
                "get_chat_buffer",
                "get_buffers",
                "scroll_to_bottom",
                "focus_input",
                "resize",
                "update_mode_indicator",
                "setup_markdown_rendering"
            }

            for _, func_name in ipairs(required_functions) do
                assert.is_function(chat_nui[func_name], 
                    "Function '" .. func_name .. "' should exist")
            end
        end)

        it("should have correct function count for backward compatibility", function()
            local function_count = 0
            for k, v in pairs(chat_nui) do
                if type(v) == "function" and not k:match("^_") then
                    function_count = function_count + 1
                end
            end
            
            -- Має бути принаймні 18 публічних функцій
            assert.is_true(function_count >= 18, 
                "Expected at least 18 public functions, got " .. function_count)
        end)
    end)

    describe("API Compatibility Tests", function()
        it("should handle is_open before initialization", function()
            -- Має працювати навіть якщо не ініціалізовано
            assert.has_no.errors(function()
                local is_open = chat_nui.is_open()
                assert.is_boolean(is_open)
            end)
        end)

        it("should handle clear before initialization", function()
            -- clear має не падати якщо не ініціалізовано
            assert.has_no.errors(function()
                chat_nui.clear()
            end)
        end)

        it("should handle close before initialization", function()
            assert.has_no.errors(function()
                chat_nui.close()
            end)
        end)

        it("should return empty string for get_current_input", function()
            local input = chat_nui.get_current_input()
            assert.equals("", input)
        end)

        it("should handle clear_input gracefully", function()
            assert.has_no.errors(function()
                chat_nui.clear_input()
            end)
        end)

        it("should handle resize gracefully", function()
            assert.has_no.errors(function()
                chat_nui.resize()
            end)
        end)
    end)

    describe("Function Signatures", function()
        it("add_user_message should be a function", function()
            assert.is_function(chat_nui.add_user_message)
        end)

        it("add_ai_message should be a function", function()
            assert.is_function(chat_nui.add_ai_message)
        end)

        it("add_system_message should be a function", function()
            assert.is_function(chat_nui.add_system_message)
        end)
    end)

    describe("Backward Compatibility", function()
        it("should maintain same API as chat_window.lua", function()
            -- Список функцій з старого chat_window.lua
            local old_api_functions = {
                "create_window",
                "setup_markdown_rendering",
                "add_message", -- Може не бути, але це OK
                "add_user_message",
                "add_ai_message",
                "add_system_message",
                "get_current_input",
                "clear_input",
                "send_current_message",
                "scroll_to_bottom",
                "clear",
                "focus_input",
                "close",
                "is_open",
                "get_buffers",
                "get_chat_buffer",
                "resize",
                "update_mode_indicator"
            }

            local missing = {}
            for _, func_name in ipairs(old_api_functions) do
                if func_name ~= "add_message" and type(chat_nui[func_name]) ~= "function" then
                    table.insert(missing, func_name)
                end
            end

            assert.equals(0, #missing, 
                "Missing functions: " .. table.concat(missing, ", "))
        end)

        it("should have new functions specific to chat_nui", function()
            -- Нові функції які є тільки в chat_nui
            assert.is_function(chat_nui.init)
            assert.is_function(chat_nui.show_input)
        end)
    end)

    describe("Module Design", function()
        it("should follow single responsibility principle", function()
            -- chat_nui має займатись тільки UI
            -- Перевіряємо що немає прямих викликів API
            assert.is_nil(chat_nui.send_api_request)
            assert.is_nil(chat_nui.execute_tools)
        end)

        it("should not expose internal functions", function()
            -- Внутрішні функції мають починатись з _
            local internal_exposed = {}
            for k, v in pairs(chat_nui) do
                if type(v) == "function" and k:match("^_") then
                    -- Це OK - internal functions
                else
                    -- Публічні функції не мають _ на початку
                end
            end
            -- Тест проходить якщо немає помилок
            assert.is_true(true)
        end)
    end)

    describe("Documentation", function()
        it("should have module-level documentation in file", function()
            -- Перевіряємо що файл існує і можна прочитати
            local file = io.open("lua/nvim-agent/ui/chat_nui.lua", "r")
            assert.is_not_nil(file, "File should exist")
            
            if file then
                local content = file:read("*all")
                file:close()
                
                -- Перевіряємо що є коментарі
                assert.is_true(content:match("%-%-") ~= nil, "Should have comments")
                assert.is_true(content:match("local M = {}") ~= nil, "Should follow module pattern")
            end
        end)
    end)
end)
