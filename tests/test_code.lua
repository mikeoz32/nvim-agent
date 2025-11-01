-- Тестовий файл для візуального тестування chat_nui
-- Цей файл можна використовувати для перевірки різних сценаріїв

local M = {}

-- Приклад коду для тестування Edit режиму
function M.example_function()
    local result = 0
    for i = 1, 10 do
        result = result + i
    end
    return result
end

-- Приклад з помилкою для тестування виправлення
function M.buggy_function(data)
    -- Тут немає перевірки на nil
    return data.value * 2
end

-- Приклад складної функції для рефакторингу
function M.complex_function(a, b, c, d, e)
    if a > 0 then
        if b > 0 then
            if c > 0 then
                if d > 0 then
                    if e > 0 then
                        return a + b + c + d + e
                    end
                end
            end
        end
    end
    return 0
end

-- Приклад для генерації документації
function M.undocumented_function(name, age, city)
    return {
        name = name,
        age = age,
        city = city,
        created_at = os.date("%Y-%m-%d")
    }
end

return M
