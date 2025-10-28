-- API модуль для взаємодії з AI провайдерами
local M = {}

local config = require('nvim-agent.config')
local utils = require('nvim-agent.utils')

-- Локальні змінні
local curl = nil
local job_id = nil

-- Ініціалізація модуля
function M.setup()
    -- Перевіряємо наявність curl
    if vim.fn.executable('curl') == 0 then
        vim.notify("nvim-agent: curl не знайдено. Потрібен для роботи з API.", vim.log.levels.ERROR)
        return false
    end
    
    curl = "curl"
    return true
end

-- Базова функція для HTTP запитів
local function make_request(url, headers, body, callback)
    local cmd = {
        curl,
        "-s",  -- silent
        "-X", "POST",
        "-H", "Content-Type: application/json",
    }
    
    -- Додаємо заголовки
    for key, value in pairs(headers) do
        table.insert(cmd, "-H")
        table.insert(cmd, key .. ": " .. value)
    end
    
    -- Додаємо тіло запиту
    table.insert(cmd, "-d")
    table.insert(cmd, vim.json.encode(body))
    
    -- Додаємо URL
    table.insert(cmd, url)
    
    -- Виконуємо запит асинхронно
    job_id = vim.fn.jobstart(cmd, {
        on_stdout = function(_, data, _)
            local response = table.concat(data, "")
            if response and response ~= "" then
                local success, result = pcall(vim.json.decode, response)
                if success then
                    callback(nil, result)
                else
                    callback("Помилка парсингу JSON: " .. response, nil)
                end
            end
        end,
        on_stderr = function(_, data, _)
            local error_msg = table.concat(data, "")
            if error_msg and error_msg ~= "" then
                callback("Помилка HTTP: " .. error_msg, nil)
            end
        end,
        on_exit = function(_, exit_code, _)
            if exit_code ~= 0 then
                callback("Помилка виконання запиту, код: " .. exit_code, nil)
            end
        end
    })
    
    return job_id
end

-- OpenAI API провайдер
local openai = {
    base_url = "https://api.openai.com/v1",
    
    chat_completion = function(messages, callback, tools)
        local cfg = config.get()
        local url = (cfg.api.base_url or openai.base_url) .. "/chat/completions"
        
        local headers = {
            ["Authorization"] = "Bearer " .. cfg.api.api_key
        }
        
        local body = {
            model = cfg.api.model,
            messages = messages,
            max_tokens = cfg.api.max_tokens,
            temperature = cfg.api.temperature,
            stream = false
        }
        
        -- Додаємо tools якщо передано
        if tools and #tools > 0 then
            body.tools = tools
            body.tool_choice = "auto"
        end
        
        return make_request(url, headers, body, function(err, response)
            if err then
                callback(err, nil)
                return
            end
            
            if response.error then
                callback("OpenAI API помилка: " .. (response.error.message or "Невідома помилка"), nil)
                return
            end
            
            if response.choices and #response.choices > 0 then
                local message = response.choices[1].message
                
                -- Перевіряємо чи є tool calls
                if message.tool_calls then
                    callback(nil, nil, message.tool_calls)
                else
                    callback(nil, message.content)
                end
            else
                callback("Пуста відповідь від API", nil)
            end
        end)
    end
}

-- Anthropic API провайдер
local anthropic = {
    base_url = "https://api.anthropic.com/v1",
    
    chat_completion = function(messages, callback, tools)
        local cfg = config.get()
        local url = (cfg.api.base_url or anthropic.base_url) .. "/messages"
        
        local headers = {
            ["x-api-key"] = cfg.api.api_key,
            ["anthropic-version"] = "2023-06-01"
        }
        
        -- Конвертуємо формат повідомлень для Anthropic
        local anthropic_messages = {}
        for _, msg in ipairs(messages) do
            if msg.role ~= "system" then
                table.insert(anthropic_messages, {
                    role = msg.role,
                    content = msg.content
                })
            end
        end
        
        local body = {
            model = cfg.api.model,
            messages = anthropic_messages,
            max_tokens = cfg.api.max_tokens,
            temperature = cfg.api.temperature
        }
        
        -- Додаємо tools для Anthropic (вони називаються tools)
        if tools and #tools > 0 then
            body.tools = {}
            for _, tool in ipairs(tools) do
                table.insert(body.tools, {
                    name = tool["function"].name,
                    description = tool["function"].description,
                    input_schema = tool["function"].parameters
                })
            end
        end
        
        return make_request(url, headers, body, function(err, response)
            if err then
                callback(err, nil)
                return
            end
            
            if response.error then
                callback("Anthropic API помилка: " .. (response.error.message or "Невідома помилка"), nil)
                return
            end
            
            if response.content and #response.content > 0 then
                -- Перевіряємо чи є tool_use блоки
                local tool_calls = {}
                local text_content = ""
                
                for _, content in ipairs(response.content) do
                    if content.type == "tool_use" then
                        table.insert(tool_calls, {
                            id = content.id,
                            type = "function",
                            ["function"] = {
                                name = content.name,
                                arguments = vim.json.encode(content.input)
                            }
                        })
                    elseif content.type == "text" then
                        text_content = text_content .. content.text
                    end
                end
                
                if #tool_calls > 0 then
                    callback(nil, nil, tool_calls)
                else
                    callback(nil, text_content)
                end
            else
                callback("Пуста відповідь від API", nil)
            end
        end)
    end
}

