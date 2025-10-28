#!/bin/bash
# Setup script для встановлення залежностей

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPS_DIR="$SCRIPT_DIR/deps"
PLENARY_DIR="$DEPS_DIR/plenary.nvim"

echo "📦 Встановлення залежностей для nvim-agent..."

# Створюємо папку deps/
mkdir -p "$DEPS_DIR"

# Встановлюємо plenary.nvim
if [ -d "$PLENARY_DIR" ]; then
    echo "✅ plenary.nvim вже встановлено"
else
    echo "⬇️  Клонування plenary.nvim..."
    git clone --depth 1 https://github.com/nvim-lua/plenary.nvim "$PLENARY_DIR"
    echo "✅ plenary.nvim встановлено"
fi

echo ""
echo "✅ Всі залежності встановлено!"
echo ""
echo "Запустіть тести:"
echo "  make test"
echo "  або"
echo "  ./test.ps1  (Windows)"
