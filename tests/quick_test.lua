-- Швидкий тест для chat_nui.lua
-- Запуск: nvim -u tests/test_init.lua -l tests/quick_test.lua

print("🧪 Початок тестування chat_nui.lua")
print("=" .. string.rep("=", 50))

-- 1. Перевірка ініціалізації
print("\n✅ Тест 1: Ініціалізація модуля")
local ok, chat_nui = pcall(require, 'nvim-agent.ui.chat_nui')
if not ok then
    print("❌ FAILED: Не вдалося завантажити модуль")
    print("   Помилка: " .. tostring(chat_nui))
    os.exit(1)
end
print("   ✓ Модуль завантажено успішно")

-- 2. Перевірка функції init
print("\n✅ Тест 2: Виклик init()")
local init_ok, result = pcall(function() return chat_nui.init() end)
if not init_ok then
    print("❌ FAILED: Помилка при ініціалізації")
    print("   Помилка: " .. tostring(result))
    os.exit(1)
end
print("   ✓ init() виконано успішно")

-- 3. Перевірка наявності всіх API функцій
print("\n✅ Тест 3: Перевірка API функцій")
local required_functions = {
    "create_window",
    "show_input",
    "add_user_message",
    "add_ai_message",
    "add_system_message",
    "send_current_message",
    "get_current_input",
    "clear_input",
    "clear",
    "close",
    "is_open",
    "get_chat_buffer",
    "get_buffers",
    "scroll_to_bottom",
    "focus_input",
    "resize",
    "update_mode_indicator",
    "setup_markdown_rendering"
}

local missing = {}
for _, func_name in ipairs(required_functions) do
    if type(chat_nui[func_name]) ~= "function" then
        table.insert(missing, func_name)
    end
end

if #missing > 0 then
    print("❌ FAILED: Відсутні функції:")
    for _, name in ipairs(missing) do
        print("   - " .. name)
    end
    os.exit(1)
end
print("   ✓ Всі " .. #required_functions .. " функцій присутні")

-- 4. Перевірка створення вікна
print("\n✅ Тест 4: Створення вікна")
local create_ok, create_err = pcall(function()
    chat_nui.create_window()
end)

if not create_ok then
    print("❌ FAILED: Помилка при створенні вікна")
    print("   Помилка: " .. tostring(create_err))
    os.exit(1)
end
print("   ✓ Вікно створено успішно")

-- 5. Перевірка чи вікно відкрите
print("\n✅ Тест 5: Перевірка is_open()")
if not chat_nui.is_open() then
    print("❌ FAILED: Вікно повинно бути відкрите")
    os.exit(1)
end
print("   ✓ Вікно відкрите")

-- 6. Перевірка буфера
print("\n✅ Тест 6: Перевірка chat buffer")
local buf = chat_nui.get_chat_buffer()
if not buf or not vim.api.nvim_buf_is_valid(buf) then
    print("❌ FAILED: Невалідний chat buffer")
    os.exit(1)
end
print("   ✓ Chat buffer валідний (bufnr: " .. buf .. ")")

-- 7. Перевірка додавання повідомлень
print("\n✅ Тест 7: Додавання повідомлень")
local msg_ok, msg_err = pcall(function()
    chat_nui.add_user_message("Тестове повідомлення користувача")
    chat_nui.add_ai_message("Тестова відповідь AI")
    chat_nui.add_system_message("Тестове системне повідомлення")
end)

if not msg_ok then
    print("❌ FAILED: Помилка при додаванні повідомлень")
    print("   Помилка: " .. tostring(msg_err))
    os.exit(1)
end
print("   ✓ Повідомлення додано успішно")

-- 8. Перевірка очищення
print("\n✅ Тест 8: Очищення чату")
local clear_ok, clear_err = pcall(function()
    chat_nui.clear()
end)

if not clear_ok then
    print("❌ FAILED: Помилка при очищенні")
    print("   Помилка: " .. tostring(clear_err))
    os.exit(1)
end
print("   ✓ Чат очищено успішно")

-- 9. Перевірка закриття
print("\n✅ Тест 9: Закриття вікна")
local close_ok, close_err = pcall(function()
    chat_nui.close()
end)

if not close_ok then
    print("❌ FAILED: Помилка при закритті")
    print("   Помилка: " .. tostring(close_err))
    os.exit(1)
end
print("   ✓ Вікно закрито успішно")

-- 10. Перевірка чи вікно закрите
print("\n✅ Тест 10: Перевірка що вікно закрите")
if chat_nui.is_open() then
    print("❌ FAILED: Вікно повинно бути закрите")
    os.exit(1)
end
print("   ✓ Вікно закрите")

-- Підсумок
print("\n" .. string.rep("=", 50))
print("🎉 ВСІ ТЕСТИ ПРОЙШЛИ УСПІШНО!")
print("=" .. string.rep("=", 50))
print("\n✅ Готовність до production: 10/10 базових тестів")
print("📝 Наступний крок: Ручне тестування UI (tests/manual_test.md)")
