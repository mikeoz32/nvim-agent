#!/usr/bin/env -S nvim -l

-- Простий скрипт для перевірки синтаксису Lua файлів через Neovim
-- Використання: nvim -l tests/syntax_check.lua <file1.lua> <file2.lua> ...

local args = {...}

if #args == 0 then
    print("Usage: nvim -l tests/syntax_check.lua <file1.lua> [file2.lua] ...")
    os.exit(1)
end

local has_errors = false

for _, filepath in ipairs(args) do
    -- Читаємо файл
    local file = io.open(filepath, "r")
    if not file then
        print(string.format("❌ Cannot open file: %s", filepath))
        has_errors = true
        goto continue
    end
    
    local content = file:read("*all")
    file:close()
    
    -- Перевіряємо синтаксис
    local func, err = loadstring(content, filepath)
    
    if func then
        print(string.format("✅ %s - OK", filepath))
    else
        print(string.format("❌ %s - SYNTAX ERROR:", filepath))
        print(err)
        has_errors = true
    end
    
    ::continue::
end

if has_errors then
    print("\n❌ Found syntax errors!")
    os.exit(1)
else
    print("\n✅ All files OK!")
    os.exit(0)
end
