-- Тести для Copilot API
local copilot = require('nvim-agent.api.copilot')

describe("copilot api", function()
    describe("token management", function()
        it("повинен отримувати OAuth token", function()
            local config = require('nvim-agent.config')
            local token = config.get_github_copilot_token()
            
            -- Може бути nil якщо Copilot не налаштований
            if token then
                assert.is_string(token)
                assert.is_true(#token == 40 or #token == 36)
                assert.is_true(token:match("^gh[uop]_") ~= nil)
            end
        end)
    end)
    
    describe("supports_tools", function()
        it("повинен підтримувати tools", function()
            assert.is_true(copilot.supports_tools())
        end)
    end)
    
    describe("get_model_name", function()
        it("повинен повертати ім'я моделі", function()
            local model = copilot.get_model_name()
            assert.is_string(model)
            assert.is_true(#model > 0)
        end)
    end)
    
    describe("chat completion", function()
        -- Цей тест вимагає реального Copilot token
        pending("повинен виконувати chat completion з tools", function()
            local messages = {
                {role = "system", content = "Ти AI асистент"},
                {role = "user", content = "які файли в проекті?"}
            }
            
            local mcp = require('nvim-agent.mcp')
            local tools = mcp.get_tools_for_openai()
            
            local callback_called = false
            local result_err = nil
            local result_response = nil
            local result_tool_calls = nil
            
            copilot.chat(messages, {tools = tools}, function(err, response, tool_calls)
                callback_called = true
                result_err = err
                result_response = response
                result_tool_calls = tool_calls
            end)
            
            -- Чекаємо виконання
            vim.wait(5000, function()
                return callback_called
            end)
            
            assert.is_true(callback_called)
            assert.is_nil(result_err)
            assert.is_not_nil(result_tool_calls)
            assert.is_true(#result_tool_calls > 0)
            
            local tool_call = result_tool_calls[1]
            assert.equals("get_project_structure", tool_call["function"].name)
        end)
    end)
end)
