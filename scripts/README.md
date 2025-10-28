# Scripts

Допоміжні скрипти для розробки та налаштування проекту.

## setup.sh / setup.ps1

Встановлює залежності для тестування (plenary.nvim) в папку `deps/`.

**Використання:**
```bash
# Linux/macOS
./scripts/setup.sh

# Windows
.\scripts\setup.ps1
```

## run_tests.ps1

Застарілий скрипт. Використовуйте замість нього:
- `.\test.ps1` (Windows)
- `make test` (Linux/macOS)
