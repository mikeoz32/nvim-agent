-- Швидка перевірка синтаксису без завантаження модулів
local filepath = arg[1]

if not filepath then
    print("Usage: lua tests/quick_syntax_check.lua <file.lua>")
    os.exit(1)
end

local file = io.open(filepath, "r")
if not file then
    print("❌ Cannot open file: " .. filepath)
    os.exit(1)
end

local content = file:read("*all")
file:close()

-- Перевіряємо синтаксис
local func, err = loadstring(content, filepath)

if func then
    print("✅ " .. filepath .. " - Syntax OK")
    os.exit(0)
else
    print("❌ " .. filepath .. " - SYNTAX ERROR:")
    print(err)
    os.exit(1)
end
