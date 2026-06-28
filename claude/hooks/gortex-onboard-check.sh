#!/usr/bin/env bash
# Claude Code SessionStart hook — nudge to onboard repos that don't use gortex.
#
# Fires at the start of every session. Stays completely silent unless:
#   - the cwd is inside a git repo, AND
#   - that repo has no gortex integration, AND
#   - the repo hasn't opted out via a .gortex-skip marker.
# When all hold, it prints guidance (added to the session as context) telling
# Claude to ASK whether to run `gortex init` — never to run it unprompted.
set -u

# Claude passes the session JSON on stdin; pull cwd from it, fall back to $PWD.
cwd="$(jq -r '.cwd // empty' 2>/dev/null)"
[ -n "$cwd" ] || cwd="$PWD"

# Only relevant inside a git repo.
root="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)" || exit 0
[ -n "$root" ] || exit 0

# Already integrated, or explicitly silenced → say nothing.
[ -e "$root/.gortex.yaml" ] && exit 0
[ -e "$root/.gortex-skip" ] && exit 0
grep -qs '"gortex"' "$root/.mcp.json" 2>/dev/null && exit 0

cat <<EOF
This repository ($root) is not integrated with gortex — no .gortex.yaml and no
gortex MCP server in .mcp.json. Gortex (a code-intelligence engine / MCP server)
is installed on this machine. Ask the user ONCE, early, whether they'd like to
wire it up by running \`gortex init\` (per-repo code-intelligence + MCP for the
detected assistants). Do not run it without their explicit confirmation. If they
decline, drop the topic for this session — they can create an empty .gortex-skip
file in the repo root to silence this nudge permanently.
EOF
