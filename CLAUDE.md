# CLAUDE.md

Personal dotfiles repo. Cloned by VS Code into every devcontainer it creates; `install.sh` runs once at clone time to set up Claude Code, VS Code extensions, Claude configs, and shell aliases.

## Repository structure

```
dotfiles/
├── install.sh              # Entry point — runs once on container create
├── claude/
│   ├── CLAUDE.md           # Copied to ~/.claude/CLAUDE.md (global Claude Code instructions)
│   ├── settings.json       # Copied to ~/.claude/settings.json
│   └── commands/           # Copied to ~/.claude/commands/ (custom slash commands)
└── shell/
    └── aliases.sh          # Sourced from ~/.bashrc on every interactive shell
```

The `claude/CLAUDE.md` inside this repo is **not** the file you're reading. That one becomes the user's global Claude instructions in every container. This file (`/CLAUDE.md` at repo root) is project-level context for Claude when working *on the dotfiles repo itself*.

## Critical constraints

### Idempotency

**`install.sh` must be safe to re-run any number of times.** It runs automatically once on container create, but is also run by hand whenever the user pulls dotfiles changes (`cd ~/dotfiles && git pull && bash install.sh`). Every step needs to handle the "already done" case gracefully:

- Tool installs check `command -v <tool>` first and skip if present.
- File copies use `cp -f` to overwrite without prompting.
- Lines added to `~/.bashrc` (or any shared file) are guarded with `grep -qxF` to avoid duplicates.
- Optional source files (e.g. `claude/commands/`) are wrapped in existence checks before being read.

When adding new steps to `install.sh`, write them so a second run is a no-op. Never assume a clean filesystem.

### Line endings must be LF

The repo is cloned into a Linux container and bash chokes on CRLF. The repo has a `.gitattributes` enforcing `eol=lf` for shell scripts; preserve it. If you create new scripts, double-check they're LF before committing — a single CRLF script breaks the install with cryptic errors like `$'\r': command not found` or `set: pipefail: invalid option`.

### `~/.claude/` is a named Docker volume

In the user's devcontainers, `~/.claude/` is mounted as a named volume that survives container rebuilds. This means:

- Session history and the auth token persist across rebuilds — don't add steps that wipe `~/.claude/` wholesale.
- The `cp -f` overwrites of `settings.json` and `CLAUDE.md` are deliberate: configs from this repo are the source of truth and should refresh on every install run, while runtime state (sessions, history) is preserved alongside.
- `commands/` is copied with `cp -rf <src>/.` so the contents merge into the existing dir rather than replacing it.

## What belongs here vs not

**Belongs:** anything personal that should follow the developer into every devcontainer regardless of project — Claude Code, icon themes, shell aliases, personal git config snippets, a custom prompt, AI tool preferences.

**Does not belong:** anything project-specific. Python versions, project dependencies, language toolchains, project-required VS Code extensions all live in each project's `.devcontainer/`. The split is "what I personally like" vs "what this project needs"; this repo is strictly the first.

## Testing changes

Don't rely on container rebuild to test — too slow. The fast loop is:

```bash
cd ~/dotfiles
git pull
bash install.sh
```

After install, verify:

```bash
# Aliases — open a new terminal or `source ~/.bashrc`, then:
alias

# Claude configs
ls -la ~/.claude/
cat ~/.claude/CLAUDE.md | head

# Tools
which claude && claude --version
```

For a true clean-slate test, rebuild the container ("Dev Containers: Rebuild Container" in VS Code). The named volumes for `.venv` and `~/.claude/` survive, but the container's writable layer is wiped, so dotfiles re-clone and install from scratch — this catches issues that an incremental `bash install.sh` would mask.

## Common pitfalls

- **Aliases not appearing after install:** the user's *currently open* shell already finished reading `.bashrc` before the source line was added. They need a new terminal or `source ~/.bashrc`. This is expected behavior; don't try to "fix" it in the script.
- **`cp` failing on a missing source file:** use `[ -f "$src" ] && cp -f ...` rather than letting `set -e` abort the whole install. Optional configs should be optional.
- **Empty directories:** git doesn't track them. If `install.sh` references a directory that's empty in normal use (e.g. `claude/commands/` for a user with no custom commands), guard the copy with an existence check.
- **VS Code extension IDs are case-sensitive and publisher-specific.** Verify against the marketplace listing before adding `code --install-extension` lines; a wrong ID fails silently to the user beyond a one-line error.

## Conventions

- Bash scripts start with `#!/usr/bin/env bash` and `set -euo pipefail`.
- Comments explain *why*, not *what*. The shell is readable; intent isn't.
- Keep `install.sh` flat and linear. If it needs functions or multi-file structure, the dotfiles have outgrown their purpose.