-- GitHub Copilot API провайдер
local github_copilot = {
    base_url = "https://api.github.com/copilot",
    
    chat_completion = function(messages, callback)
        local cfg = config.get()
        
        -- Для GitHub Copilot потрібен особливий токен
        if not cfg.api.github_token then
            callback("GitHub token не налаштовано. Встановіть github_token в конфігурації або GITHUB_TOKEN у змінних оточення", nil)
            return
        end
        
        local url = (cfg.api.base_url or github_copilot.base_url) .. "/chat/completions"
        
        local headers = {
            ["Authorization"] = "token " .. cfg.api.github_token,
            ["Accept"] = "application/vnd.github.v3+json",
            ["User-Agent"] = "nvim-agent/1.0"
        }
        
        -- GitHub Copilot використовує інший формат
        local body = {
            messages = messages,
            model = cfg.api.model or "gpt-4",
            max_tokens = cfg.api.max_tokens,
            temperature = cfg.api.temperature,
            stream = false
        }
        
        return make_request(url, headers, body, function(err, response)
            if err then
                callback(err, nil)
                return
            end
            
            if response.error then
                callback("GitHub Copilot API помилка: " .. (response.error.message or "Невідома помилка"), nil)
                return
            end
            
            if response.choices and #response.choices > 0 then
                local message = response.choices[1].message
                callback(nil, message.content)
            else
                callback("Пуста відповідь від GitHub Copilot API", nil)
            end
        end)
    end
}

-- Локальний API провайдер (для Ollama та інших)
local local_provider = {
    chat_completion = function(messages, callback)
        local cfg = config.get()
        
        if not cfg.api.base_url then
            callback("Не вказано base_url для локального провайдера", nil)
            return
        end
        
        local url = cfg.api.base_url .. "/chat/completions"
        
        local headers = {}
        if cfg.api.api_key then
            headers["Authorization"] = "Bearer " .. cfg.api.api_key
        end
        
        local body = {
            model = cfg.api.model,
            messages = messages,
            max_tokens = cfg.api.max_tokens,
            temperature = cfg.api.temperature,
            stream = false
        }
        
        return make_request(url, headers, body, function(err, response)
            if err then
                callback(err, nil)
                return
            end
            
            if response.error then
                callback("Локальний API помилка: " .. (response.error.message or "Невідома помилка"), nil)
                return
            end
            
            if response.choices and #response.choices > 0 then
                local message = response.choices[1].message
                callback(nil, message.content)
            else
                callback("Пуста відповідь від API", nil)
            end
        end)
    end
}

-- GitHub Copilot провайдер (використовує окремий модуль)
local github_copilot_module = require('nvim-agent.api.github_copilot')
local github_copilot = {
    chat_completion = function(messages, callback, tools)
        local options = { tools = tools }
        github_copilot_module.chat(messages, options, function(result, err)
            -- github_copilot.chat викликає callback(result, err)
            -- але нам потрібно callback(err, response, tool_calls)
            if err then
                callback(err, nil, nil)
            elseif result then
                callback(nil, result.content, result.tool_calls)
            else
                callback("Unknown error from GitHub Copilot", nil, nil)
            end
        end)
    end
}

-- Copilot провайдер (legacy, через VS Code)
local copilot_module = require('nvim-agent.api.copilot')
local copilot_provider = {
    chat_completion = function(messages, callback, tools)
        local options = { tools = tools }
        copilot_module.chat(messages, options, function(err, response, tool_calls)
            -- copilot.chat тепер викликає callback(err, response, tool_calls)
            callback(err, response, tool_calls)
        end)
    end
}

