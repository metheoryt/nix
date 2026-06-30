# Codex Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Manage OpenAI Codex's config like the existing Claude setup — git-tracked, symlinked into `~/.codex`, wired on Linux (a home module) and Windows (`bootstrap.sh`), sharing one source of truth with Claude.

**Architecture:** `claude/` stays canonical for all tool-agnostic content (memory, hook scripts, skills, the instruction file). A thin new `codex/` dir holds only the format-divergent files (`hooks.json`, `agents/*.toml`). `~/.codex` symlinks point at `claude/` for shared content and `codex/` for divergent. The global + repo-root instruction files flip so `AGENTS.md` is the real file and `CLAUDE.md` a symlink to it (Claude Code does not read `AGENTS.md` natively).

**Tech Stack:** Bash (Git Bash on Windows), Nix / Home Manager (`mkOutOfStoreSymlink`), TOML, JSON.

## Global Constraints

- **Single source of truth:** shared content (memory `*.md`, hook scripts `*.sh`, skills) lives ONLY under `claude/` and is symlinked into both `~/.claude` and `~/.codex`. Never duplicate it into `codex/`.
- **`codex/` tracks ONLY** `hooks.json`, `agents/*.toml`, `.gitignore`, `.gitattributes`. Everything else under `~/.codex` is machine-local and gitignored.
- **`AGENTS.md` is the canonical instruction file**; `CLAUDE.md` is an in-repo symlink → `AGENTS.md` (both global `claude/` and repo root).
- **Never track** `config.toml`, `auth.json`, sessions, sqlite, caches (machine-local, like the statusline).
- **Line endings:** all files under `codex/` are `text eol=lf` (bash/json/toml consumed cross-platform; CRLF breaks shebangs).
- **Windows symlinks** require `core.symlinks=true` + Developer Mode (already required by the existing bootstrap).
- **Commit trailer:** end every commit message with `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.
- **Stage files by name** — never `git add -A`/`git add .` (skip the untracked `claude/settings.json` working change unless a step says otherwise).

---

### Task 1: Flip instruction files to `AGENTS.md` canonical

Make `AGENTS.md` the real tracked file and `CLAUDE.md` a symlink to it, in both `claude/` (global) and the repo root (project). Nothing breaks: Claude still reads `CLAUDE.md`, which resolves to `AGENTS.md`.

**Files:**
- Rename: `claude/CLAUDE.md` → `claude/AGENTS.md`; create symlink `claude/CLAUDE.md` → `AGENTS.md`
- Rename: `CLAUDE.md` → `AGENTS.md`; create symlink `CLAUDE.md` → `AGENTS.md`
- Delete: the untracked root `AGENTS.md` (the partial transformed copy) before the rename

**Interfaces:**
- Produces: `claude/AGENTS.md` (canonical global instruction file — Task 3 bootstrap and Task 4 codex.nix link `~/.codex/AGENTS.md` and `~/.claude/CLAUDE.md` to it); root `AGENTS.md` (canonical project file).

- [ ] **Step 1: Remove the untracked transformed root AGENTS.md**

```bash
cd "C:/Users/methe/GitHub/nix"
rm -f AGENTS.md
git status --short AGENTS.md   # expect: no output (gone, was untracked)
```

- [ ] **Step 2: Flip the global instruction file**

```bash
cd "C:/Users/methe/GitHub/nix"
git mv claude/CLAUDE.md claude/AGENTS.md
ln -s AGENTS.md claude/CLAUDE.md
git add claude/CLAUDE.md
```

- [ ] **Step 3: Flip the root instruction file**

```bash
cd "C:/Users/methe/GitHub/nix"
git mv CLAUDE.md AGENTS.md
ln -s AGENTS.md CLAUDE.md
git add CLAUDE.md
```

- [ ] **Step 4: Verify the symlinks resolve to the real files**

```bash
cd "C:/Users/methe/GitHub/nix"
readlink claude/CLAUDE.md          # expect: AGENTS.md
readlink CLAUDE.md                 # expect: AGENTS.md
head -1 claude/CLAUDE.md           # expect: "## MANDATORY: Use Gortex MCP tools instead of Read/Grep/Glob"
head -1 CLAUDE.md                  # expect: "# CLAUDE.md" (root project file's first line)
git diff --cached --stat           # expect: renames claude/CLAUDE.md->AGENTS.md, CLAUDE.md->AGENTS.md + 2 new symlinks
```

Note: git records the symlinks as mode `120000` blobs whose content is the target path. If `readlink` returns the literal text instead of resolving (Windows without `core.symlinks`), run `git config core.symlinks true` and re-check out; the bootstrap already requires Developer Mode.

- [ ] **Step 5: Commit**

```bash
cd "C:/Users/methe/GitHub/nix"
git commit -m "$(cat <<'EOF'
config: make AGENTS.md the canonical instruction file

