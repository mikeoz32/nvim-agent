-- Model Context Protocol (MCP) модуль для nvim-agent
-- Надає AI доступ до інструментів та ресурсів Neovim

local M = {}

local utils = require('nvim-agent.utils')
local config = require('nvim-agent.config')
local change_manager = require('nvim-agent.change_manager')

-- Прапорець для режиму review (чи потрібен перегляд змін)
M.review_mode = false

-- Допоміжні функції
M.format_file_size = function(bytes)
    if bytes < 1024 then
        return bytes .. "B"
    elseif bytes < 1024 * 1024 then
        return string.format("%.1fKB", bytes / 1024)
    else
        return string.format("%.1fMB", bytes / 1024 / 1024)
    end
end

-- Реєстр доступних інструментів
local tools = {}
local external_servers = {}

-- Базові Neovim інструменти
M.neovim_tools = {
    -- Читання файлів
    {
        name = "read_file",
        description = "Читає вміст файлу. Для великих файлів (>200 рядків) ОБОВ'ЯЗКОВО використовуй параметри start_line/end_line щоб читати частинами. Спочатку дізнайся розмір через get_project_structure або grep_search з count, потім читай по частинах (наприклад, по 100-200 рядків).",
        parameters = {
            type = "object",
            properties = {
                path = {
                    type = "string",
                    description = "Шлях до файлу (відносний або абсолютний)"
                },
                start_line = {
                    type = "number",
                    description = "Початкова лінія (1-based). Використовуй для читання великих файлів частинами."
                },
                end_line = {
                    type = "number",
                    description = "Кінцева лінія (включно). Використовуй для читання великих файлів частинами."
                }
            },
            required = {"path"}
        },
        handler = function(params)
            local path = params.path
            if not vim.fn.filereadable(path) == 1 then
                return {error = "Файл не знайдено або недоступний: " .. path}
            end
            
            local lines = vim.fn.readfile(path)
            local total_lines = #lines
            local start_line = params.start_line or 1
            local end_line = params.end_line or total_lines
            
            -- Попередження якщо намагаються прочитати весь великий файл
            if not params.start_line and not params.end_line and total_lines > 200 then
                return {
                    error = "Файл занадто великий (" .. total_lines .. " рядків). Використай start_line та end_line для читання частинами (наприклад, 1-200, 201-400, тощо).",
                    total_lines = total_lines,
                    suggestion = "Спочатку прочитай перші 200 рядків: start_line=1, end_line=200"
                }
            end
            
            local content = {}
            for i = start_line, math.min(end_line, total_lines) do
                table.insert(content, lines[i])
            end
            
            return {
                success = true,
                content = table.concat(content, "\n"),
                lines = {start_line, math.min(end_line, total_lines)},
                total_lines = total_lines,
                has_more = end_line < total_lines
            }
        end
    },
    
    -- Запис файлів
    {
        name = "write_file",
        description = "Записує або оновлює вміст файлу.",
        parameters = {
            type = "object",
            properties = {
                path = {
                    type = "string",
                    description = "Шлях до файлу"
                },
                content = {
                    type = "string",
                    description = "Вміст для запису"
                },
                create_dirs = {
                    type = "boolean",
                    description = "Створити директорії якщо не існують"
                }
            },
            required = {"path", "content"}
        },
        handler = function(params)
            local path = params.path
            local content = params.content
            
            -- Перевіряємо чи файл існує
            local file_exists = vim.fn.filereadable(path) == 1
            
            -- Створюємо зміну
            local change_type = file_exists and 
                change_manager.CHANGE_TYPE.FILE_MODIFY or 
                change_manager.CHANGE_TYPE.FILE_CREATE
            
            local change = change_manager.create_change(change_type, {
                path = path,
                content = content,
                create_dirs = params.create_dirs
            })
            
            -- Якщо review mode увімкнено, додаємо до стеку
            if M.review_mode then
                change_manager.add_change(change)
                return {
                    success = true,
                    path = path,
                    lines_written = #vim.split(content, "\n"),
                    pending_review = true,
                    change_id = change.id
                }
            end
            
            -- Інакше застосовуємо одразу
            -- Створюємо директорії якщо потрібно
            if params.create_dirs then
                local dir = vim.fn.fnamemodify(path, ":h")
                if vim.fn.isdirectory(dir) == 0 then
                    vim.fn.mkdir(dir, "p")
                end
            end
            
            -- Записуємо файл
            local lines = vim.split(content, "\n")
            local success = pcall(vim.fn.writefile, lines, path)
            
            if success then
                return {
                    success = true,
                    path = path,
                    lines_written = #lines
                }
            else
                return {error = "Не вдалося записати файл: " .. path}
            end
        end
    },
    
    -- Пошук файлів
    {
        name = "find_files",
        description = "Шукає файли за патерном в робочій директорії.",
        parameters = {
            type = "object",
            properties = {
                pattern = {
                    type = "string",
                    description = "Glob патерн для пошуку (наприклад, '**/*.lua')"
                },
                max_results = {
                    type = "number",
                    description = "Максимальна кількість результатів (за замовчуванням 100)"
                }
            },
            required = {"pattern"}
        },
        handler = function(params)
            local pattern = params.pattern
            local max_results = params.max_results or 100
            
            -- Використовуємо vim.fn.glob для пошуку
            local files = vim.fn.glob(pattern, false, true)
            
            -- Обмежуємо результати
            if #files > max_results then
                files = vim.list_slice(files, 1, max_results)
            end
            
            return {
                success = true,
                files = files,
                count = #files,
                truncated = #files >= max_results
            }
        end
    },
    
    -- Виконання команд Neovim
    {
        name = "execute_command",
        description = "Виконує команду Neovim (Ex команда).",
        parameters = {
            type = "object",
            properties = {
                command = {
                    type = "string",
                    description = "Команда для виконання (без префікса ':')"
                }
            },
            required = {"command"}
        },
        handler = function(params)
            local cmd = params.command
            
            local success, result = pcall(vim.cmd, cmd)
            
            if success then
                return {
                    success = true,
                    command = cmd,
                    output = result or "Команду виконано"
                }
            else
                return {
                    error = "Помилка виконання: " .. tostring(result)
                }
            end
        end
    },
    
    -- Пошук тексту в файлах
    {
        name = "grep_search",
        description = "Шукає текст у файлах робочої директорії.",
        parameters = {
            type = "object",
            properties = {
                query = {
                    type = "string",
                    description = "Текст для пошуку"
                },
                file_pattern = {
                    type = "string",
                    description = "Патерн файлів для пошуку (опціонально)"
                },
                max_results = {
                    type = "number",
                    description = "Максимальна кількість результатів"
                }
            },
            required = {"query"}
        },
        handler = function(params)
            local query = params.query
            local max_results = params.max_results or 50
            
            -- Використовуємо vimgrep
            local cmd = string.format("vimgrep /%s/gj **/*", vim.fn.escape(query, '/'))
            if params.file_pattern then
                cmd = string.format("vimgrep /%s/gj %s", vim.fn.escape(query, '/'), params.file_pattern)
            end
            
            local success, _ = pcall(vim.cmd, cmd)
            
            if not success then
                return {success = true, matches = {}, count = 0}
            end
            
            -- Отримуємо результати з quickfix
            local qflist = vim.fn.getqflist()
            local matches = {}
            
            for i, item in ipairs(qflist) do
                if i > max_results then break end
                
                table.insert(matches, {
                    file = vim.fn.bufname(item.bufnr),
                    line = item.lnum,
                    column = item.col,
                    text = item.text
                })
            end
            
            return {
                success = true,
                matches = matches,
                count = #matches,
                total = #qflist
            }
        end
    },
    
    -- Отримання інформації про буфери
    {
        name = "list_buffers",
        description = "Повертає список відкритих буферів.",
        parameters = {
            type = "object",
            properties = {
                only_modified = {
                    type = "boolean",
                    description = "Тільки змінені буфери"
                }
            }
        },
        handler = function(params)
            local buffers = {}
            
            for _, buf in ipairs(vim.api.nvim_list_bufs()) do
                if vim.api.nvim_buf_is_loaded(buf) then
                    local name = vim.api.nvim_buf_get_name(buf)
                    
                    -- Безпечне отримання modified статусу
                    local ok, modified = pcall(function()
                        return vim.api.nvim_get_option_value('modified', {buf = buf})
                    end)
                    
                    if not ok then
                        -- Fallback для старих версій Neovim
                        ok, modified = pcall(vim.api.nvim_buf_get_option, buf, 'modified')
                    end
                    
                    if not ok then
                        modified = false
                    end
                    
                    if not params.only_modified or modified then
                        table.insert(buffers, {
                            number = buf,
                            name = name,
                            modified = modified,
                            lines = vim.api.nvim_buf_line_count(buf)
                        })
                    end
                end
            end
            
            return {
                success = true,
                buffers = buffers,
                count = #buffers
            }
        end
    },
    
    -- Отримання діагностики LSP
    {
        name = "get_diagnostics",
        description = "Отримує діагностичні повідомлення (помилки, попередження) з LSP.",
        parameters = {
            type = "object",
            properties = {
                buffer = {
                    type = "number",
                    description = "Номер буфера (0 для поточного)"
                },
                severity = {
                    type = "string",
                    description = "Рівень серйозності: ERROR, WARN, INFO, HINT"
                }
            }
        },
        handler = function(params)
            local bufnr = params.buffer or 0
            if bufnr == 0 then
                bufnr = vim.api.nvim_get_current_buf()
            end
            
            local diagnostics = vim.diagnostic.get(bufnr)
            local result = {}
            
            local severity_map = {
                ERROR = vim.diagnostic.severity.ERROR,
                WARN = vim.diagnostic.severity.WARN,
                INFO = vim.diagnostic.severity.INFO,
                HINT = vim.diagnostic.severity.HINT
            }
            
            local filter_severity = params.severity and severity_map[params.severity]
            
            for _, diag in ipairs(diagnostics) do
                if not filter_severity or diag.severity == filter_severity then
                    table.insert(result, {
                        line = diag.lnum + 1,
                        column = diag.col + 1,
                        severity = vim.diagnostic.severity[diag.severity],
                        message = diag.message,
                        source = diag.source
                    })
                end
            end
            
            return {
                success = true,
                diagnostics = result,
                count = #result
            }
        end
    },
    
    -- LSP: Перехід до визначення
    {
        name = "goto_definition",
        description = "Знаходить визначення символу під курсором або за заданою позицією.",
        parameters = {
            type = "object",
            properties = {
                buffer = {
                    type = "number",
                    description = "Номер буфера (0 для поточного)"
                },
                line = {
                    type = "number",
                    description = "Номер рядка (1-indexed)"
                },
                column = {
                    type = "number",
                    description = "Номер колонки (1-indexed)"
                },
                symbol = {
                    type = "string",
                    description = "Назва символу для пошуку"
                }
            }
        },
        handler = function(params)
            local bufnr = params.buffer or 0
            if bufnr == 0 then
                bufnr = vim.api.nvim_get_current_buf()
            end
            
            -- Якщо передано символ, шукаємо його в буфері
            if params.symbol then
                local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
                for i, line in ipairs(lines) do
                    local col = line:find(params.symbol, 1, true)
                    if col then
                        params.line = i
                        params.column = col
                        break
                    end
                end
            end
            
            if not params.line or not params.column then
                return {error = "Не вказано позицію або символ не знайдено"}
            end
            
            -- Встановлюємо позицію курсора
            vim.api.nvim_win_set_cursor(0, {params.line, params.column - 1})
            
            -- Отримуємо визначення через LSP
            local result = {}
            local lsp_params = vim.lsp.util.make_position_params()
            
            local responses = vim.lsp.buf_request_sync(bufnr, 'textDocument/definition', lsp_params, 1000)
            
            if not responses or vim.tbl_isempty(responses) then
                return {error = "LSP визначення не знайдено"}
            end
            
            for _, response in pairs(responses) do
                if response.result then
                    local locations = vim.lsp.util.locations_to_items(response.result, 'utf-8')
                    for _, loc in ipairs(locations) do
                        table.insert(result, {
                            file = loc.filename,
                            line = loc.lnum,
                            column = loc.col,
                            text = loc.text
                        })
                    end
                end
            end
            
            return {
                success = true,
                definitions = result,
                count = #result
            }
        end
    },
    
    -- LSP: Пошук посилань
    {
        name = "find_references",
        description = "Знаходить всі посилання на символ.",
        parameters = {
            type = "object",
            properties = {
                buffer = {
                    type = "number",
                    description = "Номер буфера (0 для поточного)"
                },
                line = {
                    type = "number",
                    description = "Номер рядка"
                },
                column = {
                    type = "number",
                    description = "Номер колонки"
                },
                symbol = {
                    type = "string",
                    description = "Назва символу"
                },
                include_declaration = {
                    type = "boolean",
                    description = "Включити визначення символу"
                }
            }
        },
        handler = function(params)
            local bufnr = params.buffer or 0
            if bufnr == 0 then
                bufnr = vim.api.nvim_get_current_buf()
            end
            
            -- Шукаємо символ якщо передано
            if params.symbol then
                local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
                for i, line in ipairs(lines) do
                    local col = line:find(params.symbol, 1, true)
                    if col then
                        params.line = i
                        params.column = col
                        break
                    end
                end
            end
            
            if not params.line or not params.column then
                return {error = "Не вказано позицію або символ не знайдено"}
            end
            
            vim.api.nvim_win_set_cursor(0, {params.line, params.column - 1})
            
            local lsp_params = vim.lsp.util.make_position_params()
            lsp_params.context = {
                includeDeclaration = params.include_declaration or false
            }
            
            local result = {}
            local responses = vim.lsp.buf_request_sync(bufnr, 'textDocument/references', lsp_params, 2000)
            
            if not responses or vim.tbl_isempty(responses) then
                return {success = true, references = {}, count = 0}
            end
            
            for _, response in pairs(responses) do
                if response.result then
                    local locations = vim.lsp.util.locations_to_items(response.result, 'utf-8')
                    for _, loc in ipairs(locations) do
                        table.insert(result, {
                            file = loc.filename,
                            line = loc.lnum,
                            column = loc.col,
                            text = loc.text
                        })
                    end
                end
            end
            
            return {
                success = true,
                references = result,
                count = #result
            }
        end
    },
    
    -- LSP: Отримання сигнатури функції
    {
        name = "get_signature_help",
        description = "Отримує підказку про параметри функції.",
        parameters = {
            type = "object",
            properties = {
                buffer = {
                    type = "number",
                    description = "Номер буфера"
                },
                line = {
                    type = "number",
                    description = "Номер рядка"
                },
                column = {
                    type = "number",
                    description = "Номер колонки"
                }
            }
        },
        handler = function(params)
            local bufnr = params.buffer or 0
            if bufnr == 0 then
                bufnr = vim.api.nvim_get_current_buf()
            end
            
            if params.line and params.column then
                vim.api.nvim_win_set_cursor(0, {params.line, params.column - 1})
            end
            
            local lsp_params = vim.lsp.util.make_position_params()
            local responses = vim.lsp.buf_request_sync(bufnr, 'textDocument/signatureHelp', lsp_params, 1000)
            
            if not responses or vim.tbl_isempty(responses) then
                return {error = "Підказка про сигнатуру не доступна"}
            end
            
            local signatures = {}
            for _, response in pairs(responses) do
                if response.result and response.result.signatures then
                    for _, sig in ipairs(response.result.signatures) do
                        table.insert(signatures, {
                            label = sig.label,
                            documentation = sig.documentation and sig.documentation.value or "",
                            parameters = vim.tbl_map(function(p)
                                return {
                                    label = p.label,
                                    documentation = p.documentation and p.documentation.value or ""
                                }
                            end, sig.parameters or {})
                        })
                    end
                end
            end
            
            return {
                success = true,
                signatures = signatures,
                count = #signatures
            }
        end
    },
    
    -- LSP: Hover інформація
    {
        name = "get_hover_info",
        description = "Отримує документацію та інформацію про символ.",
        parameters = {
            type = "object",
            properties = {
                buffer = {
                    type = "number",
                    description = "Номер буфера"
                },
                line = {
                    type = "number",
                    description = "Номер рядка"
                },
                column = {
                    type = "number",
                    description = "Номер колонки"
                },
                symbol = {
                    type = "string",
                    description = "Назва символу"
                }
            }
        },
        handler = function(params)
            local bufnr = params.buffer or 0
            if bufnr == 0 then
                bufnr = vim.api.nvim_get_current_buf()
            end
            
            if params.symbol then
                local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
                for i, line in ipairs(lines) do
                    local col = line:find(params.symbol, 1, true)
                    if col then
                        params.line = i
                        params.column = col
                        break
                    end
                end
            end
            
            if params.line and params.column then
                vim.api.nvim_win_set_cursor(0, {params.line, params.column - 1})
            end
            
            local lsp_params = vim.lsp.util.make_position_params()
            local responses = vim.lsp.buf_request_sync(bufnr, 'textDocument/hover', lsp_params, 1000)
            
            if not responses or vim.tbl_isempty(responses) then
                return {error = "Hover інформація не доступна"}
            end
            
            local hover_info = {}
            for _, response in pairs(responses) do
                if response.result and response.result.contents then
                    local contents = response.result.contents
                    if type(contents) == "table" then
                        if contents.value then
                            table.insert(hover_info, contents.value)
                        else
                            for _, item in ipairs(contents) do
                                if type(item) == "string" then
                                    table.insert(hover_info, item)
                                elseif item.value then
                                    table.insert(hover_info, item.value)
                                end
                            end
                        end
                    else
                        table.insert(hover_info, contents)
                    end
                end
            end
            
            return {
                success = true,
                hover_info = table.concat(hover_info, "\n\n")
            }
        end
    },
    
    -- LSP: Список символів у документі
    {
        name = "get_document_symbols",
        description = "Отримує список всіх символів (функції, класи, змінні) у документі.",
        parameters = {
            type = "object",
            properties = {
                buffer = {
                    type = "number",
                    description = "Номер буфера"
                },
                file = {
                    type = "string",
                    description = "Шлях до файлу"
                },
                kind = {
                    type = "string",
                    description = "Тип символів: Function, Class, Variable, Method тощо"
                }
            }
        },
        handler = function(params)
            local bufnr = params.buffer or 0
            
            -- Якщо вказано файл, відкриваємо його
            if params.file then
                local file_bufnr = vim.fn.bufnr(params.file)
                if file_bufnr == -1 then
                    -- Файл не відкритий, відкриваємо його
                    vim.cmd('badd ' .. params.file)
                    file_bufnr = vim.fn.bufnr(params.file)
                end
                bufnr = file_bufnr
            end
            
            if bufnr == 0 then
                bufnr = vim.api.nvim_get_current_buf()
            end
            
            local lsp_params = {textDocument = vim.lsp.util.make_text_document_params(bufnr)}
            local responses = vim.lsp.buf_request_sync(bufnr, 'textDocument/documentSymbol', lsp_params, 2000)
            
            if not responses or vim.tbl_isempty(responses) then
                return {success = true, symbols = {}, count = 0}
            end
            
            local symbols = {}
            local kind_filter = params.kind
            
            local function process_symbol(symbol, parent_name)
                local kind_name = vim.lsp.protocol.SymbolKind[symbol.kind] or "Unknown"
                
                if not kind_filter or kind_name == kind_filter then
                    local full_name = parent_name and (parent_name .. "." .. symbol.name) or symbol.name
                    
                    table.insert(symbols, {
                        name = full_name,
                        kind = kind_name,
                        line = symbol.location and symbol.location.range.start.line + 1 or 
                               symbol.range and symbol.range.start.line + 1 or 0,
                        detail = symbol.detail
                    })
                end
                
                -- Рекурсивно обробляємо дочірні символи
                if symbol.children then
                    for _, child in ipairs(symbol.children) do
                        process_symbol(child, symbol.name)
                    end
                end
            end
            
            for _, response in pairs(responses) do
                if response.result then
                    for _, symbol in ipairs(response.result) do
                        process_symbol(symbol)
                    end
                end
            end
            
            return {
                success = true,
                symbols = symbols,
                count = #symbols
            }
        end
    },
    
    -- LSP: Перейменування символу
    {
        name = "rename_symbol",
        description = "Перейменовує символ у всіх місцях використання.",
        parameters = {
            type = "object",
            properties = {
                buffer = {
                    type = "number",
                    description = "Номер буфера"
                },
                line = {
                    type = "number",
                    description = "Номер рядка"
                },
                column = {
                    type = "number",
                    description = "Номер колонки"
                },
                old_name = {
                    type = "string",
                    description = "Стара назва символу"
                },
                new_name = {
                    type = "string",
                    description = "Нова назва символу"
                }
            },
            required = {"new_name"}
        },
        handler = function(params)
            local bufnr = params.buffer or 0
            if bufnr == 0 then
                bufnr = vim.api.nvim_get_current_buf()
            end
            
            if params.old_name then
                local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
                for i, line in ipairs(lines) do
                    local col = line:find(params.old_name, 1, true)
                    if col then
                        params.line = i
                        params.column = col
                        break
                    end
                end
            end
            
            if params.line and params.column then
                vim.api.nvim_win_set_cursor(0, {params.line, params.column - 1})
            end
            
            local lsp_params = vim.lsp.util.make_position_params()
            lsp_params.newName = params.new_name
            
            local responses = vim.lsp.buf_request_sync(bufnr, 'textDocument/rename', lsp_params, 2000)
            
            if not responses or vim.tbl_isempty(responses) then
                return {error = "Не вдалося виконати перейменування"}
            end
            
            local changes = {}
            for _, response in pairs(responses) do
                if response.result then
                    vim.lsp.util.apply_workspace_edit(response.result, 'utf-8')
                    
                    -- Підраховуємо зміни
                    if response.result.changes then
                        for uri, edits in pairs(response.result.changes) do
                            table.insert(changes, {
                                file = vim.uri_to_fname(uri),
                                edits_count = #edits
                            })
                        end
                    end
                end
            end
            
            return {
                success = true,
                message = "Перейменовано на '" .. params.new_name .. "'",
                changes = changes,
                files_changed = #changes
            }
        end
    },
    
    -- LSP: Code Actions
    {
        name = "get_code_actions",
        description = "Отримує доступні code actions (швидкі виправлення) для позиції.",
        parameters = {
            type = "object",
            properties = {
                buffer = {
                    type = "number",
                    description = "Номер буфера"
                },
                line = {
                    type = "number",
                    description = "Номер рядка"
                },
                column = {
                    type = "number",
                    description = "Номер колонки"
                }
            }
        },
        handler = function(params)
            local bufnr = params.buffer or 0
            if bufnr == 0 then
                bufnr = vim.api.nvim_get_current_buf()
            end
            
            if params.line and params.column then
                vim.api.nvim_win_set_cursor(0, {params.line, params.column - 1})
            end
            
            local lsp_params = vim.lsp.util.make_range_params()
            lsp_params.context = {
                diagnostics = vim.diagnostic.get(bufnr)
            }
            
            local responses = vim.lsp.buf_request_sync(bufnr, 'textDocument/codeAction', lsp_params, 2000)
            
            if not responses or vim.tbl_isempty(responses) then
                return {success = true, actions = {}, count = 0}
            end
            
            local actions = {}
            for _, response in pairs(responses) do
                if response.result then
                    for i, action in ipairs(response.result) do
                        table.insert(actions, {
                            index = i,
                            title = action.title,
                            kind = action.kind,
                            is_preferred = action.isPreferred or false
                        })
                    end
                end
            end
            
            return {
                success = true,
                actions = actions,
                count = #actions
            }
        end
    },
    
    -- LSP: Форматування коду
    {
        name = "format_code",
        description = "Форматує код у буфері або діапазоні рядків.",
        parameters = {
            type = "object",
            properties = {
                buffer = {
                    type = "number",
                    description = "Номер буфера"
                },
                start_line = {
                    type = "number",
                    description = "Початковий рядок (для часткового форматування)"
                },
                end_line = {
                    type = "number",
                    description = "Кінцевий рядок (для часткового форматування)"
                }
            }
        },
        handler = function(params)
            local bufnr = params.buffer or 0
            if bufnr == 0 then
                bufnr = vim.api.nvim_get_current_buf()
            end
            
            local lsp_params
            if params.start_line and params.end_line then
                -- Форматування діапазону
                lsp_params = vim.lsp.util.make_given_range_params(
                    {params.start_line - 1, 0},
                    {params.end_line - 1, 0},
                    bufnr
                )
                
                local responses = vim.lsp.buf_request_sync(bufnr, 'textDocument/rangeFormatting', lsp_params, 2000)
                
                if responses and not vim.tbl_isempty(responses) then
                    for _, response in pairs(responses) do
                        if response.result then
                            vim.lsp.util.apply_text_edits(response.result, bufnr, 'utf-8')
                        end
                    end
                    
                    return {
                        success = true,
                        message = "Відформатовано рядки " .. params.start_line .. "-" .. params.end_line
                    }
                end
            else
                -- Форматування всього файлу
                vim.lsp.buf.format({bufnr = bufnr, timeout_ms = 2000})
                
                return {
                    success = true,
                    message = "Файл відформатовано"
                }
            end
            
            return {error = "Форматування не доступне для цього буфера"}
        end
    },
    
    -- Виконання shell команд
    {
        name = "execute_shell",
        description = "Виконує shell команду та повертає результат.",
        parameters = {
            type = "object",
            properties = {
                command = {
                    type = "string",
                    description = "Shell команда для виконання"
                },
                timeout = {
                    type = "number",
                    description = "Таймаут в секундах"
                }
            },
            required = {"command"}
        },
        handler = function(params)
            local cmd = params.command
            local timeout = params.timeout or 30
            
            local output = vim.fn.system(cmd)
            local exit_code = vim.v.shell_error
            
            return {
                success = exit_code == 0,
                output = output,
                exit_code = exit_code
            }
        end
    },
    
    -- Вставка тексту в буфер
    {
        name = "insert_text",
        description = "Вставляє текст у вказану позицію буфера.",
        parameters = {
            type = "object",
            properties = {
                buffer = {
                    type = "number",
                    description = "Номер буфера"
                },
                line = {
                    type = "number",
                    description = "Номер рядка для вставки"
                },
                text = {
                    type = "string",
                    description = "Текст для вставки"
                },
                mode = {
                    type = "string",
                    description = "Режим вставки: 'before', 'after', 'replace'"
                }
            },
            required = {"text"}
        },
        handler = function(params)
            local bufnr = params.buffer or 0
            if bufnr == 0 then
                bufnr = vim.api.nvim_get_current_buf()
            end
            
            local line = params.line or vim.api.nvim_win_get_cursor(0)[1]
            local mode = params.mode or "after"
            local lines = vim.split(params.text, "\n")
            
            if mode == "before" then
                vim.api.nvim_buf_set_lines(bufnr, line - 1, line - 1, false, lines)
            elseif mode == "after" then
                vim.api.nvim_buf_set_lines(bufnr, line, line, false, lines)
            elseif mode == "replace" then
                vim.api.nvim_buf_set_lines(bufnr, line - 1, line, false, lines)
            end
            
            return {
                success = true,
                message = "Текст вставлено",
                lines_inserted = #lines,
                at_line = line
            }
        end
    },
    
    -- Видалення ліній
    {
        name = "delete_lines",
        description = "Видаляє рядки з буфера.",
        parameters = {
            type = "object",
            properties = {
                buffer = {
                    type = "number",
                    description = "Номер буфера"
                },
                start_line = {
                    type = "number",
                    description = "Початковий рядок"
                },
                end_line = {
                    type = "number",
                    description = "Кінцевий рядок"
                }
            },
            required = {"start_line"}
        },
        handler = function(params)
            local bufnr = params.buffer or 0
            if bufnr == 0 then
                bufnr = vim.api.nvim_get_current_buf()
            end
            
            local start_line = params.start_line
            local end_line = params.end_line or start_line
            
            vim.api.nvim_buf_set_lines(bufnr, start_line - 1, end_line, false, {})
            
            return {
                success = true,
                message = "Рядки видалено",
                lines_deleted = end_line - start_line + 1
            }
        end
    },
    
    -- Заміна тексту
    {
        name = "replace_text",
        description = "Замінює текст в буфері (підтримує regex).",
        parameters = {
            type = "object",
            properties = {
                buffer = {
                    type = "number",
                    description = "Номер буфера"
                },
                pattern = {
                    type = "string",
                    description = "Патерн для пошуку (regex)"
                },
                replacement = {
                    type = "string",
                    description = "Текст для заміни"
                },
                start_line = {
                    type = "number",
                    description = "Початковий рядок (опціонально)"
                },
                end_line = {
                    type = "number",
                    description = "Кінцевий рядок (опціонально)"
                },
                global = {
                    type = "boolean",
                    description = "Замінити всі входження в рядку"
                }
            },
            required = {"pattern", "replacement"}
        },
        handler = function(params)
            local bufnr = params.buffer or 0
            if bufnr == 0 then
                bufnr = vim.api.nvim_get_current_buf()
            end
            
            local start_line = params.start_line or 1
            local end_line = params.end_line or vim.api.nvim_buf_line_count(bufnr)
            
            local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
            local replacements = 0
            local flags = params.global and "g" or ""
            
            for i, line in ipairs(lines) do
                local new_line, count = line:gsub(params.pattern, params.replacement)
                if count > 0 then
                    lines[i] = new_line
                    replacements = replacements + count
                end
            end
            
            vim.api.nvim_buf_set_lines(bufnr, start_line - 1, end_line, false, lines)
            
            return {
                success = true,
                message = "Виконано " .. replacements .. " замін",
                replacements = replacements
            }
        end
    },
    
    -- Отримання вибраного тексту (ВИМКНЕНО - проблема з схемою)
    -- {
    --     name = "get_selection",
    --     description = "Отримує поточний вибраний текст у візуальному режимі.",
    --     parameters = {
    --         type = "object",
    --         properties = {}
    --     },
    --     handler = function(params)
    --         -- Отримуємо позиції вибору
    --         local start_pos = vim.fn.getpos("'<")
    --         local end_pos = vim.fn.getpos("'>")
    --         
    --         if start_pos[2] == 0 or end_pos[2] == 0 then
    --             return {error = "Нема активного вибору"}
    --         end
    --         
    --         local lines = vim.api.nvim_buf_get_lines(
    --             0,
    --             start_pos[2] - 1,
    --             end_pos[2],
    --             false
    --         )
    --         
    --         -- Обрізаємо перший та останній рядок по колонках
    --         if #lines > 0 then
    --             if #lines == 1 then
    --                 lines[1] = lines[1]:sub(start_pos[3], end_pos[3])
    --             else
    --                 lines[1] = lines[1]:sub(start_pos[3])
    --                 lines[#lines] = lines[#lines]:sub(1, end_pos[3])
    --             end
    --         end
    --         
    --         return {
    --             success = true,
    --             text = table.concat(lines, "\n"),
    --             start_line = start_pos[2],
    --             end_line = end_pos[2],
    --             start_col = start_pos[3],
    --             end_col = end_pos[3]
    --         }
    --     end
    -- },
    
    -- Створення нового буфера
    {
        name = "create_buffer",
        description = "Створює новий буфер з опціональним вмістом.",
        parameters = {
            type = "object",
            properties = {
                name = {
                    type = "string",
                    description = "Ім'я буфера (шлях до файлу)"
                },
                content = {
                    type = "string",
                    description = "Початковий вміст"
                },
                filetype = {
                    type = "string",
                    description = "Тип файлу (lua, python, javascript тощо)"
                },
                open = {
                    type = "boolean",
                    description = "Відкрити буфер у вікні"
                }
            }
        },
        handler = function(params)
            local bufnr = vim.api.nvim_create_buf(true, not params.name)
            
            if params.name then
                vim.api.nvim_buf_set_name(bufnr, params.name)
            end
            
            if params.content then
                local lines = vim.split(params.content, "\n")
                vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
            end
            
            if params.filetype then
                vim.api.nvim_buf_set_option(bufnr, 'filetype', params.filetype)
            end
            
            if params.open then
                vim.api.nvim_set_current_buf(bufnr)
            end
            
            return {
                success = true,
                buffer = bufnr,
                name = params.name or "unnamed",
                message = "Буфер створено"
            }
        end
    },
    
    -- Закриття буфера
    {
        name = "close_buffer",
        description = "Закриває буфер.",
        parameters = {
            type = "object",
            properties = {
                buffer = {
                    type = "number",
                    description = "Номер буфера"
                },
                force = {
                    type = "boolean",
                    description = "Примусово закрити навіть якщо є незбережені зміни"
                }
            }
        },
        handler = function(params)
            local bufnr = params.buffer or vim.api.nvim_get_current_buf()
            local force = params.force or false
            
            local modified = vim.api.nvim_buf_get_option(bufnr, 'modified')
            if modified and not force then
                return {
                    error = "Буфер має незбережені зміни. Використайте force=true для примусового закриття"
                }
            end
            
            vim.api.nvim_buf_delete(bufnr, {force = force})
            
            return {
                success = true,
                message = "Буфер закрито"
            }
        end
    },
    
    -- Збереження буфера
    {
        name = "save_buffer",
        description = "Зберігає буфер на диск.",
        parameters = {
            type = "object",
            properties = {
                buffer = {
                    type = "number",
                    description = "Номер буфера"
                },
                path = {
                    type = "string",
                    description = "Шлях для збереження (якщо відрізняється)"
                }
            }
        },
        handler = function(params)
            local bufnr = params.buffer or vim.api.nvim_get_current_buf()
            
            if params.path then
                vim.api.nvim_buf_set_name(bufnr, params.path)
            end
            
            local name = vim.api.nvim_buf_get_name(bufnr)
            if name == "" then
                return {error = "Буфер не має імені. Вкажіть path"}
            end
            
            vim.api.nvim_buf_call(bufnr, function()
                vim.cmd('write')
            end)
            
            return {
                success = true,
                message = "Буфер збережено",
                path = name
            }
        end
    },
    
    -- Відкриття файлу
    {
        name = "open_file",
        description = "Відкриває файл у новому або існуючому буфері.",
        parameters = {
            type = "object",
            properties = {
                path = {
                    type = "string",
                    description = "Шлях до файлу"
                },
                line = {
                    type = "number",
                    description = "Перейти на рядок після відкриття"
                },
                column = {
                    type = "number",
                    description = "Перейти на колонку після відкриття"
                },
                split = {
                    type = "string",
                    description = "Режим відкриття: 'horizontal', 'vertical', 'tab'"
                }
            },
            required = {"path"}
        },
        handler = function(params)
            local path = params.path
            
            if not vim.fn.filereadable(path) == 1 then
                return {error = "Файл не існує або недоступний: " .. path}
            end
            
            local cmd = "edit"
            if params.split == "horizontal" then
                cmd = "split"
            elseif params.split == "vertical" then
                cmd = "vsplit"
            elseif params.split == "tab" then
                cmd = "tabedit"
            end
            
            vim.cmd(cmd .. " " .. vim.fn.fnameescape(path))
            
            if params.line then
                vim.api.nvim_win_set_cursor(0, {params.line, params.column or 0})
            end
            
            return {
                success = true,
                message = "Файл відкрито",
                buffer = vim.api.nvim_get_current_buf(),
                path = path
            }
        end
    },
    
    -- Отримання treesitter інформації
    {
        name = "get_treesitter_nodes",
        description = "Отримує treesitter nodes для аналізу структури коду.",
        parameters = {
            type = "object",
            properties = {
                buffer = {
                    type = "number",
                    description = "Номер буфера"
                },
                node_type = {
                    type = "string",
                    description = "Тип вузлів (function, class, variable тощо)"
                },
                start_line = {
                    type = "number",
                    description = "Початковий рядок"
                },
                end_line = {
                    type = "number",
                    description = "Кінцевий рядок"
                }
            }
        },
        handler = function(params)
            local has_ts, ts = pcall(require, 'nvim-treesitter')
            if not has_ts then
                return {error = "Treesitter не встановлено"}
            end
            
            local bufnr = params.buffer or 0
            if bufnr == 0 then
                bufnr = vim.api.nvim_get_current_buf()
            end
            
            local parser = vim.treesitter.get_parser(bufnr)
            if not parser then
                return {error = "Treesitter parser не доступний для цього буфера"}
            end
            
            local tree = parser:parse()[1]
            local root = tree:root()
            
            local nodes = {}
            local start_line = params.start_line or 0
            local end_line = params.end_line or vim.api.nvim_buf_line_count(bufnr)
            
            local function traverse(node)
                local node_type = node:type()
                local srow, scol, erow, ecol = node:range()
                
                -- Фільтруємо по діапазону
                if srow + 1 >= start_line and erow + 1 <= end_line then
                    -- Фільтруємо по типу якщо вказано
                    if not params.node_type or node_type == params.node_type then
                        table.insert(nodes, {
                            type = node_type,
                            start_line = srow + 1,
                            start_col = scol + 1,
                            end_line = erow + 1,
                            end_col = ecol + 1,
                            text = vim.treesitter.get_node_text(node, bufnr)
                        })
                    end
                end
                
                -- Рекурсивно обходимо дочірні вузли
                for child in node:iter_children() do
                    traverse(child)
                end
            end
            
            traverse(root)
            
            return {
                success = true,
                nodes = nodes,
                count = #nodes
            }
        end
    },
    
    -- Виконання макросу
    {
        name = "execute_macro",
        description = "Виконує записаний Vim макрос.",
        parameters = {
            type = "object",
            properties = {
                register = {
                    type = "string",
                    description = "Реєстр з макросом (a-z)"
                },
                count = {
                    type = "number",
                    description = "Скільки разів виконати"
                }
            },
            required = {"register"}
        },
        handler = function(params)
            local register = params.register
            local count = params.count or 1
            
            if not register:match("^[a-z]$") then
                return {error = "Неправильний реєстр. Використовуйте a-z"}
            end
            
            local macro = vim.fn.getreg(register)
            if macro == "" then
                return {error = "Реєстр " .. register .. " порожній"}
            end
            
            for i = 1, count do
                vim.cmd("normal @" .. register)
            end
            
            return {
                success = true,
                message = "Макрос виконано " .. count .. " раз(ів)",
                register = register
            }
        end
    },
    
    -- Отримання контексту проекту
    {
        name = "get_project_context",
        description = "Завантажує контекст всього проекту: структуру файлів, основні файли, конфігурацію.",
        parameters = {
            type = "object",
            properties = {
                include_content = {
                    type = "boolean",
                    description = "Включити вміст файлів (false - тільки структура)"
                },
                file_patterns = {
                    type = "array",
                    items = {type = "string"},
                    description = "Патерни файлів для включення (за замовчуванням: код файли)"
                },
                exclude_patterns = {
                    type = "array",
                    items = {type = "string"},
                    description = "Патерни для виключення"
                },
                max_file_size = {
                    type = "number",
                    description = "Максимальний розмір файлу в KB (за замовчуванням 100KB)"
                },
                max_files = {
                    type = "number",
                    description = "Максимальна кількість файлів (за замовчуванням 50)"
                },
                include_git_info = {
                    type = "boolean",
                    description = "Включити Git інформацію"
                }
            }
        },
        handler = function(params)
            local cwd = vim.fn.getcwd()
            local include_content = params.include_content ~= false
            local max_file_size = (params.max_file_size or 100) * 1024
            local max_files = params.max_files or 50
            
            -- Дефолтні патерни для коду
            local default_patterns = {
                "*.lua", "*.js", "*.ts", "*.jsx", "*.tsx", "*.py", "*.rb", 
                "*.go", "*.rs", "*.c", "*.cpp", "*.h", "*.java", "*.cs",
                "*.php", "*.vue", "*.svelte", "*.html", "*.css", "*.scss",
                "*.json", "*.yaml", "*.yml", "*.toml", "*.md", "*.txt"
            }
            
            local file_patterns = params.file_patterns or default_patterns
            
            -- Дефолтні виключення
            local default_excludes = {
                "node_modules", ".git", "dist", "build", ".next", 
                "target", "vendor", ".venv", "venv", "__pycache__",
                ".pytest_cache", ".mypy_cache", "coverage"
            }
            
            local exclude_patterns = params.exclude_patterns or default_excludes
            
            -- Функція перевірки чи файл виключений
            local function is_excluded(path)
                for _, pattern in ipairs(exclude_patterns) do
                    if path:match(pattern) then
                        return true
                    end
                end
                return false
            end
            
            -- Функція перевірки чи файл відповідає патерну
            local function matches_pattern(filename, patterns)
                for _, pattern in ipairs(patterns) do
                    local lua_pattern = pattern:gsub("%*", ".*"):gsub("%.", "%%.")
                    if filename:match(lua_pattern .. "$") then
                        return true
                    end
                end
                return false
            end
            
            -- Збір файлів
            local files = {}
            local file_count = 0
            local total_size = 0
            
            -- Рекурсивний обхід директорій
            local function scan_dir(dir)
                if file_count >= max_files then
                    return
                end
                
                local handle = vim.loop.fs_scandir(dir)
                if not handle then return end
                
                while true do
                    local name, type = vim.loop.fs_scandir_next(handle)
                    if not name then break end
                    
                    local path = dir .. "/" .. name
                    local relative_path = path:sub(#cwd + 2)
                    
                    if not is_excluded(relative_path) then
                        if type == "directory" then
                            scan_dir(path)
                        elseif type == "file" and matches_pattern(name, file_patterns) then
                            local stat = vim.loop.fs_stat(path)
                            if stat and stat.size <= max_file_size then
                                local file_info = {
                                    path = relative_path,
                                    size = stat.size,
                                    modified = stat.mtime.sec
                                }
                                
                                if include_content then
                                    local content = vim.fn.readfile(path)
                                    if content then
                                        file_info.content = table.concat(content, "\n")
                                        file_info.lines = #content
                                    end
                                end
                                
                                table.insert(files, file_info)
                                file_count = file_count + 1
                                total_size = total_size + stat.size
                                
                                if file_count >= max_files then
                                    break
                                end
                            end
                        end
                    end
                end
            end
            
            scan_dir(cwd)
            
            -- Сортуємо файли за важливістю
            local priority_files = {
                "README.md", "package.json", "Cargo.toml", "go.mod",
                "requirements.txt", "Gemfile", "composer.json",
                "pyproject.toml", "setup.py", "CMakeLists.txt"
            }
            
            table.sort(files, function(a, b)
                local a_priority = vim.tbl_contains(priority_files, vim.fn.fnamemodify(a.path, ":t"))
                local b_priority = vim.tbl_contains(priority_files, vim.fn.fnamemodify(b.path, ":t"))
                
                if a_priority ~= b_priority then
                    return a_priority
                end
                
                return a.path < b.path
            end)
            
            -- Структура проекту (дерево директорій)
            local structure = {}
            local function build_tree(file_path)
                local parts = vim.split(file_path, "/")
                local current = structure
                
                for i, part in ipairs(parts) do
                    if i == #parts then
                        table.insert(current, part)
                    else
                        if not current[part] then
                            current[part] = {}
                        end
                        current = current[part]
                    end
                end
            end
            
            for _, file in ipairs(files) do
                build_tree(file.path)
            end
            
            -- Git інформація
            local git_info = nil
            if params.include_git_info then
                local git_branch = vim.fn.system("git branch --show-current 2>/dev/null"):gsub("\n", "")
                local git_status = vim.fn.system("git status --short 2>/dev/null")
                local git_remote = vim.fn.system("git remote get-url origin 2>/dev/null"):gsub("\n", "")
                
                if vim.v.shell_error == 0 then
                    git_info = {
                        branch = git_branch,
                        has_changes = git_status ~= "",
                        remote = git_remote,
                        status_summary = git_status
                    }
                end
            end
            
            -- Виявлення типу проекту
            local project_type = "unknown"
            local project_info = {}
            
            for _, file in ipairs(files) do
                local basename = vim.fn.fnamemodify(file.path, ":t")
                
                if basename == "package.json" and file.content then
                    project_type = "node"
                    local ok, json = pcall(vim.json.decode, file.content)
                    if ok then
                        project_info = {
                            name = json.name,
                            version = json.version,
                            description = json.description,
                            dependencies = json.dependencies and vim.tbl_keys(json.dependencies) or {}
                        }
                    end
                    break
                elseif basename == "Cargo.toml" then
                    project_type = "rust"
                    break
                elseif basename == "go.mod" then
                    project_type = "go"
                    break
                elseif basename == "requirements.txt" or basename == "pyproject.toml" then
                    project_type = "python"
                    break
                elseif basename == "init.lua" or basename == "plugin" then
                    project_type = "neovim-plugin"
                    break
                end
            end
            
            return {
                success = true,
                project = {
                    root = cwd,
                    type = project_type,
                    info = project_info
                },
                files = files,
                structure = structure,
                git = git_info,
                statistics = {
                    total_files = file_count,
                    total_size = total_size,
                    size_mb = string.format("%.2f", total_size / 1024 / 1024),
                    truncated = file_count >= max_files
                }
            }
        end
    },
    
    -- Отримання структури проекту (швидка версія без вмісту)
    {
        name = "get_project_structure",
        description = "Швидко отримує структуру проекту без вмісту файлів.",
        parameters = {
            type = "object",
            properties = {
                max_depth = {
                    type = "number",
                    description = "Максимальна глибина вкладеності (за замовчуванням 5)"
                },
                show_hidden = {
                    type = "boolean",
                    description = "Показувати приховані файли"
                }
            }
        },
        handler = function(params)
            local cwd = vim.fn.getcwd()
            local max_depth = params.max_depth or 3  -- Зменшено з 5 до 3
            local show_hidden = params.show_hidden or false
            
            local exclude_dirs = {
                "node_modules", ".git", "dist", "build", ".next",
                "target", "vendor", ".venv", "venv", "__pycache__",
                ".cache", "coverage", ".pytest_cache"
            }
            
            local tree = {}
            local file_count = 0
            local dir_count = 0
            local max_files = 500  -- Ліміт файлів
            
            local function scan_dir(dir, depth, parent)
                if depth > max_depth or file_count >= max_files then
                    return
                end
                
                local ok, handle = pcall(vim.loop.fs_scandir, dir)
                if not ok or not handle then return end
                
                local items = {}
                
                -- Обмежуємо кількість ітерацій
                local iterations = 0
                local max_iterations = 1000
                
                while iterations < max_iterations do
                    iterations = iterations + 1
                    
                    local ok_scan, name, type = pcall(vim.loop.fs_scandir_next, handle)
                    if not ok_scan or not name then break end
                    
                    -- Пропускаємо приховані якщо не потрібні
                    if not show_hidden and name:sub(1, 1) == "." then
                        goto continue
                    end
                    
                    -- Пропускаємо виключені директорії
                    if type == "directory" and vim.tbl_contains(exclude_dirs, name) then
                        goto continue
                    end
                    
                    local path = dir .. "/" .. name
                    local item = {
                        name = name,
                        type = type,
                        depth = depth
                    }
                    
                    if type == "directory" then
                        dir_count = dir_count + 1
                        item.children = {}
                        scan_dir(path, depth + 1, item.children)
                        table.insert(items, item)
                    else
                        file_count = file_count + 1
                        local ok_stat, stat = pcall(vim.loop.fs_stat, path)
                        if ok_stat and stat then
                            item.size = stat.size
                        end
                        table.insert(items, item)
                    end
                    
                    ::continue::
                end
                
                -- Сортуємо: спочатку директорії, потім файли
                table.sort(items, function(a, b)
                    if a.type ~= b.type then
                        return a.type == "directory"
                    end
                    return a.name < b.name
                end)
                
                for _, item in ipairs(items) do
                    table.insert(parent, item)
                end
            end
            
            -- Захищений виклик scan_dir
            local ok, err = pcall(scan_dir, cwd, 1, tree)
            
            if not ok then
                return {
                    success = false,
                    error = "Помилка сканування: " .. tostring(err)
                }
            end
            
            -- Форматуємо дерево у текстовий вигляд
            local function format_tree(items, prefix, level)
                local lines = {}
                local max_lines = 100  -- Обмеження для великих проектів
                
                if #lines >= max_lines then
                    return lines
                end
                
                for i, item in ipairs(items) do
                    if #lines >= max_lines then
                        table.insert(lines, prefix .. "... (більше файлів)")
                        break
                    end
                    
                    local is_last = i == #items
                    local connector = is_last and "└── " or "├── "
                    local icon = item.type == "directory" and "📁 " or "📄 "
                    
                    local line = prefix .. connector .. icon .. item.name
                    if item.type == "file" and item.size then
                        line = line .. string.format(" (%s)", M.format_file_size(item.size))
                    end
                    
                    table.insert(lines, line)
                    
                    if item.children and #item.children > 0 then
                        local child_prefix = prefix .. (is_last and "    " or "│   ")
                        local child_lines = format_tree(item.children, child_prefix, level + 1)
                        for _, child_line in ipairs(child_lines) do
                            table.insert(lines, child_line)
                        end
                    end
                end
                
                return lines
            end
            
            local tree_lines = format_tree(tree, "", 0)
            
            return {
                success = true,
                root = cwd,
                tree = tree,
                tree_text = table.concat(tree_lines, "\n"),
                statistics = {
                    files = file_count,
                    directories = dir_count,
                    max_depth = max_depth,
                    truncated = file_count >= max_files
                }
            }
        end
    }
}

-- Реєстрація інструмента
function M.register_tool(tool)
    if not tool.name or not tool.handler then
        return false, "Інструмент повинен мати name та handler"
    end
    
    tools[tool.name] = tool
    utils.log("info", "MCP tool зареєстровано", {name = tool.name})
    
    return true
end

-- Виконання інструмента
function M.execute_tool(tool_name, parameters)
    local tool = tools[tool_name]
    
    if not tool then
        return {error = "Інструмент не знайдено: " .. tool_name}
    end
    
    utils.log("debug", "Виконання MCP tool", {
        name = tool_name,
        params = parameters
    })
    
    -- Виконуємо handler
    local success, result = pcall(tool.handler, parameters or {})
    
    if not success then
        utils.log("error", "Помилка виконання MCP tool", {
            name = tool_name,
            error = result
        })
        return {error = "Помилка виконання: " .. tostring(result)}
    end
    
    return result
end

-- Отримання списку доступних інструментів
function M.list_tools()
    local tool_list = {}
    
    for name, tool in pairs(tools) do
        table.insert(tool_list, {
            name = name,
            description = tool.description,
            parameters = tool.parameters
        })
    end
    
    return tool_list
end

-- Отримання опису інструментів у форматі для AI
-- Отримати список всіх tools з повною інформацією
function M.get_tools()
    local tools_list = {}
    
    for name, tool in pairs(tools) do
        table.insert(tools_list, {
            name = name,
            description = tool.description,
            parameters = tool.parameters,
            handler = tool.handler
        })
    end
    
    return tools_list
end

-- Отримати tools у форматі OpenAI (alias для get_tools_schema для сумісності з тестами)
function M.get_tools_for_openai()
    return M.get_tools_schema()
end

-- Отримати схему tools для OpenAI API
function M.get_tools_schema()
    local schema = {}
    
    for name, tool in pairs(tools) do
        table.insert(schema, {
            type = "function",
            ["function"] = {
                name = name,
                description = tool.description,
                parameters = tool.parameters
            }
        })
    end
    
    return schema
end

-- Реєстрація зовнішнього MCP сервера
function M.register_server(config)
    if not config.name or not config.command then
        return false, "Сервер повинен мати name та command"
    end
    
    external_servers[config.name] = {
        name = config.name,
        command = config.command,
        args = config.args or {},
        env = config.env or {},
        tools = {}
    }
    
    utils.log("info", "MCP сервер зареєстровано", {name = config.name})
    return true
end

-- Ініціалізація MCP модуля
function M.setup(user_config)
    user_config = user_config or {}
    
    -- Реєструємо базові Neovim інструменти
    for _, tool in ipairs(M.neovim_tools) do
        M.register_tool(tool)
    end
    
    -- Реєструємо зовнішні сервери з конфігурації
    if user_config.servers then
        for _, server_config in ipairs(user_config.servers) do
            M.register_server(server_config)
        end
    end
    
    utils.log("info", "MCP модуль ініціалізовано", {
        tools_count = vim.tbl_count(tools),
        servers_count = vim.tbl_count(external_servers)
    })
    
    return true
end

-- Обробка викликів інструментів від AI
function M.handle_tool_calls(tool_calls, callback)
    local results = {}
    local pending = #tool_calls
    
    if pending == 0 then
        callback(results)
        return
    end
    
    for i, call in ipairs(tool_calls) do
        local tool_name = call["function"].name
        local parameters = call["function"].arguments
        
        -- Парсимо параметри якщо це JSON string
        if type(parameters) == "string" then
            local success, parsed = pcall(vim.json.decode, parameters)
            if success then
                parameters = parsed
            end
        end
        
        -- Виконуємо інструмент
        local result = M.execute_tool(tool_name, parameters)
        
        -- Обрізаємо великі результати для уникнення проблем з розміром
        local result_json = vim.json.encode(result)
        local max_size = 50000  -- ~50KB максимум для одного результату
        
        if #result_json > max_size then
            -- Якщо результат занадто великий, обрізаємо content
            if result.content and type(result.content) == "string" then
                local truncated_content = result.content:sub(1, max_size - 500)
                result = vim.tbl_extend("force", result, {
                    content = truncated_content .. "\n\n[... обрізано " .. 
                              (#result.content - #truncated_content) .. " символів ...]",
                    truncated = true,
                    original_size = #result.content
                })
                result_json = vim.json.encode(result)
            end
        end
        
        -- Додаємо результат у форматі OpenAI API
        -- ВАЖЛИВО: тільки role, tool_call_id, content (БЕЗ name!)
        table.insert(results, {
            role = "tool",
            tool_call_id = call.id,
            content = result_json
        })
        
        pending = pending - 1
        if pending == 0 then
            callback(results)
        end
    end
end

return M
