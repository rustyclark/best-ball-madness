#!/bin/bash
# Setup script to copy tracked git hooks to the local .git/hooks directory

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

echo "Configuring git hooks..."
cp "$PROJECT_ROOT/.githooks/pre-commit" "$PROJECT_ROOT/.git/hooks/pre-commit"
chmod +x "$PROJECT_ROOT/.git/hooks/pre-commit"

echo "✅ Git hooks configured successfully!"
