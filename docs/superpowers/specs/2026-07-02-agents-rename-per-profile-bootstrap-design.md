# Design: generalize `claude/` → `agents/` + per-profile bootstrap

**Date:** 2026-07-02
**Status:** approved (pending spec review)

## Problem

The synced agent config is no longer Claude-specific — it feeds Claude Code
(`~/.claude`), Codex (`~/.codex`), and now a distinct **work profile**
(`~/.claude-work`, invoked as `ccw` = `CLAUDE_CONFIG_DIR=~/.claude-work claude`).
Two things follow from that:

1. **Naming.** The source-of-truth dir is called `claude/` and the justfile
   recipe `claude-bootstrap`, which no longer reflects reality. Standardize on the
   popular agent-config convention (`AGENTS.md`) and a general `agents/` name.
2. **Multi-profile bootstrap.** `bootstrap.sh` keys off `$CLAUDE_CONFIG_DIR` and
   links the *entire* personal config (including `settings.json`, `statusline`)
   into whatever that points at. Run from a `ccw` shell it therefore **clobbers
   the work profile's `settings.json`** (which holds `PURE_SENTRY_TOKEN` + a
   different plugin set) — this actually happened during design and had to be
   restored from the bootstrap backup. We want per-profile bootstrap to be a
   safe, intentional operation instead of a footgun.

## Goals

- Rename the committed structure to an agent-neutral scheme.
- Make `bootstrap.sh` profile-aware: link the right subset into whatever profile
  it is run from, never overwriting a secondary profile's own `settings.json`.
- Run bootstrap once per profile (personal, work); Codex rides with the personal
  run.
- Preserve git history for moved files.

## Non-goals

- Renaming the tool-dictated config dirs (`~/.claude`, `~/.claude-work`,
  `~/.codex`) or the `CLAUDE.md` filename Claude Code reads — those are fixed by
  the harnesses.
- Managing the work profile through Nix. The work profile is bootstrap-managed;
  Nix continues to own `~/.claude` (personal) and `~/.codex` only.

## Directory layout (after)

```
agents/                       (was claude/ — single source of truth)
├── AGENTS.md                 canonical instructions
├── CLAUDE.md → AGENTS.md     (Claude Code reads CLAUDE.md)
├── memory/{global,practices}.md
├── hosts/<hostname>.md
├── hooks/*.sh
├── skills/*/
├── subagents/*.md            (was agents/ — renamed to avoid agents/agents/)
├── commands/
├── settings.json             personal-only
├── statusline-command.sh     shared
├── balance-refresh.py        shared
├── bootstrap.sh
├── git-hooks/
└── codex/                    (was top-level codex/ — folded in)
    ├── hooks.json
    └── subagents/*.toml       (was codex/agents/)
```

All moves via `git mv` to preserve history.

## Sharing tiers

| Tier | Files | Linked into |
|---|---|---|
| **Shared** | `AGENTS.md` (→`CLAUDE.md`), `memory/`, `hosts/` (→`host-memory.md`), `hooks/`, `skills/`, `subagents/`, `commands/`, `statusline-command.sh`, `balance-refresh.py` | **every** profile bootstrapped |
| **Personal-only** | `settings.json` | default `~/.claude` only |

- A **secondary profile owns its own `settings.json`** (its secret + plugin set).
  Bootstrap never writes it.
- Registering shared hooks (e.g. `global-memory-load.sh`) in a secondary
  profile's `settings.json` SessionStart is a **one-time manual edit** — already
  done for `~/.claude-work` (its SessionStart now runs the memory loader).
- `statusline-command.sh` and `balance-refresh.py` are `$CLAUDE_CONFIG_DIR`-aware,
  so sharing them is safe. **Implication:** the work profile's old custom
  statusline is replaced by the shared one on next bootstrap (accepted).
- **Codex** keeps its current tool-neutral subset only (memory, hosts, hooks,
  skills, `subagents/*.toml`, `AGENTS.md`) — no `statusline`/`settings.json`, as
  today.

## `bootstrap.sh` redesign

Target profile = `${CLAUDE_CONFIG_DIR:-$HOME/.claude}`. Classify by comparing the
resolved target path to `$HOME/.claude`:

