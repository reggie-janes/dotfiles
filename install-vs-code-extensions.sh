#!/usr/bin/env bash
# Personal VS Code extension installer.
# Invoked by the project's post-start.sh hook (after dotfiles & VS Code
# server are fully ready), so the `code` shim is reliably functional here.
# `code --install-extension --force` is idempotent: re-runs are no-ops once
# the extension is already installed.
set -exuo pipefail

echo "install-vs-code-extensions.sh"

code --install-extension anthropic.claude-code --force || true
code --install-extension vscode-icons-team.vscode-icons --force || true

echo "install-vs-code-extensions.sh done"
