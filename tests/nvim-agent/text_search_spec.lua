local config = require('nvim-agent.config')
local mcp = require('nvim-agent.mcp')

describe("text_search", function()
    before_each(function()
        -- Ініціалізуємо config та mcp
        config.setup({
            mcp = {
                enabled = true
            }
        })
        mcp.setup()
    end)
    
    it("повинен знайти text_search інструмент", function()
        local tools = mcp.get_tools()
        local text_search_tool = nil
        
        for _, tool in ipairs(tools) do
            if tool.name == "text_search" then
                text_search_tool = tool
                break
            end
        end
        
        assert.is_not_nil(text_search_tool, "text_search tool not found")
        assert.equals("text_search", text_search_tool.name)
    end)
    
    it("повинен мати правильну структуру параметрів", function()
        local tools = mcp.get_tools()
        local text_search_tool = nil
        
        for _, tool in ipairs(tools) do
            if tool.name == "text_search" then
                text_search_tool = tool
                break
            end
        end
        
        assert.is_not_nil(text_search_tool.parameters)
        assert.is_not_nil(text_search_tool.parameters.properties)
        assert.is_not_nil(text_search_tool.parameters.properties.query)
        assert.is_not_nil(text_search_tool.parameters.properties.isRegexp)
        assert.is_not_nil(text_search_tool.parameters.properties.includePattern)
        assert.is_not_nil(text_search_tool.parameters.properties.maxResults)
        
        -- Перевіряємо required parameters
        local required = text_search_tool.parameters.required
        assert.is_not_nil(required)
        assert.is_true(vim.tbl_contains(required, "query"))
        assert.is_true(vim.tbl_contains(required, "isRegexp"))
    end)
    
    it("повинен шукати простий текст", function()
        -- Створюємо тестовий файл
        local test_file = vim.fn.tempname() .. ".lua"
        vim.fn.writefile({
            "local function test_function()",
            "    print('Hello World')",
            "end",
            "",
            "local function another_test()",
            "    print('Goodbye')",
            "end"
        }, test_file)
        
        -- Шукаємо "test"
        local result = mcp.execute_tool("text_search", {
            query = "test",
            isRegexp = false,
            includePattern = test_file
        })
        
        assert.is_not_nil(result)
        assert.is_true(result.success)
        -- Має знайти принаймні одне входження
        assert.is_true(result.count >= 1, "Expected at least 1 match, got " .. result.count)
        
        -- Прибираємо тестовий файл
        vim.fn.delete(test_file)
    end)
    
    it("повинен шукати з regex pattern", function()
        -- Створюємо тестовий файл з різними ключовими словами
        local test_file = vim.fn.tempname() .. ".lua"
        vim.fn.writefile({
            "function myFunction()",
            "    return 42",
            "end",
            "",
            "local method = function()",
            "    return true",
            "end",
            "",
            "procedure = {",
            "    run = function() end",
            "}"
        }, test_file)
        
        -- Шукаємо function|method|procedure (стандартний regex синтаксис для ripgrep)
        local result = mcp.execute_tool("text_search", {
            query = "function|method|procedure",
            isRegexp = true,
            includePattern = test_file
        })
        
        assert.is_not_nil(result)
        assert.is_true(result.success)
        -- Має знайти хоча б одне входження
        assert.is_true(result.count >= 1, "Expected at least 1 match, got " .. result.count)
        
        -- Прибираємо тестовий файл
        vim.fn.delete(test_file)
    end)
    
    it("повинен обмежувати результати maxResults", function()
        -- Створюємо файл з багатьма входженнями
        local test_file = vim.fn.tempname() .. ".lua"
        local lines = {}
        for i = 1, 100 do
            table.insert(lines, "local test_" .. i .. " = 'test'")
        end
        vim.fn.writefile(lines, test_file)
        
        -- Шукаємо з обмеженням 5 результатів
        local result = mcp.execute_tool("text_search", {
            query = "test",
            isRegexp = false,
            includePattern = test_file,
            maxResults = 5
        })
        
        assert.is_not_nil(result)
        assert.is_true(result.success)
        assert.equals(5, result.count)
        assert.is_true(result.truncated)
        
        -- Прибираємо тестовий файл
        vim.fn.delete(test_file)
    end)
    
    it("повинен повертати правильну структуру результатів", function()
        local test_file = vim.fn.tempname() .. ".lua"
        vim.fn.writefile({
            "-- Test comment",
            "local x = 1"
        }, test_file)
        
        local result = mcp.execute_tool("text_search", {
            query = "Test",
            isRegexp = false,
            includePattern = test_file
        })
        
        assert.is_not_nil(result)
        assert.is_true(result.success)
        assert.is_not_nil(result.matches)
        assert.is_not_nil(result.count)
        assert.is_not_nil(result.total)
        assert.is_not_nil(result.query)
        assert.is_not_nil(result.isRegexp)
        assert.is_not_nil(result.includePattern)
        
        if result.count > 0 then
            local match = result.matches[1]
            assert.is_not_nil(match.file)
            assert.is_not_nil(match.line)
            assert.is_not_nil(match.column)
            assert.is_not_nil(match.text)
        end
        
        vim.fn.delete(test_file)
    end)
end)
