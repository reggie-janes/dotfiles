#!/usr/bin/env bash
# Personal dotfiles installer.
# Runs inside the devcontainer after your editor clones the dotfiles repo.
# Idempotent — safe to re-run.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"

# --- Claude Code CLI ----------------------------------------------------------
if ! command -v claude >/dev/null 2>&1; then
    echo "Installing Claude Code CLI..."
    curl -fsSL https://claude.ai/install.sh | bash
else
    echo "Claude Code CLI already present — skipping install."
fi

# --- Personal VS Code extensions ---------------------------------------------
# `code` is only on PATH inside a VS Code remote session; skip silently otherwise.
if command -v code >/dev/null 2>&1; then
    code --install-extension anthropics.claude-code --force
    code --install-extension vscode-icons-team.vscode-icons --force
fi

# --- Claude preferences -------------------------------------------------------
# ~/.claude/ is a named volume in our devcontainers, so these copies refresh
# the configs on every container creation while preserving session state and auth.
mkdir -p ~/.claude/commands
cp -f  "$DIR/claude/settings.json" ~/.claude/settings.json
cp -f  "$DIR/claude/CLAUDE.md"     ~/.claude/CLAUDE.md
cp -rf "$DIR/claude/commands/."    ~/.claude/commands/

# --- Shell aliases ------------------------------------------------------------
ALIAS_LINE="source $DIR/shell/aliases.sh"
if ! grep -qxF "$ALIAS_LINE" ~/.bashrc 2>/dev/null; then
    echo "$ALIAS_LINE" >> ~/.bashrc
fi

echo "Dotfiles installed."
