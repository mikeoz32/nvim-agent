-- Тести для модуля config
local config = require('nvim-agent.config')

describe("config", function()
    describe("setup", function()
        it("повинен мати дефолтну конфігурацію", function()
            config.setup({})
            local cfg = config.get()
            
            assert.is_not_nil(cfg)
            assert.is_not_nil(cfg.api)
            assert.is_not_nil(cfg.ui)
            assert.is_not_nil(cfg.behavior)
        end)
        
        it("повинен об'єднувати користувацьку конфігурацію з дефолтною", function()
            config.setup({
                api = {
                    provider = "openai"
                }
            })
            
            local cfg = config.get()
            assert.is_not_nil(cfg)
            assert.is_not_nil(cfg.api)
            assert.equals("openai", cfg.api.provider)
            -- Дефолтні значення повинні залишитись
            assert.is_not_nil(cfg.ui)
            assert.is_not_nil(cfg.ui.chat)
        end)
    end)
    
    describe("get_github_copilot_token", function()
        it("повинен повертати токен якщо файл існує", function()
            local token = config.get_github_copilot_token()
            -- Може бути nil якщо Copilot не встановлений
            if token then
                assert.is_string(token)
                assert.is_true(#token > 0)
                -- GitHub OAuth tokens починаються з ghu_, gho_, ghp_
                assert.is_true(token:match("^gh[uop]_") ~= nil)
            end
        end)
    end)
    
    -- TODO: Додати функції get_available_providers, get_available_models, get_models_for_provider в config.lua
    --[[
    describe("providers", function()
        it("повинен мати список доступних провайдерів", function()
            local providers = config.get_available_providers()
            assert.is_not_nil(providers)
            assert.is_true(#providers > 0)
            
            -- Перевіряємо що є основні провайдери
            local has_copilot = false
            local has_openai = false
            
            for _, provider in ipairs(providers) do
                if provider.id == "copilot" then has_copilot = true end
                if provider.id == "openai" then has_openai = true end
            end
            
            assert.is_true(has_copilot)
            assert.is_true(has_openai)
        end)
    end)
    
    describe("models", function()
        it("повинен мати список моделей для кожного провайдера", function()
            local models = config.get_available_models()
            assert.is_not_nil(models)
            assert.is_table(models)
            
            -- Повинні бути моделі для copilot
            assert.is_not_nil(models.copilot)
            assert.is_true(#models.copilot > 0)
        end)
        
        it("повинен повертати моделі для конкретного провайдера", function()
            local copilot_models = config.get_models_for_provider("copilot")
            assert.is_not_nil(copilot_models)
            assert.is_true(#copilot_models > 0)
            
            -- Перевіряємо структуру моделі
            local first_model = copilot_models[1]
            assert.is_not_nil(first_model.id)
            assert.is_not_nil(first_model.name)
        end)
    end)
    ]]--
end)
