-- Базовий OpenAI API провайдер
local M = {}

local curl = require('plenary.curl')

function M.chat(messages, options, callback)
    local config = require('nvim-agent.config').get()
    local api_key = config.api.api_key
    local model = options.model or config.api.model or "gpt-4"
    
    if not api_key then
        callback(nil, "OpenAI API key not configured")
        return
    end
    
    local body = {
        model = model,
        messages = messages,
        stream = false,
        temperature = options.temperature or 0.7,
        max_tokens = options.max_tokens or 4096,
    }
    
    -- Додати tools якщо є
    if options.tools and #options.tools > 0 then
        body.tools = options.tools
    end
    
    curl.post("https://api.openai.com/v1/chat/completions", {
        headers = {
            ["Content-Type"] = "application/json",
            ["Authorization"] = "Bearer " .. api_key,
        },
        body = vim.fn.json_encode(body),
        callback = vim.schedule_wrap(function(response)
            if response.status ~= 200 then
                callback(nil, "OpenAI API error: " .. (response.body or "unknown error"))
                return
            end
            
            local ok, data = pcall(vim.fn.json_decode, response.body)
            if not ok then
                callback(nil, "Failed to parse OpenAI response")
                return
            end
            
            if not data.choices or #data.choices == 0 then
                callback(nil, "No response from OpenAI")
                return
            end
            
            local message = data.choices[1].message
            local result = {
                content = message.content,
                tool_calls = message.tool_calls,
            }
            
            callback(result, nil)
        end)
    })
end

function M.supports_tools()
    return true
end

function M.get_model_name()
    local config = require('nvim-agent.config').get()
    return config.api.model or "gpt-4"
end

return M
