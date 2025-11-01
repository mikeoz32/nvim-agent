-- Скрипт для запуску тестів summarization

-- Запуск тестів
require('plenary.test_harness').test_directory('tests/unit', {
    minimal_init = 'tests/minimal_init.lua'
})
