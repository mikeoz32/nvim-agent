# Повний список MCP інструментів nvim-agent

## Статистика

- **Всього інструментів:** 28
- **LSP інтеграція:** 9 інструментів
- **Робота з файлами:** 5 інструментів
- **Редагування:** 4 інструменти
- **Управління буферами:** 4 інструменти
- **Інші:** 6 інструментів

---

## 1. read_file
**Категорія:** Робота з файлами  
**Опис:** Читає вміст файлу або його частини  
**Параметри:**
- `path` (string, обов'язковий)
- `start_line` (number, опціонально)
- `end_line` (number, опціонально)

---

## 2. write_file
**Категорія:** Робота з файлами  
**Опис:** Записує або оновлює вміст файлу  
**Параметри:**
- `path` (string, обов'язковий)
- `content` (string, обов'язковий)
- `create_dirs` (boolean, опціонально)

---

## 3. open_file
**Категорія:** Робота з файлами  
**Опис:** Відкриває файл у буфері  
**Параметри:**
- `path` (string, обов'язковий)
- `line` (number, опціонально)
- `column` (number, опціонально)
- `split` (string, опціонально) - 'horizontal', 'vertical', 'tab'

---

## 4. find_files
**Категорія:** Робота з файлами  
**Опис:** Шукає файли за glob патерном  
**Параметри:**
- `pattern` (string, обов'язковий)
- `max_results` (number, опціонально)

---

## 5. grep_search
**Категорія:** Робота з файлами  
**Опис:** Шукає текст у файлах проекту  
**Параметри:**
- `query` (string, обов'язковий)
- `file_pattern` (string, опціонально)
- `max_results` (number, опціонально)

---

## 6. get_diagnostics
**Категорія:** LSP  
**Опис:** Отримує діагностичні повідомлення  
**Параметри:**
- `buffer` (number, опціонально)
- `severity` (string, опціонально) - ERROR, WARN, INFO, HINT

---

## 7. goto_definition
**Категорія:** LSP  
**Опис:** Знаходить визначення символу  
**Параметри:**
- `buffer` (number, опціонально)
- `line` (number, опціонально)
- `column` (number, опціонально)
- `symbol` (string, опціонально)

---

## 8. find_references
**Категорія:** LSP  
**Опис:** Знаходить всі посилання на символ  
**Параметри:**
- `buffer` (number, опціонально)
- `line` (number, опціонально)
- `column` (number, опціонально)
- `symbol` (string, опціонально)
- `include_declaration` (boolean, опціонально)

---

## 9. get_signature_help
**Категорія:** LSP  
**Опис:** Отримує підказку про параметри функції  
**Параметри:**
- `buffer` (number, опціонально)
- `line` (number, опціонально)
- `column` (number, опціонально)

---

## 10. get_hover_info
**Категорія:** LSP  
**Опис:** Отримує документацію про символ  
**Параметри:**
- `buffer` (number, опціонально)
- `line` (number, опціонально)
- `column` (number, опціонально)
- `symbol` (string, опціонально)

---

## 11. get_document_symbols
**Категорія:** LSP  
**Опис:** Список всіх символів у документі  
**Параметри:**
- `buffer` (number, опціонально)
- `file` (string, опціонально)
- `kind` (string, опціонально) - Function, Class, Variable, Method

---

## 12. rename_symbol
**Категорія:** LSP  
**Опис:** Перейменовує символ у всіх місцях  
**Параметри:**
- `buffer` (number, опціонально)
- `line` (number, опціонально)
- `column` (number, опціонально)
- `old_name` (string, опціонально)
- `new_name` (string, обов'язковий)

---

## 13. get_code_actions
**Категорія:** LSP  
**Опис:** Отримує доступні code actions  
**Параметри:**
- `buffer` (number, опціонально)
- `line` (number, опціонально)
- `column` (number, опціонально)

---

## 14. format_code
**Категорія:** LSP  
**Опис:** Форматує код  
**Параметри:**
- `buffer` (number, опціонально)
- `start_line` (number, опціонально)
- `end_line` (number, опціонально)

---

## 15. insert_text
**Категорія:** Редагування  
**Опис:** Вставляє текст у буфер  
**Параметри:**
- `buffer` (number, опціонально)
- `line` (number, опціонально)
- `text` (string, обов'язковий)
- `mode` (string, опціонально) - 'before', 'after', 'replace'

---

## 16. delete_lines
**Категорія:** Редагування  
**Опис:** Видаляє рядки з буфера  
**Параметри:**
- `buffer` (number, опціонально)
- `start_line` (number, обов'язковий)
- `end_line` (number, опціонально)

---

## 17. replace_text
**Категорія:** Редагування  
**Опис:** Замінює текст (підтримує regex)  
**Параметри:**
- `buffer` (number, опціонально)
- `pattern` (string, обов'язковий)
- `replacement` (string, обов'язковий)
- `start_line` (number, опціонально)
- `end_line` (number, опціонально)
- `global` (boolean, опціонально)

---

## 18. get_selection
**Категорія:** Редагування  
**Опис:** Отримує вибраний текст  
**Параметри:** немає

---

## 19. list_buffers
**Категорія:** Буфери  
**Опис:** Список відкритих буферів  
**Параметри:**
- `only_modified` (boolean, опціонально)

---

## 20. create_buffer
**Категорія:** Буфери  
**Опис:** Створює новий буфер  
**Параметри:**
- `name` (string, опціонально)
- `content` (string, опціонально)
- `filetype` (string, опціонально)
- `open` (boolean, опціонально)

---

## 21. save_buffer
**Категорія:** Буфери  
**Опис:** Зберігає буфер на диск  
**Параметри:**
- `buffer` (number, опціонально)
- `path` (string, опціонально)

---

## 22. close_buffer
**Категорія:** Буфери  
**Опис:** Закриває буфер  
**Параметри:**
- `buffer` (number, опціонально)
- `force` (boolean, опціонально)

---

## 23. get_treesitter_nodes
**Категорія:** Treesitter  
**Опис:** Аналізує структуру коду  
**Параметри:**
- `buffer` (number, опціонально)
- `node_type` (string, опціонально)
- `start_line` (number, опціонально)
- `end_line` (number, опціонально)

---

## 24. execute_command
**Категорія:** Команди  
**Опис:** Виконує Ex команду Neovim  
**Параметри:**
- `command` (string, обов'язковий)

---

## 25. execute_shell
**Категорія:** Команди  
**Опис:** Виконує shell команду  
**Параметри:**
- `command` (string, обов'язковий)
- `timeout` (number, опціонально)

---

## 26. execute_macro
**Категорія:** Команди  
**Опис:** Виконує Vim макрос  
**Параметри:**
- `register` (string, обов'язковий) - a-z
- `count` (number, опціонально)

---

## Порівняння з VS Code

| Можливість | VS Code Copilot | nvim-agent |
|------------|----------------|------------|
| Читання файлів | ✅ | ✅ |
| Запис файлів | ✅ | ✅ |
| Пошук файлів | ✅ | ✅ |
| LSP діагностика | ✅ | ✅ |
| LSP навігація | ✅ | ✅ (9 інструментів) |
| Перейменування | ✅ | ✅ |
| Форматування | ✅ | ✅ |
| Treesitter | ❌ | ✅ |
| Vim макроси | ❌ | ✅ |
| Зовнішні сервери | ✅ | ✅ |

## Використання пам'яті

Приблизний розмір кожного tool call:

- **read_file**: 1-10KB (залежить від розміру файлу)
- **write_file**: 1-10KB (залежить від вмісту)
- **LSP запити**: 0.5-2KB
- **grep_search**: 2-20KB (залежить від результатів)
- **get_treesitter_nodes**: 1-5KB

**Рекомендації:**
- Обмежуйте `max_results` при пошуку
- Використовуйте `start_line`/`end_line` для великих файлів
- Комбінуйте інструменти для складних задач

## Поширені комбінації

### 1. Знайти та виправити
```
find_references → read_file → write_file
```

### 2. Аналіз та рефакторинг
```
get_document_symbols → get_hover_info → rename_symbol → format_code
```

### 3. Створення модуля
```
find_files → read_file → create_buffer → insert_text → save_buffer
```

### 4. Тестування
```
grep_search → open_file → execute_shell → get_diagnostics
```

## Обмеження

1. **LSP інструменти** потребують активного LSP сервера
2. **Treesitter** потребує встановленого treesitter
3. **Shell команди** обмежені правами доступу
4. **Timeout** для операцій - 30 секунд за замовчуванням
5. **Розмір файлу** для читання необмежений (обережно з великими файлами)

## Налаштування продуктивності

```lua
require('nvim-agent').setup({
    mcp = {
        enabled = true,
        
        -- Оптимізації
        tools = {
            -- Збільшити timeout для повільних операцій
            execute_shell = {timeout = 60},
            
            -- Обмежити результати пошуку
            find_files = {max_results = 50},
            grep_search = {max_results = 100},
        }
    }
})
```

## Debugging інструментів

```lua
-- Лог всіх tool викликів
vim.api.nvim_create_autocmd("User", {
    pattern = "NvimAgentToolCall",
    callback = function(args)
        print("Tool:", args.data.tool_name)
        print("Params:", vim.inspect(args.data.params))
    end
})

-- Лог результатів
vim.api.nvim_create_autocmd("User", {
    pattern = "NvimAgentToolResult",
    callback = function(args)
        print("Result:", vim.inspect(args.data.result))
    end
})
```

---

**Версія:** 1.0  
**Оновлено:** 2025-10-28  
**Автор:** nvim-agent team
