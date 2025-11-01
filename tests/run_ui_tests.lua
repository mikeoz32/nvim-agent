-- Скрипт для запуску тестів chat_nui

-- Запуск тестів
require('plenary.test_harness').test_directory('tests/ui', {
    minimal_init = 'tests/minimal_init.lua'
})
