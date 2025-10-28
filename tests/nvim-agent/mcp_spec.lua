-- Тести для MCP tools
local config = require('nvim-agent.config')
local mcp = require('nvim-agent.mcp')

describe("mcp", function()
    before_each(function()
        -- Ініціалізуємо config та mcp
        config.setup({
            mcp = {
                enabled = true
            }
        })
        mcp.setup()
    end)
    
    describe("tools definition", function()
        it("повинен мати список інструментів", function()
            local tools = mcp.get_tools()
            assert.is_not_nil(tools)
            assert.is_table(tools)
            assert.is_true(#tools > 0)
        end)
        
        it("кожен інструмент повинен мати правильну структуру", function()
            local tools = mcp.get_tools()
            
            for _, tool in ipairs(tools) do
                assert.is_string(tool.name)
                assert.is_string(tool.description)
                assert.is_table(tool.parameters)
                assert.equals("object", tool.parameters.type)
                assert.is_function(tool.handler)
            end
        end)
        
        it("повинен конвертувати в OpenAI format", function()
            local openai_tools = mcp.get_tools_for_openai()
            assert.is_not_nil(openai_tools)
            assert.is_table(openai_tools)
            
            for _, tool in ipairs(openai_tools) do
                assert.is_string(tool.type)
                assert.equals("function", tool.type)
                assert.is_table(tool["function"])
                assert.is_string(tool["function"].name)
                assert.is_string(tool["function"].description)
                assert.is_table(tool["function"].parameters)
            end
        end)
    end)
    
    describe("execute_tool", function()
        -- Ці тести потребують реального файлового середовища
        pending("повинен виконувати get_project_structure", function()
            local result = mcp.execute_tool("get_project_structure", {
                max_depth = 2
            })
            
            assert.is_not_nil(result)
            assert.is_not_nil(result.success)
            assert.is_true(result.success)
            assert.is_not_nil(result.structure)
            assert.is_number(result.total_files)
            assert.is_number(result.total_dirs)
        end)
        
        it("повинен повертати помилку для неіснуючого інструменту", function()
            local result = mcp.execute_tool("nonexistent_tool", {})
            
            assert.is_not_nil(result)
            assert.is_not_nil(result.error)
            assert.is_string(result.error)
        end)
        
        pending("повинен виконувати grep_search", function()
            -- Створюємо тестовий файл
            local test_file = vim.fn.tempname()
            vim.fn.writefile({"function test()", "  return 42", "end"}, test_file)
            
            local result = mcp.execute_tool("grep_search", {
                pattern = "function",
                paths = {test_file}
            })
            
            assert.is_not_nil(result)
            assert.is_not_nil(result.success)
            assert.is_true(result.success)
            assert.is_number(result.total_matches)
            assert.is_true(result.total_matches > 0)
            
            -- Cleanup
            vim.fn.delete(test_file)
        end)
    end)
    
    describe("handle_tool_calls", function()
        it("повинен обробляти tool calls від API", function()
            local tool_calls = {
                {
                    id = "call_test123",
                    type = "function",
                    ["function"] = {
                        name = "get_project_structure",
                        arguments = vim.json.encode({max_depth = 1})
                    }
                }
            }
            
            local callback_called = false
            local results = nil
            
            mcp.handle_tool_calls(tool_calls, function(tool_results)
                callback_called = true
                results = tool_results
            end)
            
            -- Чекаємо виконання (асинхронно)
            vim.wait(1000, function()
                return callback_called
            end)
            
            assert.is_true(callback_called)
            assert.is_not_nil(results)
            assert.equals(1, #results)
            
            local result = results[1]
            assert.equals("tool", result.role)
            assert.equals("call_test123", result.tool_call_id)
            assert.is_string(result.content)
            
            -- Перевіряємо що content є валідним JSON
            local ok, parsed = pcall(vim.json.decode, result.content)
            assert.is_true(ok)
            assert.is_table(parsed)
        end)
    end)
end)