Claude Code does not read AGENTS.md natively, so AGENTS.md is now the real
file and CLAUDE.md a symlink to it, for both the global (claude/) and
repo-root instruction files. Single source, each tool reads its filename.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
git status --short   # expect: clean except the pre-existing claude/settings.json change
```

---

### Task 2: Scaffold the `codex/` directory

Create the thin `codex/` dir with only the format-divergent tracked files, plus the defensive gitignore/gitattributes and the root `.openclaude/` ignore.

**Files:**
- Create: `codex/hooks.json`
- Create: `codex/agents/quick-tasks.toml`
- Create: `codex/.gitignore`
- Create: `codex/.gitattributes`
- Modify: `.gitignore` (root — add `.openclaude/`)

**Interfaces:**
- Produces: `codex/hooks.json` and `codex/agents/quick-tasks.toml` (Task 3 bootstrap and Task 4 codex.nix link these into `~/.codex`).

- [ ] **Step 1: Create `codex/hooks.json`**

Mirrors the two SessionStart hooks tracked in `claude/settings.json`, with `$HOME/.codex/...` paths (Codex runs the command through bash, which expands `$HOME`). The gortex enforcement hooks are intentionally NOT tracked (machine-local, machine-specific paths).

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$HOME/.codex/hooks/gortex-onboard-check.sh\""
          },
          {
            "type": "command",
            "command": "bash \"$HOME/.codex/hooks/project-memory-check.sh\""
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 2: Create `codex/agents/quick-tasks.toml`**

Converted from `claude/agents/quick-tasks.md`, following the proven shape of the imported `~/.codex/agents/gortex-search.toml` (`name` / `description` / `developer_instructions`). The `model` / `tools` frontmatter fields are dropped — the imported Codex agent TOMLs do not carry them. `description` uses a double-quoted string because it contains an apostrophe ("doesn't").

```toml
name = "quick-tasks"
description = "Handles routine, one-step dev tasks — git commits, status checks, branch operations, running linters/formatters, and similar simple commands. Use proactively whenever the user asks to commit, check status, push, run a linter, or do any other short repeatable task that doesn't require editing code."
developer_instructions = """
You handle simple, routine developer tasks quickly and correctly. Your specialty is git operations and one-step commands (linting, formatting, running scripts).

For git commits:
- Run `git status` and `git diff --staged` (or `git diff HEAD`) to understand what changed
- Check recent `git log --oneline -5` to match the repo's commit message style
- Stage specific files by name — never `git add -A` or `git add .` blindly; skip secrets and binaries
- Write a concise commit message focused on the *why*, not the *what*
- Always append a Co-Authored-By trailer:
  Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
- Pass the message via HEREDOC to avoid quoting issues:
  git commit -m "$(cat <<'EOF'
  message here

  Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
  EOF
  )"
- Run `git status` after to confirm success

For all other tasks:
- Run exactly what's asked, nothing more — don't expand scope
- Don't create files or edit code; if the task requires that, say so and stop
- Report the result in one or two sentences

Keep responses short.
"""
```

- [ ] **Step 3: Create `codex/.gitignore`**

```gitignore
# Defensive: this directory holds ONLY the version-controlled Codex config
# (hooks.json + agents/*.toml). Codex shares memory, hook scripts and skills
# from claude/ (single source of truth) — those are NOT copied here. Secrets,
# machine-local config, sessions and caches live in ~/.codex and must never be
# tracked here even if something copies them in.

# Secrets & machine-local config
auth.json
.env
.credentials.json
config.toml
.codex-global-state.json
.codex-global-state.json.bak
installation_id
cap_sid
.personality_migration
models_cache.json

# SQLite / sessions / logs (auto-regenerated)
*.sqlite
*.sqlite-shm
*.sqlite-wal
sqlite/
sessions/
session_index.jsonl
external_agent_session_imports.json

