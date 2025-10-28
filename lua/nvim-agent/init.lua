-- nvim-agent: AI-powered coding assistant for Neovim
-- Головний модуль плагіна

local M = {}

-- Локальні модулі
local config = require('nvim-agent.config')
local api = require('nvim-agent.api')
local chat = require('nvim-agent.chat')
local commands = require('nvim-agent.commands')

-- Версія плагіна
M.version = "0.1.0"

-- Ініціалізація плагіна
function M.setup(user_config)
    -- Об'єднуємо користувацьку конфігурацію з дефолтною
    config.setup(user_config or {})
    
    -- Налаштовуємо інтеграцію з GitHub Copilot
    local has_copilot = config.setup_copilot_integration()
    
    -- Ініціалізуємо API модуль
    api.setup()
    
    -- Ініціалізуємо чат
    chat.setup()
    
    -- Реєструємо команди
    commands.register()
    
    -- Виводимо повідомлення про успішну ініціалізацію
    local cfg = config.get()
    local provider_msg = ""
    
    if cfg.api.provider == "github-copilot" then
        provider_msg = " (GitHub Copilot via gh CLI)"
    elseif cfg.api.provider == "copilot" then
        provider_msg = " (GitHub Copilot)"
    elseif cfg.api.provider == "openai" then
        provider_msg = " (OpenAI)"
    elseif cfg.api.provider == "anthropic" then
        provider_msg = " (Anthropic)"
    elseif cfg.api.provider == "local" then
        provider_msg = " (Local: " .. (cfg.api.model or "unknown") .. ")"
    end
    
    vim.notify("nvim-agent v" .. M.version .. " готовий до роботи!" .. provider_msg, vim.log.levels.INFO)
end

-- Основні функції
M.chat = {
    open = chat.open,
    close = chat.close,
    toggle = chat.toggle,
    send_message = chat.send_message,
    clear = chat.clear
}

M.code = {
    explain = function() commands.explain_code() end,
    generate = function() commands.generate_code() end,
    refactor = function() commands.refactor_code() end,
    test = function() commands.generate_tests() end,
    document = function() commands.generate_docs() end
}

return M