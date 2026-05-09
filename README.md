# Devcontainer + Dotfiles Setup for Python Projects

This repo demonstrates a clean separation between **team-wide project configuration** and **personal developer preferences** when working on Python projects in VS Code devcontainers.

## The split

- **`.devcontainer/`** lives in the project repo. Everyone working on the project gets the same Python version, system packages, and project-essential VS Code extensions. Committed alongside the code.
- **A separate dotfiles repo** lives in your own GitHub account. It carries your personal tooling — Claude Code, icon themes, shell aliases — into every devcontainer you open, regardless of project. Never committed into project repos.

VS Code's dotfiles integration clones your dotfiles repo into each container automatically and runs `install.sh`. Your preferences follow you everywhere; the project repo stays clean.

### Why split along this line?

Two failure modes the split avoids:

- **Everything in `.devcontainer/`** → the project repo accumulates your personal Claude config, your favorite icon theme, etc. Teammates have to either adopt your tools or strip them out before opening the project.
- **Everything in dotfiles** → the project's Python version, dependencies, and required extensions aren't reproducible. New teammates have to discover and install them by hand.

The clean axis is *what the project needs* (devcontainer) vs *what I personally like* (dotfiles).

## Per-project isolation: devcontainers, not VS Code profiles

A natural instinct is to set up a "Python profile" and "Rust profile" in VS Code, each with its own extensions and settings. This doesn't work the way once could hope:

- VS Code profiles don't layer or inherit. Switching profiles swaps the entire active set; it doesn't add to a base.
- The dotfiles integration runs once per container regardless of which profile is active. There's no per-profile dotfiles repo.

So **the devcontainer is the per-project unit** in this setup. Open the Python project → get a Python container with Python extensions and toolchain. Open a Rust project → get a Rust container with Rust extensions and toolchain. The two never interact, because they're literally different containers.

VS Code profiles, in this scheme, are reserved for cross-project *modes* — a "Presenting" profile with a giant font, a "Writing" profile for markdown work — not for language-specific work, which devcontainers already isolate.

## Named volumes for `.venv` and `~/.claude/`

Two paths inside the container are mounted as **Docker named volumes** rather than living in the container's writable layer or being bind-mounted from the host.

### `.venv`

The Python virtual environment, populated by `uv sync`.

- **Why not the workspace bind mount?** The workspace is bind-mounted from the host. On Windows/macOS, bind mounts go through a translation layer (WSL2 9P or osxfs/virtiofs) that's slow for small-file-heavy directories like a Python venv. A named volume keeps the venv on the Linux side and is significantly faster.
- **Why not the container layer?** A volume survives container rebuilds. You don't have to redownload every dependency every time you tweak the Dockerfile.
- **Why not a separate name like `.venv-linux`?** A named volume already isolates the Linux env from any `.venv` your Windows host might create. No need for a non-standard directory name or a `UV_PROJECT_ENVIRONMENT` env var.

### `~/.claude/`

Claude Code's session state, conversation history, slash commands, and auth token.

- **Survives rebuilds**, so you keep your login and session history when you tweak the Dockerfile.
- **Per-project**, because the volume name is derived from the workspace folder. The Python container's Claude state is separate from the Rust container's. Sessions stay scoped to the project they belong to.
- **Doesn't collide with the host's `~/.claude/`**. If you also use Claude Code on the Windows host, the two histories are independent — no concurrent writes to the same `.claude.json`, no Windows path leaking into Linux state.
- **Configs get refreshed on every container create**: dotfiles `install.sh` copies `CLAUDE.md`, `settings.json`, and `commands/` from your dotfiles repo into `~/.claude/`. Updates to your dotfiles propagate, while runtime state (sessions, auth) is preserved across rebuilds.

Both volumes are owned by root on first creation, so `post-create.sh` runs `chown` to hand them to the `vscode` user before `uv sync` runs.

## The `vscode` user

The base image `mcr.microsoft.com/devcontainers/python` ships with a `vscode` user that has passwordless sudo and the UID-remapping plumbing needed for bind-mounted workspaces. We use that user instead of creating our own:

- No permission mismatches on the workspace mount.
- `sudo` is available in lifecycle scripts when needed (e.g. for the volume `chown`).
- One less thing to maintain in the Dockerfile.

## Lifecycle scripts at a glance

| Script | Where it runs | When | Purpose |
|---|---|---|---|
| `host-init.sh` | Host | Before container builds | Team-wide host prep (placeholder for now) |
| `post-create.sh` | Container | Once, on creation | Chown volumes, configure git safe.directory, `uv sync` |
| `post-start.sh` | Container | Every container start | Apply git identity overrides from env vars |
| Dotfiles `install.sh` | Container | Once, on creation | Install personal tools, copy Claude configs, set up aliases |

## Setup checklist

1. Create a dotfiles repo on GitHub (e.g. `username/dotfiles`) with the structure shown below.
2. In VS Code settings, set:
   - `Dotfiles: Repository` → your dotfiles repo URL
   - `Dotfiles: Install Command` → `install.sh`
3. Copy this `.devcontainer/` folder into your Python project.
4. Optionally set `GIT_USER_NAME_OVERRIDE` and `GIT_USER_EMAIL_OVERRIDE` in your host environment if your container git identity should differ from your host's default.
5. Open the project in VS Code and choose "Reopen in Container".

---

### Suggested dotfiles repo layout

```
dotfiles/
├── install.sh
├── claude/
│   ├── CLAUDE.md
│   ├── settings.json
│   └── commands/
│       └── (your custom slash commands)
└── shell/
    └── aliases.sh
```

---

# Cleaning up volumes

Named volumes survive container deletion. If you want to wipe a project's `.venv` or Claude state — for example to start fresh — list and remove them with Docker:

```bash
docker volume ls | grep myproject
docker volume rm myproject-venv myproject-claude
```

Volumes are tied to the workspace folder name (`localWorkspaceFolderBasename`), so renaming the folder will create new volumes and orphan the old ones.
