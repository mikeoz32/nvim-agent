-- GitHub Copilot API провайдер
-- Використовує GitHub Copilot Chat API через api.githubcopilot.com
local M = {}

local utils = require('nvim-agent.utils')

-- GitHub Copilot API endpoints
local TOKEN_EXCHANGE_URL = "https://api.github.com/copilot_internal/v2/token"
local COPILOT_API_URL = "https://api.githubcopilot.com/chat/completions"

-- Кеш для session token (токен живе ~60 хвилин)
local session_token_cache = {
    token = nil,
    expires_at = 0,
}

-- Отримати GitHub Copilot OAuth token
local function get_copilot_token()
    -- Спосіб 1: З apps.json (найправильніший для Copilot)
    local apps_json_paths = {
        os.getenv("LOCALAPPDATA") and (os.getenv("LOCALAPPDATA") .. "\\github-copilot\\apps.json"),
        os.getenv("HOME") and (os.getenv("HOME") .. "/.config/github-copilot/apps.json"),
    }
    
    for _, path in ipairs(apps_json_paths) do
        if path then
            local file = io.open(path, "r")
            if file then
                local content = file:read("*a")
                file:close()
                
                local ok, data = pcall(vim.fn.json_decode, content)
                if ok and data then
                    -- Шукаємо перший oauth_token
                    for _, app in pairs(data) do
                        if app.oauth_token then
                            return app.oauth_token
                        end
                    end
                end
            end
        end
    end
    
    -- Спосіб 2: Через змінну середовища (якщо встановлено)
    local env_token = os.getenv("GITHUB_COPILOT_TOKEN")
    if env_token and env_token ~= "" then
        return env_token
    end
    
    return nil
end

-- Обмінює Copilot OAuth token на session token
local function exchange_token(oauth_token)
    -- Перевірити кеш
    local now = os.time()
    if session_token_cache.token and session_token_cache.expires_at > now then
        return session_token_cache.token, nil
    end
    
    local curl_cmd = string.format(
        'curl -s -X GET "%s" ' ..
        '-H "Authorization: token %s" ' ..
        '-H "Accept: application/json"',
        TOKEN_EXCHANGE_URL,
        oauth_token
    )
    
    local handle = io.popen(curl_cmd)
    if not handle then
        return nil, "Failed to execute curl command"
    end
    
    local response_text = handle:read("*a")
    handle:close()
    
    -- Перевірка на помилки GitHub API
    if response_text:match('"message"') and (response_text:match('"documentation_url"') or response_text:match('Not Found')) then
        local ok, response = pcall(vim.fn.json_decode, response_text)
        if ok and response.message then
            return nil, "GitHub API error: " .. response.message
        end
    end
    
    local ok, response = pcall(vim.fn.json_decode, response_text)
    if not ok then
        return nil, "Failed to parse token exchange response: " .. response_text
    end
    
    if not response or not response.token then
        return nil, "No token in response: " .. response_text
    end
    
    -- Кешувати на 50 хвилин (токен живе 60 хв)
    session_token_cache.token = response.token
    session_token_cache.expires_at = now + (50 * 60)
    
    return response.token, nil
end

