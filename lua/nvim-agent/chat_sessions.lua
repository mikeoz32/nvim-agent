-- Модуль для управління кількома чат-сесіями
local M = {}

local utils = require('nvim-agent.utils')

-- Список всіх чат-сесій
local sessions = {}
local current_session_id = nil
local next_session_id = 1

-- Створити нову сесію
function M.create_session(name)
    local session_id = "session_" .. next_session_id
    next_session_id = next_session_id + 1
    
    local config = require('nvim-agent.config')
    local cfg = config.get()
    
    sessions[session_id] = {
        id = session_id,
        name = name or ("Chat " .. next_session_id - 1),
        history = {},
        mode = cfg.behavior.default_mode or "ask", -- default mode з конфігу
        model = cfg.api.model or "gpt-4", -- default model
        created_at = os.time(),
        updated_at = os.time(),
    }
    
    -- Якщо це перша сесія, робимо її поточною
    if not current_session_id then
        current_session_id = session_id
    end
    
    M.save_sessions()
    return session_id
end

-- Отримати поточну сесію
function M.get_current_session()
    if not current_session_id or not sessions[current_session_id] then
        -- Створюємо першу сесію якщо немає
        current_session_id = M.create_session("Default Chat")
    end
    return sessions[current_session_id]
end

-- Отримати сесію за ID
function M.get_session(session_id)
    return sessions[session_id]
end

-- Отримати список всіх сесій
function M.list_sessions()
    local list = {}
    for id, session in pairs(sessions) do
        table.insert(list, {
            id = id,
            name = session.name,
            mode = session.mode,
            model = session.model,
            message_count = #session.history,
            created_at = session.created_at,
            updated_at = session.updated_at,
            is_current = id == current_session_id
        })
    end
    
    -- Сортуємо за часом оновлення (найновіші зверху)
    table.sort(list, function(a, b)
        return a.updated_at > b.updated_at
    end)
    
    return list
end

-- Перемкнутися на іншу сесію
function M.switch_session(session_id)
    if not sessions[session_id] then
        return false, "Сесія не знайдена: " .. session_id
    end
    
    current_session_id = session_id
    M.save_sessions()
    return true
end

-- Перемкнутися на іншу сесію
function M.switch_session(session_id)
    if not sessions[session_id] then
        return false, "Session not found"
    end
    
    current_session_id = session_id
    sessions[session_id].updated_at = os.time()
    M.save_sessions()
    return true
end

-- Видалити сесію
function M.delete_session(session_id)
    if not sessions[session_id] then
        return false, "Session not found"
    end
    
    -- Не можна видалити поточну сесію якщо вона єдина
    local session_count = 0
    for _ in pairs(sessions) do
        session_count = session_count + 1
    end
    
    if session_count == 1 then
        return false, "Cannot delete the last session"
    end
    
    -- Якщо видаляємо поточну сесію, переключаємося на іншу
    if session_id == current_session_id then
        for id, _ in pairs(sessions) do
            if id ~= session_id then
                current_session_id = id
                break
            end
        end
    end
    
    sessions[session_id] = nil
    M.save_sessions()
    return true
end

-- Перейменувати сесію
function M.rename_session(session_id, new_name)
    if not sessions[session_id] then
        return false, "Session not found"
    end
    
    sessions[session_id].name = new_name
    sessions[session_id].updated_at = os.time()
    M.save_sessions()
    return true
end

-- Отримати список всіх сесій
function M.get_all_sessions()
    local list = {}
    for id, session in pairs(sessions) do
        table.insert(list, {
            id = id,
            name = session.name,
            mode = session.mode,
            message_count = #session.history,
            created_at = session.created_at,
            updated_at = session.updated_at,
            is_current = id == current_session_id,
        })
    end
    
    -- Сортуємо за часом оновлення
    table.sort(list, function(a, b)
        return a.updated_at > b.updated_at
    end)
    
    return list
end

-- Очистити історію поточної сесії
function M.clear_current_session()
    local session = M.get_current_session()
    session.history = {}
    session.updated_at = os.time()
    M.save_sessions()
end

-- Додати повідомлення в поточну сесію
function M.add_message(message)
    local session = M.get_current_session()
    table.insert(session.history, message)
    session.updated_at = os.time()
    M.save_sessions()
end

-- Отримати історію поточної сесії
function M.get_history()
    local session = M.get_current_session()
    return session.history
