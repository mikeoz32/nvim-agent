-- GitHub Copilot API провайдер
-- Використовує GitHub Models API з автентифікацією через gh CLI
local M = {}

local utils = require('nvim-agent.utils')

-- Отримати GitHub токен через gh CLI
local function get_github_token()
    local config = require('nvim-agent.config').get()
    
    -- Спочатку перевіряємо чи є токен в конфігурації
    if config.api.github_token then
        return config.api.github_token
    end
    
    -- Перевіряємо змінні оточення
    local token = os.getenv("GITHUB_TOKEN") or os.getenv("GITHUB_COPILOT_TOKEN")
    if token then
        return token
    end
    
    -- Спробуємо отримати через gh CLI
    local handle = io.popen("gh auth token 2>&1")
    if handle then
        local result = handle:read("*a")
        handle:close()
        
        -- Видаляємо пробіли та переноси рядків
        result = result:gsub("%s+", "")
        
        if result and result ~= "" and not result:match("error") and not result:match("not logged in") then
            return result
        end
    end
    
    return nil
end

-- Перевірити чи gh CLI встановлений
local function check_gh_cli()
    if vim.fn.executable('gh') == 0 then
        return false, "GitHub CLI (gh) не встановлений. Встановіть: winget install GitHub.cli"
    end
    return true, nil
end

-- Автоматично залогінитись в GitHub
local function auto_login()
    local ok, err = check_gh_cli()
    if not ok then
        vim.notify(err, vim.log.levels.ERROR)
        return false
    end
    
    vim.notify("🔐 Потрібна авторизація в GitHub...", vim.log.levels.INFO)
    
    -- Запитуємо чи хоче користувач залогінитись
    vim.ui.select(
        {"Так, залогінитись зараз", "Ні, пізніше"},
        {
            prompt = "GitHub Copilot потребує авторизації. Залогінитись?",
        },
        function(choice)
            if choice == "Так, залогінитись зараз" then
                -- Відкриваємо термінал для gh auth login
                vim.notify("📝 Відкриваю термінал для авторизації...", vim.log.levels.INFO)
                
                -- Створюємо новий термінальний буфер
                vim.cmd('split')
                vim.cmd('terminal gh auth login')
                vim.cmd('startinsert')
                
                -- Підказка користувачу
                vim.defer_fn(function()
                    vim.notify(
                        "💡 Після авторизації закрийте термінал і перезапустіть чат (<Space>cc)",
                        vim.log.levels.INFO
                    )
                end, 1000)
            else
                vim.notify(
                    "ℹ️  Ви можете залогінитись пізніше командою :terminal gh auth login",
                    vim.log.levels.INFO
                )
            end
        end
    )
    
    return false
end

function M.chat(messages, options, callback)
    local token = get_github_token()
    
    if not token then
        -- Спробуємо автоматично залогінитись
        auto_login()
        callback(nil, "GitHub авторизація потрібна. Будь ласка, завершіть авторизацію і спробуйте знову.")
        return
    end
    
    local config = require('nvim-agent.config').get()
    local model = options.model or config.api.model or "gpt-4o"
    
    -- ТИМЧАСОВО: GitHub Models API може не підтримувати tools
    -- Видаляємо tools для тестування
    local has_tools = options.tools and #options.tools > 0
    if has_tools then
        vim.notify("⚠️  GitHub Models API: tools поки не підтримуються, запит без tools", vim.log.levels.WARN)
    end
    
    -- Формуємо запит для GitHub Models API
    local body = {
        model = model,
        messages = messages,
        stream = false,
        temperature = options.temperature or 0.7,
        max_tokens = options.max_tokens or 4096,
    }
    
    -- ТИМЧАСОВО закоментовано - GitHub Models API може не підтримувати tools
    -- if options.tools and #options.tools > 0 then
    --     body.tools = options.tools
    -- end
    
    -- GitHub Models API endpoint
    local url = "https://models.inference.ai.azure.com/chat/completions"
    
    -- Формуємо curl команду
    local cmd = {
        "curl",
        "-s",
        "-X", "POST",
        url,
        "-H", "Content-Type: application/json",
        "-H", "Authorization: Bearer " .. token,
        "-d", vim.fn.json_encode(body)
    }
    
    utils.log("debug", "GitHub Copilot API request", {
        model = model,
        messages_count = #messages,
        tools_count = options.tools and #options.tools or 0
    })
    
    -- Виконуємо запит
    local stdout_chunks = {}
    local stderr_chunks = {}
    
    vim.fn.jobstart(cmd, {
        on_stdout = function(_, data, _)
            if data then
                for _, line in ipairs(data) do
                    if line ~= "" then
                        table.insert(stdout_chunks, line)
                    end
                end
            end
        end,
        on_stderr = function(_, data, _)
            if data then
                for _, line in ipairs(data) do
                    if line ~= "" then
                        table.insert(stderr_chunks, line)
                    end
                end
            end
        end,
        on_exit = vim.schedule_wrap(function(_, exit_code, _)
            if exit_code ~= 0 then
                local error_msg = table.concat(stderr_chunks, "\n")
                local stdout_msg = table.concat(stdout_chunks, "\n")
                
                utils.log("error", "GitHub Copilot API error", { 
                    exit_code = exit_code,
                    stderr = error_msg,
                    stdout = stdout_msg
                })
                
                -- Показуємо більше деталей користувачу
                local full_error = "GitHub Copilot API error (exit code " .. exit_code .. "):\n"
                if error_msg ~= "" then
                    full_error = full_error .. "Error: " .. error_msg
                end
                if stdout_msg ~= "" then
                    full_error = full_error .. "\nResponse: " .. stdout_msg:sub(1, 500)
                end
                
                callback(nil, full_error)
                return
            end
            
            local response_text = table.concat(stdout_chunks, "")
            
            -- Парсимо JSON відповідь
            local ok, response = pcall(vim.fn.json_decode, response_text)
            if not ok then
                utils.log("error", "Failed to parse GitHub Copilot response", {
                    response = response_text:sub(1, 200)
                })
                callback(nil, "Failed to parse response from GitHub Copilot")
                return
            end
            
            -- Перевіряємо на помилки
            if response.error then
                local error_msg = response.error.message or vim.inspect(response.error)
                utils.log("error", "GitHub Copilot API error", { error = error_msg })
                callback(nil, "GitHub Copilot error: " .. error_msg)
                return
            end
            
            -- Витягуємо відповідь
            if not response.choices or #response.choices == 0 then
                callback(nil, "No response from GitHub Copilot")
                return
            end
            
            local message = response.choices[1].message
            local result = {
                content = message.content,
                tool_calls = message.tool_calls,
            }
            
            utils.log("debug", "GitHub Copilot API response", {
                content_length = message.content and #message.content or 0,
                has_tool_calls = message.tool_calls ~= nil
            })
            
            callback(result, nil)
        end)
    })
end

function M.supports_tools()
    return true
end

function M.get_model_name()
    local config = require('nvim-agent.config').get()
    return config.api.model or "gpt-4o"
end

-- Перевірити чи доступна авторизація
function M.check_auth()
    local token = get_github_token()
    return token ~= nil, token and "GitHub authenticated" or "GitHub token not found"
end

return M
