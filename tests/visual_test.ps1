#!/usr/bin/env pwsh
# Скрипт для візуального тестування nvim-agent

Write-Host "🚀 Запуск візуального тестування nvim-agent" -ForegroundColor Green
Write-Host "=" -NoNewline; Write-Host ("=" * 60) -ForegroundColor Gray
Write-Host ""

Write-Host "📋 Інструкції для тестування:" -ForegroundColor Cyan
Write-Host ""
Write-Host "1️⃣  Базове тестування чату:" -ForegroundColor Yellow
Write-Host "   • Відкрийте Neovim: " -NoNewline
Write-Host "nvim tests/test_code.lua" -ForegroundColor White
Write-Host "   • Відкрийте чат: " -NoNewline
Write-Host "<Space>aa" -ForegroundColor White
Write-Host "   • Натисніть " -NoNewline
Write-Host "i" -ForegroundColor White -NoNewline
Write-Host " щоб відкрити input"
Write-Host "   • Введіть багаторядковий текст"
Write-Host "   • Натисніть " -NoNewline
Write-Host "Ctrl+S" -ForegroundColor White -NoNewline
Write-Host " для відправки"
Write-Host ""

Write-Host "2️⃣  Тестування режимів:" -ForegroundColor Yellow
Write-Host "   • Ask режим (питання): " -NoNewline
Write-Host "<Space>aa" -ForegroundColor White
Write-Host "   • Edit режим (редагування): " -NoNewline
Write-Host "<Space>cm" -ForegroundColor White
Write-Host "   • Agent режим (автономія): " -NoNewline
Write-Host "<Space>cm" -ForegroundColor White
Write-Host ""

Write-Host "3️⃣  Тестування Edit режиму:" -ForegroundColor Yellow
Write-Host "   • Виберіть код в visual mode (" -NoNewline
Write-Host "V" -ForegroundColor White -NoNewline
Write-Host " + стрілки)"
Write-Host "   • Натисніть " -NoNewline
Write-Host "<Space>ae" -ForegroundColor White -NoNewline
Write-Host " (пояснити код)"
Write-Host "   • Або " -NoNewline
Write-Host "<Space>ar" -ForegroundColor White -NoNewline
Write-Host " (рефакторинг)"
Write-Host ""

Write-Host "4️⃣  Тестування статистики input:" -ForegroundColor Yellow
Write-Host "   • Введіть багаторядковий текст (20+ рядків)"
Write-Host "   • Спостерігайте за statusline:"
Write-Host "     📝 Insert | Рядків: X | Слів: Y | Символів: Z" -ForegroundColor Gray
Write-Host ""

Write-Host "5️⃣  Тестування компактного layout:" -ForegroundColor Yellow
Write-Host "   • Відправте 5-10 повідомлень"
Write-Host "   • Перевірте роздільники між повідомленнями"
Write-Host "   • Перевірте що немає зайвих пустих рядків"
Write-Host ""

Write-Host "=" -NoNewline; Write-Host ("=" * 60) -ForegroundColor Gray
Write-Host ""

$response = Read-Host "Запустити Neovim зараз? (y/n)"
if ($response -eq "y" -or $response -eq "Y") {
  Write-Host ""
  Write-Host "▶️  Запуск Neovim..." -ForegroundColor Green
  & nvim -u tests/test_init.lua tests/test_code.lua
}
else {
  Write-Host ""
  Write-Host "👋 Коли будете готові, запустіть:" -ForegroundColor Cyan
  Write-Host "   nvim -u tests/test_init.lua tests/test_code.lua" -ForegroundColor White
  Write-Host ""
}
