-- Модуль конфігурації для nvim-agent
local M = {}

-- Дефолтна конфігурація
M.defaults = {
    -- API налаштування
    api = {
        provider = "copilot",  -- copilot (найкраще), openai, anthropic, github-copilot, local
        model = "gpt-4o",      -- модель для використання
        api_key = nil,        -- API ключ (краще встановлювати через змінну оточення)
        github_token = nil,   -- GitHub токен для Copilot API (автоматично з apps.json)
        base_url = nil,       -- для локальних або кастомних API
        timeout = 30000,      -- таймаут в мілісекундах
        max_tokens = 2048,    -- максимальна кількість токенів у відповіді
        temperature = 0.7,    -- креативність (0.0 - 2.0)
    },
    
    -- UI налаштування
    ui = {
        -- Чат вікно
        chat = {
            width = 50,           -- ширина у відсотках від екрана
            height = 80,          -- висота у відсотках від екрана
            position = "right",   -- right, left, bottom, float
            border = "rounded",   -- none, single, double, rounded, solid, shadow
            title = "nvim-agent",
            show_help = true,     -- показувати підказки
        },
        
        -- Popup вікна
        popup = {
            border = "rounded",
            title_pos = "center",
            relative = "cursor",
        },
        
        -- Кольори та стилі
        highlights = {
            chat_border = "FloatBorder",
            chat_title = "Title",
            user_message = "Comment",
            ai_message = "Normal",
            code_block = "String",
            error = "ErrorMsg",
        }
    },
    
    -- Поведінка
    behavior = {
        -- Режим роботи за замовчуванням
        default_mode = "ask",              -- "ask", "edit", "agent"
        
        -- Автоматичне збереження історії чату
        auto_save_chat = true,
        chat_history_file = vim.fn.stdpath("data") .. "/nvim-agent-chat.json",
        
        -- Контекст коду
        include_file_context = true,  -- включати контекст поточного файлу
        context_lines = 20,           -- кількість ліній контексту навколо курсора
        max_context_files = 5,        -- максимальна кількість файлів в контексті
        
        -- Автодоповнення
        auto_suggest = false,         -- автоматичні пропозиції під час вводу
        suggest_delay = 1000,         -- затримка перед пропозиціями (мс)
        
        -- Інтеграція з copilot
        disable_copilot_when_active = false,
    },
    
    -- MCP (Model Context Protocol) налаштування
    mcp = {
        enabled = true,  -- Увімкнути підтримку MCP tools
        
        -- Зовнішні MCP сервери
        servers = {
            -- Приклад конфігурації серверів:
            -- {
            --     name = "filesystem",
            --     command = "mcp-server-filesystem",
            --     args = {"/path/to/workspace"},
            --     env = {}
            -- }
        },
        
        -- Налаштування інструментів
        tools = {
            -- Базові Neovim інструменти завжди доступні
            -- Можна вимкнути окремі інструменти:
            -- read_file = false,
            -- write_file = false,
        }
    },
    
    -- Команди та хоткеї
    keymaps = {
        -- Глобальні хоткеї
        toggle_chat = "<leader>cc",
        explain_code = "<leader>ce",
        generate_code = "<leader>cg", 
        refactor_code = "<leader>cr",
        generate_tests = "<leader>ct",
        generate_docs = "<leader>cd",
        cycle_mode = "<leader>cm",        -- Переключення режиму
        
        -- Хоткеї в чаті
        chat = {
            send_message = "<CR>",
            new_line = "<S-CR>",
            clear_chat = "<C-l>",
            close_chat = "<Esc>",
            focus_input = "<C-i>",
            cycle_mode = "<C-m>",         -- Переключення режиму в чаті
        }
    },
    
    -- Промпти для різних задач
    prompts = {
        explain = "Поясни цей код детально. Опиши що він робить, як працює та які можливі покращення:",
        generate = "Згенеруй код на основі цього опису. Використовуй найкращі практики та додай коментарі:",
        refactor = "Покращ цей код. Зроби його більш читабельним, ефективним та дотримуйся найкращих практик:",
        test = "Створи unit тести для цього коду. Покрий основні сценарії та крайні випадки:",
        document = "Створи документацію для цього коду. Включи опис параметрів, повертаних значень та приклади використання:",
        review = "Проведи код-рев'ю цього коду. Знайди потенційні проблеми, помилки та запропонуй покращення:",
        fix = "Знайди та виправ баги в цьому коді. Поясни що було не так та як це виправлено:",
    },
    
    -- Логування та налагодження
    debug = {
        enabled = false,
        log_level = "info",   -- error, warn, info, debug, trace
        log_file = vim.fn.stdpath("cache") .. "/nvim-agent.log",
    }
}