- **Personal run** (`CLAUDE_CONFIG_DIR` unset or resolves to `~/.claude`):
  link **shared + personal-only** into `~/.claude`, **and** link Codex's subset
  into `~/.codex` (Codex rides with the personal run).
- **Secondary run** (e.g. `ccw` → `CLAUDE_CONFIG_DIR=~/.claude-work`):
  link **shared only** into that dir. Skip `settings.json`. Skip Codex.

This converts the clobber footgun into correct behavior: bootstrapping from `ccw`
now safely links the work profile.

Usage:

```
# personal (also sets up ~/.codex)
bash agents/bootstrap.sh

# work profile
CLAUDE_CONFIG_DIR=~/.claude-work bash agents/bootstrap.sh   # or: run from a ccw shell
```

The existing safety machinery is retained: back up any real file before
replacing with a symlink, entry-by-entry linking so machine-local additions
survive, idempotent re-runs, `linked=/skipped=/failed=` summary.

## Nix + reference updates

- `modules/home/claude.nix` / `codex.nix`: repoint the source path var
  `claude` → `agents`, `codex` → `agents/codex`, inner `agents` → `subagents`.
  **Module filenames stay** (`claude.nix`/`codex.nix`) — they name the *target*
  (`~/.claude` / `~/.codex`), not the source; renaming them is churn for no gain.
- **Source-dir vs target-dir decoupling** (important): the subagent definitions
  move to source `subagents/`, but the tool target stays `agents/` (Claude reads
  `~/.claude/agents/`, Codex reads `~/.codex/agents/`). The link helpers currently
  assume source-subdir name == target-subdir name; they must be adjusted to map
  source `subagents/` → target `agents/`. Affects Nix `linkEntries` (in both
  `claude.nix` and `codex.nix`) and `bootstrap.sh` `link_entries_into`. Every
  other shared subdir keeps identical source/target names.
- **Revert the interim stopgaps added during this session:**
  - the `.claude-work/*` `home.file` block in `claude.nix` (work profile is
    bootstrap-managed now, not Nix-managed).
  - the `WORK_DIR` block in `bootstrap.sh` (superseded by the generic
    per-profile logic).
- Repoint hardcoded `claude/bootstrap.sh` paths:
  - `justfile`: rename recipe `claude-bootstrap` → **`agent-bootstrap`** (personal
    run; forces the personal profile via `env -u CLAUDE_CONFIG_DIR` so
    `just switch`/`update` always target personal regardless of shell), and add
    **`agent-bootstrap-work`** (`CLAUDE_CONFIG_DIR=~/.claude-work`). Update the two
    call sites (`switch`, `update`).
  - `git-hooks/_refresh-claude-config`: `$repo/claude/bootstrap.sh` →
    `$repo/agents/bootstrap.sh`.
- Update docs to the new names/paths: `README.md`, `AGENTS.md` self-docs
  (persistent-memory section), `hosts/*.md` Windows notes.

## Migration / rollout

1. `git mv claude → agents`, `agents/agents → agents/subagents`,
   `codex → agents/codex`, `agents/codex/agents → agents/codex/subagents`.
2. Apply the source-path edits (Nix modules, bootstrap logic, justfile,
   git-hook, docs); revert the two interim stopgaps.
3. Re-point live symlinks: run `agent-bootstrap` (personal) from a normal shell,
   `agent-bootstrap-work` (or from `ccw`) for the work profile. On NixOS,
   `just switch` re-links `~/.claude`/`~/.codex` declaratively.
4. `~/.claude-work/settings.json` already registers `global-memory-load.sh` — no
   further manual step there.
5. Validate: `just quick` / `nix flake check`; run each bootstrap and confirm
   `failed=0` and that `~/.claude-work/settings.json` (secret + work plugins) is
   untouched.

## Risks

- **Broad rename** touches many references; a missed hardcoded `claude/` path
  breaks linking. Mitigation: grep sweep for `claude/` (excluding tool dirs
  `~/.claude`, `CLAUDE.md`) after the edits; `bootstrap.sh` `failed=0` check.
- **Running `agent-bootstrap` from the wrong shell** — mitigated by
  `env -u CLAUDE_CONFIG_DIR` in the personal recipe and an explicit
  `-work` recipe.
- **NixOS vs bootstrap race** for `~/.claude` is unchanged from today
  (`_refresh-claude-config` already no-ops on NixOS).
