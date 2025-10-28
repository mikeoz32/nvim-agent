# Setup script для Windows
# Встановлення залежностей для nvim-agent

$SCRIPT_DIR = $PSScriptRoot
$DEPS_DIR = Join-Path $SCRIPT_DIR "deps"
$PLENARY_DIR = Join-Path $DEPS_DIR "plenary.nvim"

Write-Host "📦 Встановлення залежностей для nvim-agent..." -ForegroundColor Cyan

# Створюємо папку deps/
if (-not (Test-Path $DEPS_DIR)) {
  New-Item -ItemType Directory -Path $DEPS_DIR | Out-Null
}

# Встановлюємо plenary.nvim
if (Test-Path $PLENARY_DIR) {
  Write-Host "✅ plenary.nvim вже встановлено" -ForegroundColor Green
}
else {
  Write-Host "⬇️  Клонування plenary.nvim..." -ForegroundColor Yellow
  git clone --depth 1 https://github.com/nvim-lua/plenary.nvim $PLENARY_DIR
  Write-Host "✅ plenary.nvim встановлено" -ForegroundColor Green
}

Write-Host ""
Write-Host "✅ Всі залежності встановлено!" -ForegroundColor Green
Write-Host ""
Write-Host "Запустіть тести:" -ForegroundColor Cyan
Write-Host "  .\test.ps1" -ForegroundColor White