-- Основна функція для надсилання запиту
function M.chat_completion(messages, callback, options)
    local cfg = config.get()
    
    -- Провайдери які не потребують API ключа
    local no_key_providers = { "local", "copilot", "github-copilot" }
    local requires_key = true
    for _, p in ipairs(no_key_providers) do
        if cfg.api.provider == p then
            requires_key = false
            break
        end
    end
    
    if requires_key and not cfg.api.api_key then
        callback("API ключ не налаштовано", nil)
        return
    end
    
    options = options or {}
    local tools = options.tools
    
    -- Логуємо запит якщо включений debug
    if cfg.debug.enabled then
        utils.log("debug", "Надсилаємо запит до " .. cfg.api.provider, {
            provider = cfg.api.provider,
            model = cfg.api.model,
            message_count = #messages,
            tools_count = tools and #tools or 0
        })
    end
    
    -- Вибираємо провайдера
    local provider
    if cfg.api.provider == "openai" then
        provider = openai
    elseif cfg.api.provider == "anthropic" then
        provider = anthropic
    elseif cfg.api.provider == "github-copilot" then
        provider = github_copilot
    elseif cfg.api.provider == "copilot" then
        provider = copilot_provider
    elseif cfg.api.provider == "local" then
        provider = local_provider
    else
        callback("Непідтримуваний провайдер: " .. cfg.api.provider, nil)
        return
    end
    
    -- Викликаємо провайдера з обробкою таймауту
    local request_job = provider.chat_completion(messages, function(err, response, tool_calls)
        if cfg.debug.enabled then
            if err then
                utils.log("error", "Помилка API запиту", { error = err })
            elseif tool_calls then
                utils.log("debug", "Отримано tool calls від API", { 
                    count = #tool_calls
                })
            else
                utils.log("debug", "Отримано відповідь від API", { 
                    has_response = response ~= nil
                })
            end
        end
        
        callback(err, response, tool_calls)
    end, tools)
    
    -- Встановлюємо таймаут
    if cfg.api.timeout > 0 then
        vim.defer_fn(function()
            if vim.fn.jobwait({request_job}, 0)[1] == -1 then
                vim.fn.jobstop(request_job)
                callback("Таймаут запиту (" .. cfg.api.timeout .. "мс)", nil)
            end
        end, cfg.api.timeout)
    end
    
    return request_job
end

-- Функція для швидкого запиту з текстом
function M.quick_chat(prompt, context, callback)
    local messages = {}
    
    -- Додаємо системний промпт якщо є
    if context and context.system then
        table.insert(messages, {
            role = "system",
            content = context.system
        })
    end
    
    -- Додаємо контекст коду якщо є
    if context and context.code then
        table.insert(messages, {
            role = "user", 
            content = "Контекст коду:\n```" .. (context.filetype or "") .. "\n" .. context.code .. "\n```\n\n" .. prompt
        })
    else
        table.insert(messages, {
            role = "user",
            content = prompt
        })
    end
    
    return M.chat_completion(messages, callback)
end

-- Перевірка з'єднання з API
function M.test_connection(callback)
    local test_messages = {{
        role = "user",
        content = "Привіт! Це тест з'єднання. Відповідь 'OK' якщо все працює."
    }}
    
    M.chat_completion(test_messages, function(err, response)
        if err then
            callback(false, "Помилка з'єднання: " .. err)
        else
            callback(true, "З'єднання успішне. Відповідь: " .. (response or "немає"))
        end
    end)
end

-- Скасування поточного запиту
function M.cancel_request()
    if job_id and vim.fn.jobwait({job_id}, 0)[1] == -1 then
        vim.fn.jobstop(job_id)
        job_id = nil
        return true
    end
    return false
end

-- Отримати список доступних моделей
function M.get_models(callback)
    local cfg = config.get()
    local provider = cfg.api.provider
    
    if provider == "github-copilot" then
        local copilot = require('nvim-agent.api.copilot')
        copilot.get_models(callback)
    elseif provider == "openai" then
        -- OpenAI не має публічного API для списку моделей
        -- Повертаємо статичний список
        callback({
            { id = "gpt-4o", name = "GPT-4o" },
            { id = "gpt-4o-mini", name = "GPT-4o Mini" },
            { id = "gpt-4-turbo", name = "GPT-4 Turbo" },
            { id = "gpt-4", name = "GPT-4" },
            { id = "gpt-3.5-turbo", name = "GPT-3.5 Turbo" },
        }, nil)
    elseif provider == "anthropic" then
        -- Anthropic статичний список
        callback({
            { id = "claude-3-opus-20240229", name = "Claude 3 Opus" },
            { id = "claude-3-sonnet-20240229", name = "Claude 3 Sonnet" },
            { id = "claude-3-haiku-20240307", name = "Claude 3 Haiku" },
        }, nil)
    else
        callback(nil, "Провайдер " .. provider .. " не підтримує список моделей")
    end
end

return M