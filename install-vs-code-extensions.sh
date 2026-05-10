#!/usr/bin/env bash
# Personal VS Code extension installer.
# Invoked by the project's post-start.sh hook (after dotfiles & VS Code
# server are fully ready), so the `code` shim is reliably functional here.
# `code --install-extension --force` is idempotent: re-runs are no-ops once
# the extension is already installed.
set -exuo pipefail

echo "install-vs-code-extensions.sh"
whoami
pwd
fail=0
code --install-extension anthropic.claude-code --force || fail=1
code --install-extension vscode-icons-team.vscode-icons --force || fail=1

echo "install-vs-code-extensions.sh done (fail=$fail)"
exit $fail