function M.chat(messages, options, callback)
    -- Отримати Copilot OAuth token
    local copilot_token = get_copilot_token()
    
    if not copilot_token then
        callback(nil, "Copilot OAuth token not found. Please sign in to GitHub Copilot:\n" ..
                     "  - In VSCode: Sign in to GitHub Copilot\n" ..
                     "  - Or run: gh copilot\n" ..
                     "  - Or set GITHUB_COPILOT_TOKEN environment variable\n" ..
                     "Token should be stored in: %LOCALAPPDATA%\\github-copilot\\apps.json")
        return
    end
    
    -- Обміняти OAuth token на session token
    local session_token, err = exchange_token(copilot_token)
    if not session_token then
        callback(nil, "Failed to get Copilot session token: " .. err)
        return
    end
    
    -- Підготувати body запиту
    local body = {
        messages = messages,
        model = options.model or "gpt-4o",
        stream = false,
        temperature = options.temperature or 0.7,
        max_tokens = options.max_tokens or 4096,
    }
    
    -- Додати tools якщо є
    if options.tools and #options.tools > 0 then
        body.tools = options.tools
    end
    
    local body_json = vim.fn.json_encode(body)
    
    -- DEBUG: Логувати messages що відправляються
    utils.log("debug", "🔍 Copilot API Request", {
        messages_count = #messages,
        has_tools = (options.tools and #options.tools > 0),
        last_message = messages[#messages]
    })
    
    -- Використовуємо vim.system (Neovim 0.10+) замість curl через jobstart
    local curl_args = {
        '-s',
        '-w', '\\n%{http_code}',
        '-X', 'POST',
        COPILOT_API_URL,
        '-H', 'Content-Type: application/json',
        '-H', 'Authorization: Bearer ' .. session_token,
        '-H', 'Editor-Version: Neovim/' .. vim.version().major .. '.' .. vim.version().minor,
        '-H', 'Editor-Plugin-Version: nvim-agent/1.0.0',
        '-H', 'Copilot-Integration-Id: vscode-chat',
        '-H', 'User-Agent: GitHubCopilotChat/1.0.0',
        '-d', body_json,
    }
    
    vim.system({'curl', unpack(curl_args)}, {
        text = true,
    }, function(result)
        vim.schedule(function()
            if result.code ~= 0 then
                callback(nil, "Copilot API request failed with exit code: " .. result.code .. 
                        (result.stderr and ("\nError: " .. result.stderr) or ""))
                return
            end
            
            local response_text = result.stdout or ""
            if response_text == "" then
                callback(nil, "Empty response from Copilot API")
                return
            end
            
            -- Відокремити HTTP статус код від відповіді
            local http_code = response_text:match("\n(%d+)$")
            if http_code then
                response_text = response_text:gsub("\n" .. http_code .. "$", "")
            end
            
            local ok, response = pcall(vim.fn.json_decode, response_text)
            if not ok then
                callback(nil, "Failed to parse Copilot response (HTTP " .. (http_code or "?") .. "): " .. response_text:sub(1, 200))
                return
            end
            
            if response.error then
                callback(nil, "Copilot API error: " .. (response.error.message or vim.inspect(response.error)))
                return
            end
            
            if not response.choices or #response.choices == 0 then
                callback(nil, "No response from Copilot")
                return
            end
            
            -- Витягуємо message
            local message = response.choices[1].message
            local content = message.content
            
            -- Перетворюємо vim.NIL в nil для content
            if content == vim.NIL then
                content = nil
            end
            
            local tool_calls = message.tool_calls
            
            -- Нормалізуємо tool_calls для правильної серіалізації
            if tool_calls then
                local normalized_calls = {}
                for i, call in ipairs(tool_calls) do
                    -- Переконуємося що структура правильна
                    local normalized = {
                        id = call.id,
                        type = call.type or "function",
                        ["function"] = {
                            name = call["function"].name,
                            arguments = call["function"].arguments
                        }
                    }
                    -- Використовуємо числовий індекс для масиву
                    normalized_calls[i] = normalized
                end
                tool_calls = normalized_calls
            end
            
            -- Повертаємо у форматі callback(err, response, tool_calls)
            callback(nil, content, tool_calls)
        end)
    end)
end

function M.supports_tools()
    return true
end

function M.get_model_name()
    local config = require('nvim-agent.config').get()
    -- Для Copilot завжди використовуємо gpt-4
    if config and config.api and config.api.copilot and config.api.copilot.model then
        return config.api.copilot.model
    end
    return "gpt-4"
end

-- Тестова функція для перевірки з'єднання
function M.test_connection(callback)
    local copilot_token = get_copilot_token()
    
    if not copilot_token then
        callback(false, "Copilot OAuth token not found. Please sign in to GitHub Copilot.")
        return
    end
    
    -- Тест: простий запит до Copilot API
    local test_messages = {{ role = "user", content = "Say 'OK' if you can hear me" }}
    
    M.chat(test_messages, { model = "gpt-4o" }, function(result, err)
        if err then
            callback(false, "Copilot API test failed: " .. err)
        else
            callback(true, "GitHub Copilot API working! Response: " .. (result.content or ""))
        end
    end)
end

-- Отримати список доступних моделей
function M.get_models(callback)
    local copilot_token = get_copilot_token()
    
    if not copilot_token then
        callback(nil, "Copilot OAuth token not found")
        return
    end
    
    -- Обміняти OAuth token на session token
    local session_token, err = exchange_token(copilot_token)
    if not session_token then
        callback(nil, "Failed to get session token: " .. err)
        return
    end
    
    local curl_cmd = string.format(
        'curl -s -X GET "https://api.githubcopilot.com/models" ' ..
        '-H "Authorization: Bearer %s" ' ..
        '-H "Copilot-Integration-Id: vscode-chat" ' ..
        '-H "Accept: application/json"',
        session_token
    )
    
    vim.fn.jobstart(curl_cmd, {
        stdout_buffered = true,
        stderr_buffered = true,
        on_stdout = function(_, data, _)
            if not data or #data == 0 then
                return
            end
            
            local response_text = table.concat(data, "\n")
            if response_text == "" then
                return
            end
            
            vim.schedule(function()
                local ok, response = pcall(vim.fn.json_decode, response_text)
                if not ok then
                    callback(nil, "Failed to parse models response: " .. response_text)
                    return
                end
                
                if response.error then
                    callback(nil, "API error: " .. (response.error.message or "unknown"))
                    return
                end
                
                if not response.data then
                    callback(nil, "No models data in response")
                    return
                end
                
                -- Фільтруємо тільки chat моделі (не embedding)
                local chat_models = {}
                for _, model in ipairs(response.data) do
                    if not model.id:match("embedding") and not model.id:match("^text%-embedding") then
                        table.insert(chat_models, {
                            id = model.id,
                            name = model.name or model.id,
                            version = model.version,
                            category = model.model_picker_category,
                        })
                    end
                end
                
                callback(chat_models, nil)
            end)
        end,
        on_stderr = function(_, data, _)
            if data and #data > 0 then
                local error_text = table.concat(data, "\n")
                if error_text ~= "" then
                    utils.log("error", "Get models stderr", { error = error_text })
                end
            end
        end,
        on_exit = function(_, exit_code, _)
            if exit_code ~= 0 then
                vim.schedule(function()
                    callback(nil, "Failed to get models, exit code: " .. exit_code)
                end)
            end
        end,
    })
end

return M