# Caches & runtime dirs (auto-regenerated)
cache/
.tmp/
tmp/
.sandbox/
node_repl/
process_manager/
computer-use/
ambient-suggestions/
vendor_imports/

# Plugins — marketplace-managed, hold absolute paths, regenerated on launch
plugins/

# Backups created by bootstrap.sh
*.bak
.bootstrap-bak/

# Python bytecode
__pycache__/
*.pyc
```

- [ ] **Step 4: Create `codex/.gitattributes`**

```gitattributes
# Consumed by bash / json / toml parsers on Windows (Git Bash), macOS and Linux.
# Force LF in the working tree everywhere — CRLF breaks bash shebangs and confuses
# parsers on the symlinked files. Everything here is text; there are no binaries.
* text eol=lf
```

- [ ] **Step 5: Add `.openclaude/` to the root `.gitignore`**

Append to `.gitignore` (root). The file currently ends with the `.claude/settings.local.json` block (around line 38).

```gitignore

# OpenClaude per-repo local state — machine-local, keep out of git
.openclaude/
```

- [ ] **Step 6: Validate JSON and check the ignores work**

```bash
cd "C:/Users/methe/GitHub/nix"
python -m json.tool codex/hooks.json >/dev/null && echo "hooks.json OK"   # expect: hooks.json OK
git check-ignore codex/config.toml codex/auth.json codex/x.sqlite          # expect: all three printed (ignored)
git check-ignore -v codex/hooks.json; echo "exit=$?"                       # expect: exit=1 (NOT ignored — tracked)
git check-ignore .openclaude/                                              # expect: .openclaude/ printed (ignored)
```

If `python` is unavailable, validate `codex/hooks.json` by eye against Step 1 (it is a copy) — it must be well-formed JSON.

- [ ] **Step 7: Commit**

```bash
cd "C:/Users/methe/GitHub/nix"
git add codex/hooks.json codex/agents/quick-tasks.toml codex/.gitignore codex/.gitattributes .gitignore
git commit -m "$(cat <<'EOF'
codex: scaffold tracked config dir

Adds the thin codex/ dir: hooks.json (the two SessionStart hooks, mirrored
from claude/settings.json) and agents/quick-tasks.toml (converted from the
Claude .md agent). Defensive .gitignore/.gitattributes keep machine-local
~/.codex state untracked. Also ignores .openclaude/ at the repo root.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Extend `bootstrap.sh` for Codex (Windows / portable path)

Generalize the entry-linking helper, retarget the Claude instruction-file link to `AGENTS.md`, and add a Codex linking pass. This is the immediately end-to-end-testable path on Windows.

**Files:**
- Modify: `claude/bootstrap.sh` (replace `link_entries` with `link_entries_into`; retarget line 146; add Codex pass after the Claude entry links)

**Interfaces:**
- Consumes: `claude/AGENTS.md` (Task 1), `codex/hooks.json` + `codex/agents/quick-tasks.toml` (Task 2), shared `claude/memory/*`, `claude/hosts/<host>.md`, `claude/skills/*`, `claude/hooks/*`.
- Produces: working `~/.codex` symlink tree.

- [ ] **Step 1: Replace `link_entries` with a generalized `link_entries_into`**

Replace the whole `link_entries` function (currently lines 119–133) with:

```bash
# link_entries_into <abs-src-sub> <abs-dest-sub>: symlink each ENTRY inside the
# source subdir into the dest subdir individually, so machine-local additions
# coexist with tracked ones.
link_entries_into() {
  local src_sub="$1" dest_sub="$2"
  [ -d "$src_sub" ] || return
  mkdir -p "$dest_sub"
  local entry base
  for entry in "$src_sub"/* "$src_sub"/.[!.]*; do
    [ -e "$entry" ] || continue           # no matches → skip the literal glob
    base="$(basename "$entry")"
    [ "$base" = ".gitkeep" ] && continue  # placeholder, not real config
    link "$entry" "$dest_sub/$base"
  done
}
```

- [ ] **Step 2: Update the four Claude entry-link calls**

Replace the block (currently lines 170–173):

```bash
link_entries skills
link_entries agents
link_entries commands
link_entries hooks
```

with:

```bash
link_entries_into "$SRC_DIR/skills"   "$CLAUDE_DIR/skills"
link_entries_into "$SRC_DIR/agents"   "$CLAUDE_DIR/agents"
link_entries_into "$SRC_DIR/commands" "$CLAUDE_DIR/commands"
link_entries_into "$SRC_DIR/hooks"    "$CLAUDE_DIR/hooks"
```

