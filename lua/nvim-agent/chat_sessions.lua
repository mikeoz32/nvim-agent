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
    
    sessions[session_id] = {
        id = session_id,
        name = name or ("Chat " .. next_session_id - 1),
        history = {},
        mode = "ask", -- default mode
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

-- Зберегти всі сесії
function M.save_sessions()
    local data = {
        sessions = sessions,
        current_session_id = current_session_id,
        next_session_id = next_session_id,
    }
    
    utils.save_data("chat_sessions.json", data)
end

-- Завантажити сесії
function M.load_sessions()
    local data = utils.load_data("chat_sessions.json", {
        sessions = {},
        current_session_id = nil,
        next_session_id = 1,
    })
    
    sessions = data.sessions or {}
    current_session_id = data.current_session_id
    next_session_id = data.next_session_id or 1
    
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
