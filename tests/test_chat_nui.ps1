#!/usr/bin/env pwsh
# Скрипт для запуску тестів chat_nui

$ErrorActionPreference = "Stop"

Write-Host "🧪 Запуск тестів chat_nui.lua..." -ForegroundColor Cyan
Write-Host ""

# Перевірка залежностей
if (-not (Test-Path "deps/plenary.nvim")) {
  Write-Host "❌ plenary.nvim не знайдено" -ForegroundColor Red
  Write-Host "Запустіть: .\test.ps1" -ForegroundColor Yellow
  exit 1
}

if (-not (Test-Path "deps/nui.nvim")) {
  Write-Host "❌ nui.nvim не знайдено" -ForegroundColor Red
  Write-Host "Запустіть: git clone https://github.com/MunifTanjim/nui.nvim deps/nui.nvim" -ForegroundColor Yellow
  exit 1
}

Write-Host "✅ Залежності знайдено" -ForegroundColor Green
Write-Host ""

# Запуск тестів
$TestCommand = @"
lua << EOF
require('plenary.test_harness').test_directory('tests/ui', {
    minimal_init = 'tests/minimal_init.lua'
})
EOF
"@

nvim --headless --noplugin -u tests/minimal_init.lua -c "$TestCommand"

if ($LASTEXITCODE -eq 0) {
  Write-Host ""
  Write-Host "✅ Всі тести пройдено!" -ForegroundColor Green
}
else {
  Write-Host ""
  Write-Host "❌ Деякі тести не пройшли" -ForegroundColor Red
  exit 1
}