- [ ] **Step 3: Retarget the Claude instruction-file link to the canonical AGENTS.md**

Replace line 146:

```bash
link "$SRC_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
```

with:

```bash
# Instruction file: AGENTS.md is canonical; link ~/.claude/CLAUDE.md to it directly.
link "$SRC_DIR/AGENTS.md" "$CLAUDE_DIR/CLAUDE.md"
```

- [ ] **Step 4: Add the Codex linking pass**

Insert this block immediately AFTER the four `link_entries_into` Claude calls (Step 2) and BEFORE the `install_git_hooks` comment (currently line 175):

```bash
# ── Codex config (~/.codex) ─────────────────────────────────────────────────
# Codex is Claude-Code-compatible: it SHARES memory, hook scripts and skills from
# claude/ (single source of truth); only the format-divergent files live in
# codex/ (hooks.json, agents/*.toml). config.toml / auth / sessions stay
# machine-local — see codex/.gitignore. HOST_ID / host_src are reused from the
# Claude section above.
CODEX_SRC="$(cd "$SRC_DIR/../codex" && pwd)"
CODEX_DIR="${CODEX_CONFIG_DIR:-$HOME/.codex}"
mkdir -p "$CODEX_DIR"
printf '\nBootstrapping Codex config\n  live:  %s\n\n' "$CODEX_DIR"

# Instruction file: Codex reads AGENTS.md; point at claude/AGENTS.md (canonical).
link "$SRC_DIR/AGENTS.md" "$CODEX_DIR/AGENTS.md"

# Shared memory & per-host file (same sources Claude uses).
mkdir -p "$CODEX_DIR/memory"
link "$SRC_DIR/memory/global.md"    "$CODEX_DIR/memory/global.md"
link "$SRC_DIR/memory/practices.md" "$CODEX_DIR/memory/practices.md"
link "$host_src"                    "$CODEX_DIR/host-memory.md"

# Codex-specific standalone hooks file.
link "$CODEX_SRC/hooks.json" "$CODEX_DIR/hooks.json"

# Entry dirs: skills + hook scripts shared from claude/; agents from codex/.
link_entries_into "$SRC_DIR/skills"   "$CODEX_DIR/skills"
link_entries_into "$SRC_DIR/hooks"    "$CODEX_DIR/hooks"
link_entries_into "$CODEX_SRC/agents" "$CODEX_DIR/agents"
```

Note: the existing real files at `~/.codex/AGENTS.md` (mangled) and `~/.codex/hooks.json` get backed up by `backup_target` before being replaced. Because that helper computes its backup path relative to `CLAUDE_DIR`, the codex backups land under `~/.claude/.bootstrap-bak/` with an absolute-style subpath — cosmetically odd but recoverable. Acceptable for this one-time migration.

- [ ] **Step 5: Run the bootstrap and verify the Codex links resolve**

```bash
cd "C:/Users/methe/GitHub/nix"
bash claude/bootstrap.sh
```

Expected tail: `Done. linked=N  skipped=M  backed-up=K  failed=0` (failed MUST be 0).

```bash
# AGENTS.md resolves to the canonical file (gortex rules header)
head -1 ~/.codex/AGENTS.md          # expect: "## MANDATORY: Use Gortex MCP tools instead of Read/Grep/Glob"
# memory @imports no longer dangle
ls -l ~/.codex/memory/global.md ~/.codex/memory/practices.md ~/.codex/host-memory.md
# hook scripts now present (hooks.json referenced these)
ls -l ~/.codex/hooks/gortex-onboard-check.sh ~/.codex/hooks/project-memory-check.sh
# skills shared from claude/
ls ~/.codex/skills                  # expect: gortex-align  update-balance
# codex-specific files
readlink ~/.codex/hooks.json        # expect: .../nix/codex/hooks.json
ls ~/.codex/agents                  # expect: quick-tasks.toml (+ any machine-local gortex *.toml)
# claude side still good after retarget
head -1 ~/.claude/CLAUDE.md         # expect: same gortex rules header
```

- [ ] **Step 6: Commit**

