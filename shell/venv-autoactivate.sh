# Auto-activate the workspace's Python venv on shell startup.
# Skips the VS Code Python extension's delayed `source` (saves a couple of
# seconds per new terminal). Detects at runtime so this snippet works across
# projects without hardcoding the workspace name; on non-Python projects the
# glob matches nothing and this is a no-op.
#
# Edge case: in a monorepo with multiple `.venv` dirs the first match wins
# (alphabetical). Revisit if that shape ever shows up.
for _venv in /workspaces/*/.venv/bin/activate; do
    [ -r "$_venv" ] && . "$_venv" && break
done
unset _venv
