# PowerShell script для запуску тестів на Windows

param(
  [string]$TestFile = "",
  [switch]$Watch = $false,
  [switch]$Verbose = $false
)

$ErrorActionPreference = "Stop"

# Шляхи
$PLUGIN_DIR = $PSScriptRoot
$DEPS_DIR = Join-Path $PLUGIN_DIR "deps"
$PLENARY_DIR = Join-Path $DEPS_DIR "plenary.nvim"

# Кольори для виводу
function Write-Color {
  param($Text, $Color = "White")
  Write-Host $Text -ForegroundColor $Color
}

# Перевірка чи встановлено Neovim
if (-not (Get-Command nvim -ErrorAction SilentlyContinue)) {
  Write-Color "❌ Neovim не знайдено. Встановіть Neovim." "Red"
  exit 1
}

# Перевірка/встановлення plenary.nvim в deps/
if (-not (Test-Path $PLENARY_DIR)) {
  Write-Color "📦 Встановлюю plenary.nvim в deps/..." "Yellow"
  New-Item -ItemType Directory -Force -Path $DEPS_DIR | Out-Null
  git clone --depth 1 https://github.com/nvim-lua/plenary.nvim $PLENARY_DIR
  Write-Color "✅ plenary.nvim встановлено" "Green"
}
else {
  Write-Color "✅ plenary.nvim знайдено в deps/" "Green"
}# Функція запуску тестів
function Run-Tests {
  param($File = "")
    
  if ($File) {
    Write-Color "🧪 Запуск тесту: $File" "Cyan"
    nvim --headless --noplugin -u tests/minimal_init.lua -c "PlenaryBustedFile $File"
  }
  else {
    Write-Color "🧪 Запуск всіх тестів..." "Cyan"
    
    # Запуск основних тестів
    nvim --headless --noplugin -u tests/minimal_init.lua -c "lua require('plenary.test_harness').test_directory('tests/nvim-agent', { minimal_init = 'tests/minimal_init.lua' })"
    $mainTestsResult = $LASTEXITCODE
    
    # Запуск UI тестів
    Write-Color "`n🎨 Запуск UI тестів..." "Cyan"
    nvim --headless --noplugin -u tests/minimal_init.lua -l tests/run_ui_tests.lua
    $uiTestsResult = $LASTEXITCODE
    
    # Перевірка результатів
    if ($mainTestsResult -eq 0 -and $uiTestsResult -eq 0) {
      Write-Color "`n✅ Всі тести пройдено!" "Green"
      return 0
    }
    else {
      Write-Color "`n❌ Деякі тести провалились" "Red"
      return 1
    }
  }
    
  if ($LASTEXITCODE -eq 0) {
    Write-Color "`n✅ Всі тести пройдено!" "Green"
  }
  else {
    Write-Color "`n❌ Деякі тести провалились" "Red"
    exit $LASTEXITCODE
  }
}

# Основна логіка
if ($Watch) {
  Write-Color "👀 Watch режим (Ctrl+C для виходу)" "Yellow"
  Write-Color "Змініть будь-який файл в lua/ або tests/ для повторного запуску`n" "Gray"
    
  # Простий watch без entr (для Windows)
  $lastRun = Get-Date
  while ($true) {
    $files = Get-ChildItem -Path "lua", "tests" -Recurse -Filter "*.lua"
    $changed = $files | Where-Object { $_.LastWriteTime -gt $lastRun }
        
    if ($changed) {
      Clear-Host
      Run-Tests $TestFile
      $lastRun = Get-Date
    }
        
    Start-Sleep -Seconds 1
  }
}
else {
  Run-Tests $TestFile
}
