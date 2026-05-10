#!/usr/bin/env bash
# Personal dotfiles installer.
# Runs inside the devcontainer after your editor clones the dotfiles repo.
# Idempotent — safe to re-run.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"

# --- Claude Code CLI ----------------------------------------------------------
# Devcontainers that mount a named volume at ~/.local/share/claude/ will
# preserve the installed binary across rebuilds, so this becomes a no-op on
# subsequent rebuilds (the `command -v claude` check passes once the symlink
# at ~/.local/bin/claude is restored — see the symlink-restore block below).
if ! command -v claude >/dev/null 2>&1; then
    # If a previous install survived in the named volume, restore the
    # ~/.local/bin/claude symlink without re-running the network installer.
    if [ -d "$HOME/.local/share/claude/versions" ]; then
        LATEST=$(ls -1 "$HOME/.local/share/claude/versions" 2>/dev/null | sort -V | tail -n1 || true)
        if [ -n "$LATEST" ] && [ -x "$HOME/.local/share/claude/versions/$LATEST" ]; then
            mkdir -p "$HOME/.local/bin"
            ln -sfn "$HOME/.local/share/claude/versions/$LATEST" "$HOME/.local/bin/claude"
            echo "Restored Claude Code symlink → $LATEST"
        fi
    fi
fi
if ! command -v claude >/dev/null 2>&1; then
    echo "Installing Claude Code CLI..."
    curl -fsSL https://claude.ai/install.sh | bash
else
    echo "Claude Code CLI already present — skipping install."
fi

# --- Personal VS Code extensions ---------------------------------------------
# `code` is only on PATH inside a VS Code remote session; skip silently otherwise.
if command -v code >/dev/null 2>&1; then
    code --install-extension anthropic.claude-code --force
    code --install-extension vscode-icons-team.vscode-icons --force
fi

# --- Claude preferences -------------------------------------------------------
# ~/.claude/ is a named volume in our devcontainers, so these copies refresh
# the configs on every container creation while preserving session state.
mkdir -p ~/.claude/commands
cp -f  "$DIR/claude/settings.json" ~/.claude/settings.json
cp -f  "$DIR/claude/CLAUDE.md"     ~/.claude/CLAUDE.md

# Copy slash commands if any exist in dotfiles.
if [ -d "$DIR/claude/commands" ] && [ -n "$(ls -A "$DIR/claude/commands" 2>/dev/null)" ]; then
    cp -rf "$DIR/claude/commands/." ~/.claude/commands/
fi

# Persist Claude Code's top-level state file (~/.claude.json) on the same
# named volume that holds ~/.claude/. This file stores hasCompletedOnboarding,
# hasIdeOnboardingBeenShown, per-project trust state, and the oauthAccount
# block — losing it on rebuild forces the theme/trust/auth wizard to re-run.
# Symlinking it into ~/.claude/ piggybacks on the existing volume mount.
PERSIST="$HOME/.claude/_claude-root.json"
LINK="$HOME/.claude.json"
if [ -f "$LINK" ] && [ ! -L "$LINK" ]; then
    mv "$LINK" "$PERSIST"
fi
if [ ! -e "$PERSIST" ]; then
    touch "$PERSIST"
fi
ln -sfn "$PERSIST" "$LINK"

# --- Shell aliases ------------------------------------------------------------
ALIAS_LINE="source $DIR/shell/aliases.sh"
if ! grep -qxF "$ALIAS_LINE" ~/.bashrc 2>/dev/null; then
    echo "$ALIAS_LINE" >> ~/.bashrc
fi

echo "Dotfiles installed."
