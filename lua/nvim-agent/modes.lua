-- Модуль режимів роботи для nvim-agent
-- Реалізує Agent, Edit та Ask режими як в VS Code Copilot Chat

local M = {}

local utils = require('nvim-agent.utils')

-- Доступні режими
M.MODES = {
    AGENT = "agent",    -- Автономна робота, може виконувати багато дій
    EDIT = "edit",      -- Редагування коду з прямою заміною
    ASK = "ask"         -- Просто відповіді без змін коду
}

-- Поточний режим
local current_mode = M.MODES.ASK  -- За замовчуванням Ask режим

-- Опис режимів
M.mode_descriptions = {
    [M.MODES.AGENT] = {
        name = "🤖 Agent",
        description = "Автономний режим - AI може самостійно виконувати задачі, змінювати файли, виконувати команди",
        prompt_suffix = [[

Ти працюєш в автономному режимі Agent. Можеш самостійно вносити зміни в код, виконувати команди та вирішувати задачі.

У тебе є доступ до наступних MCP tools (Model Context Protocol):

📁 Робота з файлами:
- read_file - читання вмісту файлу. ЗАВЖДИ вказуй start_line та end_line (нумерація з 1). Якщо потрібно більше, викликай знову. Читай великими діапазонами (100-300 рядків).
- write_file - створення або оновлення файлу
- find_files - пошук файлів по паттерну (glob)
- open_file - відкрити файл в буфері

🔍 Пошук та аналіз:
- text_search - швидкий текстовий пошук (exact string або regex). Використовуй regex з alternation (function|method|procedure) для пошуку кількох варіантів одразу. includePattern для фільтрації файлів.
- grep_search - швидкий текстовий пошук в проекті (regex підтримка)
- get_project_structure - отримати структуру проекту (дерево файлів/директорій)
- get_project_context - аналіз проекту (залежності, мова, фреймворки)
- get_diagnostics - помилки та попередження в коді
- goto_definition, find_references - навігація по коду

💻 Виконання:
- execute_shell - виконання shell команд
- execute_command - виконання Neovim команд
- format_code - форматування коду

🔧 Редагування:
- insert_text, delete_lines, replace_text - маніпуляції з текстом
- list_buffers, create_buffer, save_buffer - робота з буферами

🌳 Treesitter:
- get_treesitter_nodes - аналіз AST дерева

Ти можеш самостійно викликати ці інструменти для виконання задач. Наприклад:
- Якщо питають про проект - використай get_project_structure або get_project_context
- Якщо треба знайти щось у коді - використай text_search (підтримує regex з alternation: 'function|method|procedure')
- Якщо треба переглянути файл - використай text_search з includePattern для конкретного файлу (швидше ніж багато read_file)
- Якщо треба прочитати файл - ЗАВЖДИ вказуй start_line та end_line (це обов'язкові параметри). Читай частинами для великих файлів.
- Якщо треба відредагувати - використай write_file або replace_text

ВАЖЛИВО: 
1. text_search - ефективний для огляду коду. Використовуй regex patterns з | для пошуку кількох варіантів одразу.
2. read_file ЗАВЖДИ вимагає start_line та end_line:
   - Подивись розмір файлу (get_project_structure покаже кількість рядків)
   - ЗАВЖДИ вказуй діапазон: read_file з start_line=1, end_line=200, потім start_line=201, end_line=400, тощо
   - Результат містить has_more_after=true якщо є ще рядки, has_more_before=true якщо є попередні

Завжди намагайся самостійно отримати необхідну інформацію через tools перед тим як відповісти.
]],
        capabilities = {
            can_edit_files = true,
            can_create_files = true,
            can_run_commands = true,
            can_suggest_changes = true,
            auto_apply_changes = true
        }
    },
    [M.MODES.EDIT] = {
        name = "✏️  Edit", 
        description = "Режим редагування - AI пропонує зміни які одразу застосовуються до коду",
        prompt_suffix = "\n\nТи працюєш в режимі редагування. Пропонуй конкретні зміни коду які можна одразу застосувати.",
        capabilities = {
            can_edit_files = true,
            can_create_files = false,
            can_run_commands = false,
            can_suggest_changes = true,
            auto_apply_changes = true
        }
    },
    [M.MODES.ASK] = {
        name = "💬 Ask",
        description = "Режим запитань - AI тільки відповідає на питання без змін коду",
        prompt_suffix = "\n\nТи працюєш в режимі запитань. Надавай інформативні відповіді та поради, але не вноси зміни в код без підтвердження.",
        capabilities = {
            can_edit_files = false,
            can_create_files = false,
            can_run_commands = false,
            can_suggest_changes = true,
            auto_apply_changes = false
        }
    }
}

-- Встановити поточний режим
function M.set_mode(mode)
    if not M.mode_descriptions[mode] then
        return false, "Невідомий режим: " .. mode
    end
    
    current_mode = mode
    
    utils.log("info", "Режим змінено", {
        mode = mode,
        name = M.mode_descriptions[mode].name
    })
    
    return true, M.mode_descriptions[mode].name
end

-- Отримати поточний режим
function M.get_mode()
    return current_mode
end

-- Alias для зручності
M.get_current_mode = M.get_mode

-- Отримати інформацію про режим
function M.get_mode_info(mode)
    mode = mode or current_mode
    return M.mode_descriptions[mode]
end

-- Перевірити чи дозволена дія в поточному режимі
function M.can_perform(action)
    local mode_info = M.get_mode_info()
    if not mode_info then
        return false
    end
    
    return mode_info.capabilities[action] == true
end

-- Отримати промпт-суфікс для режиму
function M.get_prompt_suffix(mode)
    mode = mode or current_mode
    local mode_info = M.mode_descriptions[mode]
    return mode_info and mode_info.prompt_suffix or ""
end

-- Циклічне переключення режимів
function M.cycle_mode()
    local modes = {M.MODES.ASK, M.MODES.EDIT, M.MODES.AGENT}
    
    for i, mode in ipairs(modes) do
        if mode == current_mode then
            local next_mode = modes[(i % #modes) + 1]
            return M.set_mode(next_mode)
        end
    end
    
    return M.set_mode(M.MODES.ASK)
end

-- Отримати список всіх режимів
function M.get_all_modes()
    return {
        {
            id = M.MODES.ASK,
            name = M.mode_descriptions[M.MODES.ASK].name,
            description = M.mode_descriptions[M.MODES.ASK].description,
            current = current_mode == M.MODES.ASK
        },
        {
            id = M.MODES.EDIT,
            name = M.mode_descriptions[M.MODES.EDIT].name,
            description = M.mode_descriptions[M.MODES.EDIT].description,
            current = current_mode == M.MODES.EDIT
        },
        {
            id = M.MODES.AGENT,
            name = M.mode_descriptions[M.MODES.AGENT].name,
            description = M.mode_descriptions[M.MODES.AGENT].description,
            current = current_mode == M.MODES.AGENT
        }
    }
end

-- Обробка відповіді AI в залежності від режиму
function M.process_response(response, context)
    local mode = current_mode
    local mode_info = M.get_mode_info(mode)
    
    if not mode_info then
        return response, {}
    end
    
    local result = {
        response = response,
        actions = {},
        can_auto_apply = mode_info.capabilities.auto_apply_changes
    }
    
    -- В режимі Agent або Edit витягуємо код блоки для застосування
    if mode == M.MODES.AGENT or mode == M.MODES.EDIT then
        local code_blocks = utils.extract_code_blocks(response)
        
        for _, block in ipairs(code_blocks) do
            table.insert(result.actions, {
                type = "code_change",
                language = block.language,
                code = block.code,
                auto_apply = mode_info.capabilities.auto_apply_changes
            })
        end
    end
    
    -- В режимі Agent також шукаємо команди для виконання
    if mode == M.MODES.AGENT then
        -- Шукаємо команди в форматі :command або `command`
        for cmd in response:gmatch("`([^`]+)`") do
            if cmd:match("^%s*:") or cmd:match("^%s*!") then
                table.insert(result.actions, {
                    type = "vim_command",
                    command = cmd,
                    auto_apply = false  -- Команди не виконуємо автоматично
                })
            end
        end
    end
    
    return result
end

-- Форматування відображення режиму для UI
function M.format_mode_display(mode)
    mode = mode or current_mode
    local mode_info = M.mode_descriptions[mode]
    
    if not mode_info then
        return "Unknown"
    end
    
    return mode_info.name
end

-- Отримати підказку для поточного режиму
function M.get_mode_help()
    local mode_info = M.get_mode_info()
    if not mode_info then
        return "Режим не встановлено"
    end
    
    local help = string.format(
        "%s\n%s\n\nМожливості:\n",
        mode_info.name,
        mode_info.description
    )
    
    local caps = mode_info.capabilities
    help = help .. string.format("• Редагування файлів: %s\n", caps.can_edit_files and "✓" or "✗")
    help = help .. string.format("• Створення файлів: %s\n", caps.can_create_files and "✓" or "✗")
    help = help .. string.format("• Виконання команд: %s\n", caps.can_run_commands and "✓" or "✗")
    help = help .. string.format("• Автозастосування змін: %s\n", caps.auto_apply_changes and "✓" or "✗")
    
    return help
end

-- Валідація дії в поточному режимі
function M.validate_action(action_type)
    local mode_info = M.get_mode_info()
    if not mode_info then
        return false, "Режим не встановлено"
    end
    
    local action_map = {
        edit_file = "can_edit_files",
        create_file = "can_create_files",
        run_command = "can_run_commands",
        suggest_change = "can_suggest_changes"
    }
    
    local capability = action_map[action_type]
    if not capability then
        return false, "Невідомий тип дії: " .. action_type
    end
    
    if not mode_info.capabilities[capability] then
        return false, string.format(
            "Дія '%s' недоступна в режимі %s",
            action_type,
            mode_info.name
        )
    end
    
    return true
end

-- Ініціалізація модуля
function M.setup(config)
    -- Встановлюємо режим за замовчуванням з конфігурації
    if config and config.default_mode then
        M.set_mode(config.default_mode)
    end
    
    return true
end

return M
