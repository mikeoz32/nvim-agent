# PowerShell скрипт для тестування nvim-agent

$PLUGIN_DIR = $PSScriptRoot

Write-Host "`n=== nvim-agent Testing Script ===" -ForegroundColor Cyan
Write-Host "Plugin directory: $PLUGIN_DIR`n" -ForegroundColor Gray

# Функція для запуску Neovim з тестовою конфігурацією
function Start-TestNeovim {
  param(
    [string]$File = ""
  )
    
  $configPath = Join-Path $PLUGIN_DIR "test_config.lua"
    
  if ($File) {
    nvim -u $configPath $File
  }
  else {
    nvim -u $configPath
  }
}

# Функція для запуску автоматичних тестів
function Start-AutoTests {
  Write-Host "Running automated tests..." -ForegroundColor Yellow
    
  $configPath = Join-Path $PLUGIN_DIR "test_config.lua"
  $testPath = Join-Path $PLUGIN_DIR "tests\basic_test.lua"
    
  nvim --headless -u $configPath -c "luafile $testPath" -c "qall"
    
  if ($LASTEXITCODE -eq 0) {
    Write-Host "`n✅ All tests passed!`n" -ForegroundColor Green
  }
  else {
    Write-Host "`n❌ Some tests failed!`n" -ForegroundColor Red
  }
}

# Функція для перевірки залежностей
function Test-Dependencies {
  Write-Host "Checking dependencies..." -ForegroundColor Yellow
    
  # Перевірка Neovim
  if (Get-Command nvim -ErrorAction SilentlyContinue) {
    $nvimVersion = nvim --version | Select-Object -First 1
    Write-Host "✅ Neovim: $nvimVersion" -ForegroundColor Green
  }
  else {
    Write-Host "❌ Neovim not found!" -ForegroundColor Red
    Write-Host "   Install: winget install Neovim.Neovim" -ForegroundColor Gray
  }
    
  # Перевірка структури плагіна
  $requiredDirs = @(
    "lua\nvim-agent",
    "lua\nvim-agent\ui",
    "lua\nvim-agent\api",
    "docs",
    "tests"
  )
    
  foreach ($dir in $requiredDirs) {
    $path = Join-Path $PLUGIN_DIR $dir
    if (Test-Path $path) {
      Write-Host "✅ Directory: $dir" -ForegroundColor Green
    }
    else {
      Write-Host "❌ Missing directory: $dir" -ForegroundColor Red
    }
  }
    
  # Перевірка ключових файлів
  $requiredFiles = @(
    "lua\nvim-agent\init.lua",
    "lua\nvim-agent\chat.lua",
    "lua\nvim-agent\ui\inline_buttons.lua",
    "lua\nvim-agent\change_manager.lua",
    "test_config.lua"
  )
    
  foreach ($file in $requiredFiles) {
    $path = Join-Path $PLUGIN_DIR $file
    if (Test-Path $path) {
      Write-Host "✅ File: $file" -ForegroundColor Green
    }
    else {
      Write-Host "❌ Missing file: $file" -ForegroundColor Red
    }
  }
    
  # Перевірка API ключа
  if ($env:OPENAI_API_KEY) {
    Write-Host "✅ OPENAI_API_KEY is set" -ForegroundColor Green
  }
  else {
    Write-Host "⚠️  OPENAI_API_KEY not set (optional for testing)" -ForegroundColor Yellow
    Write-Host "   Set with: `$env:OPENAI_API_KEY = 'sk-...'" -ForegroundColor Gray
  }
    
  Write-Host ""
}

# Функція для відкриття документації
function Open-Documentation {
  param([string]$Doc = "README.md")
    
  $docPath = Join-Path $PLUGIN_DIR $Doc
    
  if (Test-Path $docPath) {
    Start-Process $docPath
  }
  else {
    Write-Host "❌ Documentation not found: $Doc" -ForegroundColor Red
  }
}

# Функція для очищення тестових файлів
function Clear-TestFiles {
  Write-Host "Cleaning test files..." -ForegroundColor Yellow
    
  $patterns = @(
    "*.log",
    "*test*.txt",
    ".nvim-agent-*"
  )
    
  foreach ($pattern in $patterns) {
    $files = Get-ChildItem -Path $PLUGIN_DIR -Filter $pattern -Recurse
    foreach ($file in $files) {
      Remove-Item $file.FullName -Force
      Write-Host "Deleted: $($file.Name)" -ForegroundColor Gray
    }
  }
    
  Write-Host "✅ Cleanup complete`n" -ForegroundColor Green
}

# Показати меню
function Show-Menu {
  Write-Host "Available commands:" -ForegroundColor Cyan
  Write-Host "  1. test           - Open Neovim with test config" -ForegroundColor White
  Write-Host "  2. test-auto      - Run automated tests" -ForegroundColor White
  Write-Host "  3. check          - Check dependencies" -ForegroundColor White
  Write-Host "  4. docs           - Open documentation" -ForegroundColor White
  Write-Host "  5. clean          - Clean test files" -ForegroundColor White
  Write-Host "  6. help           - Show this menu" -ForegroundColor White
  Write-Host ""
  Write-Host "Examples:" -ForegroundColor Cyan
  Write-Host "  .\run_tests.ps1 test              - Open Neovim" -ForegroundColor Gray
  Write-Host "  .\run_tests.ps1 test myfile.js    - Open file in test mode" -ForegroundColor Gray
  Write-Host "  .\run_tests.ps1 test-auto          - Run automated tests" -ForegroundColor Gray
  Write-Host "  .\run_tests.ps1 check              - Check setup" -ForegroundColor Gray
  Write-Host ""
}

# Головна логіка
switch ($args[0]) {
  "test" {
    if ($args[1]) {
      Start-TestNeovim -File $args[1]
    }
    else {
      Start-TestNeovim
    }
  }
  "test-auto" {
    Start-AutoTests
  }
  "check" {
    Test-Dependencies
  }
  "docs" {
    if ($args[1]) {
      Open-Documentation -Doc $args[1]
    }
    else {
      Open-Documentation
    }
  }
  "clean" {
    Clear-TestFiles
  }
  "help" {
    Show-Menu
  }
  default {
    Show-Menu
  }
}
