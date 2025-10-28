-- Допоміжні функції для тестів
local M = {}

-- Завантажує плагін для тестування
function M.setup()
    -- Додаємо шлях до плагіна
    local plugin_path = vim.fn.fnamemodify(vim.fn.getcwd(), ':p')
    vim.opt.rtp:prepend(plugin_path)
    
    -- Завантажуємо плагін
    local nvim_agent = require('nvim-agent')
    nvim_agent.setup({
        api = {
            provider = "copilot",
            model = "gpt-4o"
        },
        behavior = {
            include_file_context = false,  -- Вимикаємо для тестів
            auto_save_chat = false
        },
        debug = {
            enabled = false  -- Вимикаємо логи під час тестів
        }
    })
    
    return nvim_agent
end

-- Створює тимчасовий буфер з вмістом
function M.create_temp_buffer(content, filetype)
    local buf = vim.api.nvim_create_buf(false, true)
    
    if type(content) == "string" then
        content = vim.split(content, "\n")
    end
    
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)
    
    if filetype then
        vim.api.nvim_buf_set_option(buf, 'filetype', filetype)
    end
    
    return buf
end

-- Створює тимчасовий файл
function M.create_temp_file(content, extension)
    local temp_file = vim.fn.tempname()
    if extension then
        temp_file = temp_file .. "." .. extension
    end
    
    if type(content) == "string" then
        content = vim.split(content, "\n")
    end
    
    vim.fn.writefile(content, temp_file)
    
    return temp_file
end

-- Чекає асинхронної операції з timeout
function M.wait_for(condition, timeout, interval)
    timeout = timeout or 5000
    interval = interval or 100
    
    return vim.wait(timeout, condition, interval)
end

-- Mock функція для API викликів
function M.mock_api_response(response, tool_calls)
    local original_chat = require('nvim-agent.api.copilot').chat
    
    local mock = {
        calls = {},
        restore = function(self)
            require('nvim-agent.api.copilot').chat = original_chat
        end
    }
    
    require('nvim-agent.api.copilot').chat = function(messages, options, callback)
        table.insert(mock.calls, {
            messages = messages,
            options = options
        })
        
        vim.schedule(function()
            callback(nil, response, tool_calls)
        end)
    end
    
    return mock
end

-- Очищає всі тестові дані
function M.cleanup()
    -- Очищаємо сесії
    local sessions = require('nvim-agent.sessions')
    local list = sessions.list_sessions()
    
    for _, session in ipairs(list) do
        if session.id:match("^test%-") then
            sessions.delete_session(session.id)
        end
    end
    
    -- Закриваємо всі тестові буфери
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) then
            local name = vim.api.nvim_buf_get_name(buf)
            if name:match("test%-") or vim.api.nvim_buf_get_option(buf, 'buftype') ~= '' then
                vim.api.nvim_buf_delete(buf, {force = true})
            end
        end
    end
end

return M
