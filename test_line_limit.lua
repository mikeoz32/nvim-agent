-- Тест ограничения размера диапазона

vim.g.mapleader = " "
vim.opt.rtp:append(".")
require('nvim-agent').setup({
    api = {
        provider = "github-copilot",
        model = "gpt-4o",
    }
})

local mcp = require('nvim-agent.mcp')

-- Створюємо файл з багатьма строками
local test_file = "test_limit.txt"
local file = io.open(test_file, "w")
for i = 1, 2000 do
    file:write("Line " .. i .. "\n")
end
file:close()

print("Testing max line range limit (1000 lines):")

-- Тест 1: В межах ліміту
print("\n1. Trying to read 1000 lines (should succeed):")
local result1 = mcp.execute_tool("read_file", {
    path = test_file,
    start_line = 1,
    end_line = 1000
})
print("  Result: " .. (result1.success and "✓ Success" or "✗ Failed: " .. result1.error))

-- Тест 2: Перевищення ліміту
print("\n2. Trying to read 1001 lines (should fail):")
local result2 = mcp.execute_tool("read_file", {
    path = test_file,
    start_line = 1,
    end_line = 1001
})
print("  Result: " .. (result2.success and "✗ Should have failed!" or "✓ Failed as expected"))
if not result2.success then
    print("  Error: " .. result2.error)
end

-- Тест 3: Значно більше ліміту
print("\n3. Trying to read 2000 lines (should fail):")
local result3 = mcp.execute_tool("read_file", {
    path = test_file,
    start_line = 1,
    end_line = 2000
})
print("  Result: " .. (result3.success and "✗ Should have failed!" or "✓ Failed as expected"))
if not result3.success then
    print("  Error: " .. result3.error)
end

os.remove(test_file)
print("\nTest completed!")
