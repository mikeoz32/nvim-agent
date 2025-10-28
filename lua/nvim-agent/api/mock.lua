-- Mock API провайдер для тестування без реальних API ключів
local M = {}

function M.chat(messages, options, callback)
    -- Симулюємо затримку API
    vim.defer_fn(function()
        local mock_response = {
            content = "🤖 Це mock відповідь від AI.\n\n" ..
                     "API провайдер не налаштований або використовується mock режим.\n\n" ..
                     "Для реального використання налаштуйте OpenAI, Anthropic або Local провайдер.\n\n" ..
                     "**Приклад використання:**\n" ..
                     "```lua\n" ..
                     "require('nvim-agent').setup({\n" ..
                     "    api = {\n" ..
                     "        provider = 'openai',\n" ..
                     "        api_key = os.getenv('OPENAI_API_KEY'),\n" ..
                     "        model = 'gpt-4',\n" ..
                     "    }\n" ..
                     "})\n" ..
                     "```",
            tool_calls = nil
        }
        callback(mock_response, nil)
    end, 500)
end

function M.supports_tools()
    return false
end

function M.get_model_name()
    return "mock-model-v1"
end

return M