```bash
cd "C:/Users/methe/GitHub/nix"
git add claude/bootstrap.sh
git commit -m "$(cat <<'EOF'
bootstrap: wire Codex config into ~/.codex

Generalizes link_entries to link_entries_into (explicit src+dest), retargets
the Claude instruction link to the canonical AGENTS.md, and adds a Codex pass
that shares memory/hook-scripts/skills from claude/ and links the codex/
divergent files. Fixes the partial import's dangling @imports and missing
hook scripts.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Add `codex.nix` home module + wire into `me.nix` (Linux)

Mirror `claude.nix` for `~/.codex`, import it, and add the `codex` package to the dev bundle. Nix evaluation is validated on a Linux host (or the dev shell); the Bash tool on Windows cannot run `nix`.

**Files:**
- Create: `modules/home/codex.nix`
- Modify: `modules/home/me.nix` (add `./codex.nix` to `imports`; add `codex` to `home.packages`)
- Modify: `modules/home/claude.nix:55` (retarget the Claude instruction link to `AGENTS.md`)

**Interfaces:**
- Consumes: `claude/AGENTS.md`, `claude/memory/*`, `claude/hosts/<host>.md`, `claude/skills`, `claude/hooks`, `codex/hooks.json`, `codex/agents`.
- Produces: the same `~/.codex` link tree as Task 3, declaratively on NixOS.

- [ ] **Step 1: Retarget the Claude instruction link in `claude.nix`**

In `modules/home/claude.nix`, replace line 55:

```nix
      ".claude/CLAUDE.md".source = link "${claude}/CLAUDE.md";
```

with:

```nix
      # AGENTS.md is canonical; ~/.claude/CLAUDE.md links straight to the real file.
      ".claude/CLAUDE.md".source = link "${claude}/AGENTS.md";
```

- [ ] **Step 2: Create `modules/home/codex.nix`**

```nix
# Codex config, version-controlled in this repo and symlinked into ~/.codex.
# Codex is Claude-Code-compatible, so it SHARES the tool-agnostic content
# (memory, hook scripts, skills) from claude/ — single source of truth. Only the
# format-divergent files live in codex/ (hooks.json, agents/*.toml). The global
# instruction file is claude/AGENTS.md (the canonical real file; claude/CLAUDE.md
# is a symlink to it). config.toml / auth / sessions stay machine-local and are
# NOT linked (see codex/.gitignore). Windows uses claude/bootstrap.sh, which
# produces the identical links.
{
  config,
  osConfig,
  lib,
  ...
}: let
  claude = "${config.home.homeDirectory}/nix/claude";
  codex = "${config.home.homeDirectory}/nix/codex";
  link = config.lib.file.mkOutOfStoreSymlink;

  # Symlink each entry inside <base>/<sub> into ~/.codex/<sub> individually, so
  # machine-local additions (e.g. gortex's own agents) coexist with tracked ones.
  # `srcDir` is the in-tree path literal (enumerates names — pure-eval safe); the
  # symlink target stays the out-of-store `base` string so edits stay live.
  linkEntries = sub: base: srcDir:
    lib.mapAttrs'
    (name: _:
      lib.nameValuePair ".codex/${sub}/${name}" {
        source = link "${base}/${sub}/${name}";
      })
    (lib.filterAttrs (name: _: name != ".gitkeep") (builtins.readDir srcDir));
in {
  home.file =
    {
      # Instruction file: Codex reads AGENTS.md; point at the canonical real file.
      ".codex/AGENTS.md".source = link "${claude}/AGENTS.md";

      # Codex-specific standalone hooks file.
      ".codex/hooks.json".source = link "${codex}/hooks.json";

      # Shared memory & per-host file (same sources Claude uses).
      ".codex/memory/global.md".source = link "${claude}/memory/global.md";
      ".codex/memory/practices.md".source = link "${claude}/memory/practices.md";
      ".codex/host-memory.md".source = link "${claude}/hosts/${osConfig.networking.hostName}.md";
    }
    # Shared from claude/: skills + hook scripts. Codex-specific: agents.
    // linkEntries "skills" claude ../../claude/skills
    // linkEntries "hooks" claude ../../claude/hooks
    // linkEntries "agents" codex ../../codex/agents;
}
```

- [ ] **Step 3: Import `codex.nix` in `me.nix`**

In `modules/home/me.nix`, the `imports` list has `./claude.nix` at line 20. Add `./codex.nix` right after it:

```nix
    # Claude Code config: version-controlled in claude/, symlinked into ~/.claude
    ./claude.nix
    # Codex config: shares claude/ content, codex/-specific files, symlinked into ~/.codex
    ./codex.nix
```

- [ ] **Step 4: Resolve the `codex` package attribute, then add it to the dev bundle**

Find the right attribute (the Windows install is the OpenAI Codex desktop/Sky build; nixpkgs likely ships the leaner CLI). On a host with Nix:

```bash
nix search nixpkgs '^codex$' 2>/dev/null || nix search nixpkgs codex | head -30
```

- If `legacyPackages...codex` appears → use the bare attr `codex`.
- If it lives under another name (e.g. `codex-cli`) → use that.
- If absent from this pinned nixpkgs → it needs a flake input/overlay like `claude-code` uses (`claude-code-nix`); stop and report to the user rather than guessing an input.

Then add it to `home.packages` in `modules/home/me.nix`, next to `claude-code` (line 36):

```nix
    claude-code
    codex # OpenAI Codex CLI (config synced via codex.nix)
    sox # for claude /voice audio recording
```

(Replace `codex` with the resolved attribute from the search if it differs.)

- [ ] **Step 5: Validate the flake evaluates (Linux host or dev shell)**

```bash
just quick     # fast syntax check (alejandra/nil) — must pass
just check     # nix flake check — must evaluate with codex.nix imported and the package resolved
```

Expected: both succeed. On Windows without Nix, defer this step to a NixOS host (`g16`/`latitude5520`) or `just shell`; do not mark complete until it passes somewhere with Nix.

- [ ] **Step 6: Commit**

```bash
cd "C:/Users/methe/GitHub/nix"
git add modules/home/codex.nix modules/home/me.nix modules/home/claude.nix
git commit -m "$(cat <<'EOF'
nix: add codex.nix home module + codex to the dev bundle

Mirrors claude.nix for ~/.codex (shares claude/ memory/hooks/skills, links
codex/-specific hooks.json + agents), imports it in me.nix, retargets the
Claude instruction link to the canonical AGENTS.md, and adds the codex
package to home.packages.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: End-to-end verification & mark the spec implemented

Confirm the full setup works and record completion. No code; a final integration gate + a docs commit.

**Files:**
- Modify: `docs/superpowers/specs/2026-06-30-codex-support-design.md` (flip Status to implemented)

- [ ] **Step 1: Confirm the tracked surface is exactly what was intended**

```bash
cd "C:/Users/methe/GitHub/nix"
git ls-files codex/    # expect ONLY: codex/.gitattributes codex/.gitignore codex/agents/quick-tasks.toml codex/hooks.json
git status --short     # expect: clean (aside from the pre-existing claude/settings.json change)
```

- [ ] **Step 2: Confirm no dangling references in Codex's config**

```bash
# Every @import in AGENTS.md resolves under ~/.codex
for f in memory/global.md memory/practices.md host-memory.md; do
  test -e ~/.codex/"$f" && echo "OK $f" || echo "MISSING $f"
done   # expect: three OK lines
# Every hook command path in hooks.json exists
test -e ~/.codex/hooks/gortex-onboard-check.sh && test -e ~/.codex/hooks/project-memory-check.sh && echo "hooks OK"
```

- [ ] **Step 3: Manual acceptance — launch Codex**

Start Codex in this repo and confirm: it loads `AGENTS.md` (gortex rules present), the SessionStart hooks fire without "file not found", and the `quick-tasks` agent + shared skills are listed. (Manual — record the result.)

- [ ] **Step 4: Mark the spec implemented and commit**

In `docs/superpowers/specs/2026-06-30-codex-support-design.md`, change the Status line:

```markdown
**Status:** Implemented (2026-06-30)
```

```bash
cd "C:/Users/methe/GitHub/nix"
git add docs/superpowers/specs/2026-06-30-codex-support-design.md
git commit -m "$(cat <<'EOF'
docs: mark Codex support spec implemented

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Notes for the implementer

- **Push:** the plan commits locally only. Push when the user asks (and pull/rebase onto `origin/main` first per repo convention).
- **Windows vs Linux split:** Tasks 1–3 + 5 are fully verifiable on this Windows machine via Git Bash. Task 4's `just quick`/`just check` need the Nix toolchain — validate on a NixOS host or in `just shell`.
- **Don't touch** the pre-existing uncommitted `claude/settings.json` change; it's unrelated to this work.