-- Поточна конфігурація
M.current = {}

-- Функція налаштування
function M.setup(user_config)
    -- Глибоке об'єднання конфігурацій
    M.current = vim.tbl_deep_extend("force", M.defaults, user_config or {})
    
    -- Перевіряємо API ключ
    if not M.current.api.api_key then
        -- Спробуємо отримати з змінних оточення
        local env_key = os.getenv("OPENAI_API_KEY") or 
                       os.getenv("ANTHROPIC_API_KEY") or
                       os.getenv("NVIM_AGENT_API_KEY")
        
        if env_key then
            M.current.api.api_key = env_key
        elseif M.current.api.provider ~= "github-copilot" and M.current.api.provider ~= "copilot" and M.current.api.provider ~= "local" and M.current.api.provider ~= "mock" then
            vim.notify("nvim-agent: API ключ не знайдено. Встановіть OPENAI_API_KEY або налаштуйте в конфігурації.", 
                      vim.log.levels.WARN)
        end
    end
    
    -- Перевіряємо GitHub токен для Copilot
    if not M.current.api.github_token and (M.current.api.provider == "github-copilot" or M.current.api.provider == "copilot") then
        local github_token = os.getenv("GITHUB_TOKEN") or 
                            os.getenv("GITHUB_COPILOT_TOKEN") or
                            M.get_github_copilot_token()
        
        if github_token then
            M.current.api.github_token = github_token
        else
            -- Замість попередження, пропонуємо залогінитись
            vim.defer_fn(function()
                vim.ui.select(
                    {"Так, налаштувати зараз", "Ні, пізніше"},
                    {
                        prompt = "🔐 GitHub Copilot не налаштовано. Налаштувати авторизацію?",
                    },
                    function(choice)
                        if choice == "Так, налаштувати зараз" then
                            if vim.fn.executable('gh') == 0 then
                                vim.notify(
                                    "❌ GitHub CLI не встановлений.\n" ..
                                    "Встановіть: winget install GitHub.cli",
                                    vim.log.levels.ERROR
                                )
                                return
                            end
                            
                            vim.notify("📝 Відкриваю термінал для авторизації...", vim.log.levels.INFO)
                            vim.cmd('split')
                            vim.cmd('terminal gh auth login')
                            vim.cmd('startinsert')
                            
                            vim.defer_fn(function()
                                vim.notify(
                                    "💡 Після завершення авторизації:\n" ..
                                    "1. Закрийте термінал (введіть 'exit' або натисніть Ctrl+D)\n" ..
                                    "2. Відкрийте чат: <Space>cc",
                                    vim.log.levels.INFO,
                                    { timeout = 10000 }
                                )
                            end, 1000)
                        else
                            vim.notify(
                                "ℹ️  Ви можете налаштувати пізніше:\n" ..
                                "   :terminal gh auth login\n" ..
                                "Або встановіть GITHUB_TOKEN: $env:GITHUB_TOKEN = (gh auth token)",
                                vim.log.levels.INFO,
                                { timeout = 5000 }
                            )
                        end
                    end
                )
            end, 500)
        end
    end
    
    -- Створюємо директорії для файлів
    local data_dir = vim.fn.fnamemodify(M.current.behavior.chat_history_file, ":h")
    if vim.fn.isdirectory(data_dir) == 0 then
        vim.fn.mkdir(data_dir, "p")
    end
    
    local log_dir = vim.fn.fnamemodify(M.current.debug.log_file, ":h") 
    if vim.fn.isdirectory(log_dir) == 0 then
        vim.fn.mkdir(log_dir, "p")
    end
    
    -- Налаштовуємо хайлайти
    M.setup_highlights()
    
    return M.current