end

-- Встановити режим для поточної сесії
function M.set_mode(mode)
    local session = M.get_current_session()
    session.mode = mode
    session.updated_at = os.time()
    M.save_sessions()
end

-- Отримати режим поточної сесії
function M.get_mode()
    local session = M.get_current_session()
    return session.mode
end

-- Встановити модель для поточної сесії
function M.set_model(model)
    local session = M.get_current_session()
    session.model = model
    session.updated_at = os.time()
    M.save_sessions()
end

-- Отримати модель поточної сесії
function M.get_model()
    local session = M.get_current_session()
    return session.model or require('nvim-agent.config').get().api.model or "gpt-4"
end

-- Отримати шлях до файлу сесій (специфічний для проекту)
local function get_sessions_file()
    -- Спробуємо знайти root проекту (git, package.json, Cargo.toml, etc)
    local cwd = vim.fn.getcwd()
    local root_markers = {'.git', 'package.json', 'Cargo.toml', 'go.mod', 'pyproject.toml', '.nvim-agent'}
    
    local project_root = nil
    for _, marker in ipairs(root_markers) do
        local marker_path = vim.fn.finddir(marker, cwd .. ';')
        if marker_path ~= '' then
            project_root = vim.fn.fnamemodify(marker_path, ':h')
            utils.log("debug", "Знайдено project root через " .. marker, { root = project_root })
            break
        end
        
        -- Також перевіряємо файли
        local marker_file = vim.fn.findfile(marker, cwd .. ';')
        if marker_file ~= '' then
            project_root = vim.fn.fnamemodify(marker_file, ':h')
            utils.log("debug", "Знайдено project root через файл " .. marker, { root = project_root })
            break
        end
    end
    
    if project_root then
        -- Зберігаємо в папці проекту: .nvim-agent/sessions.json
        local nvim_agent_dir = project_root .. '/.nvim-agent'
        vim.fn.mkdir(nvim_agent_dir, 'p')
        -- ВАЖЛИВО: Конвертуємо в абсолютний шлях
        local sessions_file = vim.fn.fnamemodify(nvim_agent_dir .. '/sessions.json', ':p')
        utils.log("info", "Використовую project-specific sessions", { file = sessions_file })
        return sessions_file
    else
        -- Fallback на глобальні чати якщо не в проекті
        utils.log("info", "Project root не знайдено, використовую глобальні сесії")
        return "chat_sessions.json"
    end
end

-- Зберегти всі сесії
function M.save_sessions()
    local data = {
        sessions = sessions,
        current_session_id = current_session_id,
        next_session_id = next_session_id,
    }
    
    local sessions_file = get_sessions_file()
    
    utils.log("info", "Зберігаю сесії", {
        file = sessions_file,
        sessions_count = vim.tbl_count(sessions)
    })
    utils.save_data(sessions_file, data)
end

-- Завантажити сесії
function M.load_sessions()
    local sessions_file = get_sessions_file()
    local data = utils.load_data(sessions_file, {
        sessions = {},
        current_session_id = nil,
        next_session_id = 1,
    })
    
    sessions = data.sessions or {}
    current_session_id = data.current_session_id
    next_session_id = data.next_session_id or 1
    
    -- Міграція старих сесій: додаємо model якщо його немає
    local config = require('nvim-agent.config')
    local default_model = config.get().api.model or "gpt-4"
    for _, session in pairs(sessions) do
        if not session.model then
            session.model = default_model
        end
    end
    
    -- Міграція: якщо немає сесій в проектному файлі, спробуємо завантажити глобальні
    if vim.tbl_isempty(sessions) and sessions_file ~= "chat_sessions.json" then
        local global_data = utils.load_data("chat_sessions.json", nil)
        if global_data and not vim.tbl_isempty(global_data.sessions or {}) then
            utils.log("info", "Міграція сесій з глобального файлу в проектний")
            sessions = global_data.sessions or {}
            current_session_id = global_data.current_session_id
            next_session_id = global_data.next_session_id or 1
            -- Зберігаємо в новому місці
            M.save_sessions()
        end
    end
    
    -- Якщо немає жодної сесії, створюємо дефолтну
    if vim.tbl_isempty(sessions) then
        M.create_session("Default Chat")
    end
end

-- Ініціалізація
function M.setup()
    M.load_sessions()
end

return M
