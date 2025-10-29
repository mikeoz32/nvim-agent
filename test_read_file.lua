-- Тест для перевірки read_file з великими файлами

-- Створюємо великий тестовий файл
local test_file = "test_large_file.txt"
local file = io.open(test_file, "w")

for i = 1, 1000 do
    file:write("Line " .. i .. ": This is a test line with some content\n")
end
file:close()

-- Тестуємо read_file
print("Created test file with 1000 lines")

-- Ініціалізуємо nvim-agent
vim.g.mapleader = " "
vim.opt.rtp:append(".")
require('nvim-agent').setup({
    api = {
        provider = "github-copilot",
        model = "gpt-4o",
    }
})

-- Отримуємо MCP інструменти
local mcp = require('nvim-agent.mcp')
local tools = mcp.get_tools()

-- Знаходимо read_file
local read_file_tool = nil
for _, tool in ipairs(tools) do
    if tool.name == "read_file" then
        read_file_tool = tool
        break
    end
end

if not read_file_tool then
    print("ERROR: read_file tool not found!")
    return
end

print("\nTesting read_file with small range (lines 1-10):")
local result1 = mcp.execute_tool("read_file", {
    path = test_file,
    start_line = 1,
    end_line = 10
})

if result1.success then
    print("✓ Success!")
    print("  Lines read: " .. result1.lines_read[1] .. "-" .. result1.lines_read[2])
    print("  Total lines: " .. result1.total_lines)
    print("  Has more after: " .. tostring(result1.has_more_after))
    print("  Content preview: " .. result1.content:sub(1, 100) .. "...")
else
    print("✗ Failed: " .. (result1.error or "unknown error"))
end

print("\nTesting read_file with middle range (lines 500-510):")
local result2 = mcp.execute_tool("read_file", {
    path = test_file,
    start_line = 500,
    end_line = 510
})

if result2.success then
    print("✓ Success!")
    print("  Lines read: " .. result2.lines_read[1] .. "-" .. result2.lines_read[2])
    print("  Has more before: " .. tostring(result2.has_more_before))
    print("  Has more after: " .. tostring(result2.has_more_after))
else
    print("✗ Failed: " .. (result2.error or "unknown error"))
end

print("\nTesting read_file with large range (lines 1-1000):")
local result3 = mcp.execute_tool("read_file", {
    path = test_file,
    start_line = 1,
    end_line = 1000
})

if result3.success then
    print("✓ Success! Can read all 1000 lines without ENAMETOOLONG")
    print("  Lines read: " .. result3.lines_read[1] .. "-" .. result3.lines_read[2])
    print("  Total lines: " .. result3.total_lines)
else
    print("✗ Failed: " .. (result3.error or "unknown error"))
end

-- Очищаємо
os.remove(test_file)
print("\nTest completed!")
