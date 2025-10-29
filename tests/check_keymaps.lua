-- Скрипт для перевірки встановлених кеймапів
-- Запуск: nvim -u tests/test_init.lua -c "luafile tests/check_keymaps.lua"

print("\n=== Перевірка кеймапів nvim-agent ===\n")

-- Перевіряємо leader key
print("Leader key: '" .. vim.g.mapleader .. "'")
print("")

-- Отримуємо всі кеймапи для normal mode
local keymaps = vim.api.nvim_get_keymap('n')

-- Шукаємо кеймапи nvim-agent
local found = false
for _, map in ipairs(keymaps) do
    if map.lhs:match("^" .. vim.g.mapleader) then
        if map.desc and (map.desc:match("nvim%-agent") or map.desc:match("чат") or map.desc:match("код")) then
            print(string.format("  %s -> %s", map.lhs, map.desc or "no description"))
            found = true
        end
    end
end

if not found then
    print("  ❌ Кеймапи nvim-agent не знайдено!")
    print("\n  Спроба встановити кеймапи вручну...")
    require('nvim-agent.commands').setup_keymaps()
    print("  ✅ Кеймапи встановлено вручну")
    print("\n  Спробуйте ще раз:")
    
    keymaps = vim.api.nvim_get_keymap('n')
    for _, map in ipairs(keymaps) do
        if map.lhs:match("^" .. vim.g.mapleader) then
            if map.desc and (map.desc:match("nvim%-agent") or map.desc:match("чат") or map.desc:match("код")) then
                print(string.format("  %s -> %s", map.lhs, map.desc or "no description"))
            end
        end
    end
else
    print("\n  ✅ Кеймапи встановлено успішно!")
end

print("\n=================================\n")
