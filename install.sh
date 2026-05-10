#!/usr/bin/env bash
# Personal dotfiles installer.
# Runs inside the devcontainer after your editor clones the dotfiles repo.
# Idempotent — safe to re-run.
set -exuo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"

# --- Shell aliases ------------------------------------------------------------
ALIAS_LINE="source $DIR/shell/aliases.sh"
if ! grep -qxF "$ALIAS_LINE" ~/.bashrc 2>/dev/null; then
    echo "$ALIAS_LINE" >> ~/.bashrc
fi

# --- Auto-activate workspace venv --------------------------------------------
# Without this, the VS Code Python extension activates the venv for us, but
# only after a few seconds of delay per new terminal.
VENV_LINE="source $DIR/shell/venv-autoactivate.sh"
if ! grep -qxF "$VENV_LINE" ~/.bashrc 2>/dev/null; then
    echo "$VENV_LINE" >> ~/.bashrc
fi

# --- Claude Code CLI ----------------------------------------------------------
# The launcher at ~/.local/bin/claude is not in any persistent mount, so it's
# lost on every rebuild and must be re-created. The named volume mount on
# ~/.local/share/claude/ keeps the version downloads warm, so re-running the
# installer is fast (it skips the download when the version is already cached).
echo "Installing/refreshing Claude Code CLI..."
curl -fsSL https://claude.ai/install.sh | bash

# Note: personal VS Code extensions are NOT installed here.
# Lifecycle scripts run without VSCODE_IPC_HOOK_CLI set, so `code` resolves
# to a dummy fallback that only knows how to print "code or code-insiders is
# not installed". Add personal extensions to the user-level VS Code setting
# `dev.containers.defaultExtensions` instead — VS Code installs them itself.

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


echo "Dotfiles installed."