end

-- Налаштування підсвічування
function M.setup_highlights()
    local highlights = M.current.ui.highlights
    
    -- Встановлюємо кастомні хайлайти якщо потрібно
    for name, group in pairs(highlights) do
        if not vim.fn.hlexists("NvimAgent" .. name) then
            vim.cmd(string.format("highlight default link NvimAgent%s %s", name, group))
        end
    end
end

-- Отримати поточну конфігурацію
function M.get()
    return M.current
end

-- Отримати значення з конфігурації
function M.get_option(path, default)
    local keys = vim.split(path, ".", { plain = true })
    local value = M.current
    
    for _, key in ipairs(keys) do
        if type(value) == "table" and value[key] ~= nil then
            value = value[key]
        else
            return default
        end
    end
    
    return value
end

-- Встановити значення в конфігурації
function M.set_option(path, value)
    local keys = vim.split(path, ".", { plain = true })
    local config = M.current
    
    for i = 1, #keys - 1 do
        local key = keys[i]
        if type(config[key]) ~= "table" then
            config[key] = {}
        end
        config = config[key]
    end
    
    config[keys[#keys]] = value
end

-- Отримати GitHub Copilot токен з GitHub CLI
function M.get_github_copilot_token()
    -- Читаємо токен з apps.json (як робить copilot.lua)
    local apps_json_paths = {
        (os.getenv("LOCALAPPDATA") or "") .. "\\github-copilot\\apps.json",
        (os.getenv("HOME") or "") .. "/.config/github-copilot/apps.json",
    }
    
    for _, path in ipairs(apps_json_paths) do
        local file = io.open(path, "r")
        if file then
            local content = file:read("*all")
            file:close()
            
            -- Парсимо JSON
            local ok, data = pcall(vim.fn.json_decode, content)
            if ok and data then
                -- apps.json має структуру: { "github.com:appid": { "oauth_token": "ghu_..." } }
                for _, app_data in pairs(data) do
                    if app_data.oauth_token then
                        return app_data.oauth_token
                    end
                end
            end
        end
    end
    
    -- Fallback: спробуємо gh CLI
    if vim.fn.executable('gh') == 1 then
        local handle = io.popen('gh auth token 2>/dev/null')
        if handle then
            local result = handle:read("*a")
            handle:close()
            
            if result and result:match("%S") then
                return result:gsub("%s+", "")
            end
        end
    end
    
    return nil
end

-- Перевірка інтеграції з існуючим GitHub Copilot
function M.check_copilot_integration()
    -- Перевіряємо чи встановлено GitHub Copilot плагін
    local has_copilot = false
    
    -- Перевіряємо кілька поширених шляхів до Copilot плагіна
    local copilot_paths = {
        "github/copilot.vim",
        "copilot",
        "copilot.vim"
    }
    
    for _, path in ipairs(copilot_paths) do
        if pcall(require, path) then
            has_copilot = true
            break
        end
    end
    
    -- Також перевіряємо через vim команди
    if not has_copilot then
        has_copilot = vim.fn.exists(":Copilot") == 2
    end
    
    return has_copilot
end

-- Налаштування інтеграції з існуючим Copilot
function M.setup_copilot_integration()
    local has_copilot = M.check_copilot_integration()
    
    if has_copilot and M.current.behavior.disable_copilot_when_active then
        -- Можемо тимчасово відключити Copilot коли активний наш чат
        vim.g.nvim_agent_copilot_integration = true
        
        -- Додаємо автокоманди для керування Copilot
        vim.api.nvim_create_autocmd("User", {
            pattern = "NvimAgentChatOpened",
            callback = function()
                if vim.fn.exists(":Copilot") == 2 then
                    vim.cmd("Copilot disable")
                end
            end
        })
        
        vim.api.nvim_create_autocmd("User", {
            pattern = "NvimAgentChatClosed", 
            callback = function()
                if vim.fn.exists(":Copilot") == 2 then
                    vim.cmd("Copilot enable")
                end
            end
        })
    end
    
    return has_copilot
end

return M