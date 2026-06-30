# Codex support, synced to the Claude setup

**Date:** 2026-06-30
**Status:** Implemented (2026-06-30)

## Goal

Manage OpenAI Codex's config the same way this repo already manages Claude Code:
git-tracked, symlinked into the live config dir, wired on both Linux (NixOS, via a
home module) and Windows (via `bootstrap.sh`). Keep Codex in sync with Claude so a
skill / hook / memory added once is available in both tools.

## Guiding principle

`claude/` stays the **single source of truth** for all tool-agnostic content
(memory, hook scripts, skills, the global instruction file). Codex gets its own
symlinks into `~/.codex`, most of which point back into `claude/`. A thin new
`codex/` dir holds only the two genuinely Codex-format files. `config.toml` is
treated like the statusline: machine-local, never synced.

## Context — current state (why this is needed)

The user installed Codex and did a one-shot import from Claude. It is partial and
partly broken:

- `~/.codex/AGENTS.md` exists (a sed-transformed copy of `claude/CLAUDE.md`) but
  has **mangled paths** (`.Codex/memory/project.md`, `Codex.local.md`, `~/.Codex/`).
- `~/.codex/memory/` **does not exist** → the three `@import` lines in `AGENTS.md`
  (`memory/global.md`, `memory/practices.md`, `host-memory.md`) dangle.
- `~/.codex/hooks/` is **empty** → `hooks.json` references
  `gortex-onboard-check.sh` + `project-memory-check.sh` that aren't there.
- `~/.codex/skills/` has **no user skills** (`gortex-align`, `update-balance`
  missing).
- Only `gortex-search.toml` / `gortex-impact.toml` agents were converted;
  `quick-tasks` was not.
- None of it is git-tracked or symlinked the way `claude/` is.

This "Codex" is Claude-Code-compatible: same hooks-JSON schema, same
`claude-plugins-official` marketplace, `skills/` / `agents/` / `hooks/` dirs, and
`AGENTS.md` as the global instruction file (with `@import` support).

## Format divergences (what cannot just be symlinked from `claude/`)

| Concern          | Claude                     | Codex                        | Shared source? |
|------------------|----------------------------|------------------------------|----------------|
| Instruction file | `CLAUDE.md`                | `AGENTS.md`                  | Yes — symlink AGENTS.md → CLAUDE.md |
| Memory `*.md`    | `memory/*.md`              | same names, `@import`ed      | Yes |
| Per-host memory  | `hosts/<host>.md`          | `host-memory.md`             | Yes |
| Hook scripts     | `hooks/*.sh`               | `hooks/*.sh`                 | Yes |
| Skills           | `skills/<name>/`           | `skills/<name>/`             | Yes |
| Hook wiring      | block in `settings.json`   | standalone `hooks.json`      | No — codex-specific |
| Agents           | `*.md` frontmatter         | `*.toml`                     | No — codex-specific |
| Settings         | `settings.json`            | `config.toml` (machine-local)| No — not synced |
| Statusline/balance | scripts                  | n/a                          | Not synced |

## Decisions (locked during brainstorming)

1. **Sync model:** single source of truth — shared content lives under `claude/`
   and is symlinked into both `~/.claude` and `~/.codex`. Only divergent files
   live in a new `codex/` dir.
2. **Global instruction file — `AGENTS.md` is canonical:** Claude Code does **not**
   read `AGENTS.md` natively (anthropics/claude-code #34235, still unimplemented as
   of 2026-03; no reliable fallback). So the single real file is **`claude/AGENTS.md`**
   and `claude/CLAUDE.md` becomes an **in-repo git symlink → `AGENTS.md`**. Live
   links: `~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md` both point at
   `claude/AGENTS.md`. One real file, edited in one place; each tool reads its
   expected filename. (The "Claude" wording in the text is accepted — the rules are
   tool-agnostic.)
3. **Platforms:** both — new `modules/home/codex.nix` (Linux) **and** extended
   `claude/bootstrap.sh` (Windows). Codex wired on `g16`, `latitude5520`, and the
   Windows machine.
4. **Gortex enforcement hooks** (the `consult-unlock` / Read-Grep-Glob deny
   entries currently in `~/.codex/hooks.json`) are **not tracked** — they embed a
   machine-specific `gortex.exe` absolute path and are not tracked on the Claude
   side either. Machine-local concern, re-applied by gortex's own tooling.
   Trade-off: the symlinked `hooks.json` replaces the current one, so those
   entries drop until gortex re-adds them.
5. **`config.toml` not synced** — machine-local paths (computer-use exe,
   runtimes), auth, marketplace/plugin state, per-project trust. Like the
   statusline.
6. **Gortex sub-agents** (`gortex-search/impact.toml`) **not tracked** —
   gortex-provided, not in `claude/agents` either. Left machine-local;
   `link_entries` coexists with them.
7. **Repo-root instruction file — `AGENTS.md` canonical:** same flip as the global
   file. Root **`AGENTS.md`** is the real tracked project-instruction file; root
   **`CLAUDE.md`** becomes a **git symlink → `AGENTS.md`**. Relies on the same
   `core.symlinks` + Windows Developer Mode the bootstrap already requires.
   Fallback: tracked copy if the in-git symlink proves troublesome on Windows.
8. **gitignore the machine-local Codex state** so nothing under `~/.codex` can be
   accidentally committed if copied into `codex/`.
9. **Codex in the dev bundle** — add `codex` to `home.packages` in
   `modules/home/me.nix`.

## Target link map (`~/.codex/`)

| `~/.codex/` target              | Source                       | Shared |
|---------------------------------|------------------------------|--------|
| `AGENTS.md`                     | `claude/AGENTS.md`           | shared |
| `memory/global.md`              | `claude/memory/global.md`    | shared |
| `memory/practices.md`           | `claude/memory/practices.md` | shared |
| `host-memory.md`                | `claude/hosts/<host>.md`     | shared |
| `skills/<name>/`                | `claude/skills/<name>/`      | shared |
| `hooks/<script>.sh`             | `claude/hooks/*.sh`          | shared |
| `hooks.json`                    | `codex/hooks.json`           | codex  |
| `agents/<name>.toml`            | `codex/agents/*.toml`        | codex  |

## New repo dir — `codex/` (deliberately thin)

- `codex/hooks.json` — Codex's standalone hooks file. Mirrors the two
  SessionStart hooks tracked in `claude/settings.json`
  (`gortex-onboard-check.sh`, `project-memory-check.sh`), rewritten as
  `bash "$HOME/.codex/hooks/<script>.sh"` for portability. (Codex runs the
  command through bash, which expands `$HOME` — same as `claude/settings.json`.)
- `codex/agents/quick-tasks.toml` — converted from `claude/agents/quick-tasks.md`
  (`.md` frontmatter → `.toml` with `name` / `description` /
  `developer_instructions = """..."""`, following the existing
  `~/.codex/agents/gortex-search.toml` shape).
- `codex/.gitignore` — defensive, mirrors `claude/.gitignore`; ignores all
  machine-local `~/.codex` artifacts (see list below). Tracked content = only
  `hooks.json` + `agents/*.toml`.
- `codex/.gitattributes` — `* text eol=lf` (same rationale as `claude/`: bash /
  toml / json consumed cross-platform; CRLF breaks shebangs).

### `codex/.gitignore` contents (to ignore)

- Secrets: `auth.json`, `.env`, `.credentials.json`
- Machine-local config/state: `config.toml`, `.codex-global-state.json*`,
  `installation_id`, `cap_sid`, `.personality_migration`, `models_cache.json`
- SQLite / sessions / logs: `*.sqlite`, `*.sqlite-shm`, `*.sqlite-wal`,
  `sqlite/`, `sessions/`, `session_index.jsonl`,
  `external_agent_session_imports.json`
- Caches / runtime dirs: `cache/`, `.tmp/`, `tmp/`, `.sandbox/`, `node_repl/`,
  `process_manager/`, `computer-use/`, `ambient-suggestions/`, `vendor_imports/`
- Plugins (marketplace-managed, abs paths): `plugins/`
- Bootstrap backups / bytecode: `*.bak`, `.bootstrap-bak/`, `__pycache__/`,
  `*.pyc`

## Wiring changes

### Instruction-file flip (`claude/` and repo root)

Make `AGENTS.md` the canonical real file; `CLAUDE.md` becomes an in-repo git
symlink to it. Two places:

- **Global:** `git mv claude/CLAUDE.md claude/AGENTS.md`, then
  `ln -s AGENTS.md claude/CLAUDE.md` (tracked symlink).
- **Root:** delete the untracked transformed `AGENTS.md` first, then
  `git mv CLAUDE.md AGENTS.md` and `ln -s AGENTS.md CLAUDE.md`.

Retarget the existing Claude instruction-file links to the real file (one hop, no
symlink chain): `~/.claude/CLAUDE.md` → `claude/AGENTS.md` in both
`modules/home/claude.nix` (line 55) and the `bootstrap.sh` Claude section
(line 146). The in-repo `claude/CLAUDE.md` symlink remains for repo
discoverability and any docs that reference the path; it resolves to the same
file regardless.

### `claude/bootstrap.sh`

- Generalize `link_entries` to take explicit src + dest bases (e.g.
  `link_entries_into <abs-src-sub> <abs-dest-sub>`); update the existing Claude
  calls to use it. The generic `link` helper is reused unchanged.
- Add a "Bootstrapping Codex config" pass:
  - `CODEX_DIR="${CODEX_CONFIG_DIR:-$HOME/.codex}"`, `CODEX_SRC="$SRC_DIR/../codex"`.
  - Whole-file: `~/.codex/AGENTS.md` → `claude/AGENTS.md` (the canonical real file);
    **skip** statusline / settings / balance.
  - Memory: `~/.codex/memory/global.md` + `practices.md` → `claude/memory/*`;
    `~/.codex/host-memory.md` → `claude/hosts/<host>.md` (reuse `host_id`).
  - Entry dirs: `skills` + `hooks` shared from `claude/`; `agents` from `codex/`.
  - Codex-specific whole-file: `hooks.json` → `codex/hooks.json`.
- One-time cleanup the pass naturally performs: replaces the mangled
  `~/.codex/AGENTS.md` (real file → backed up, then symlinked) and creates the
  missing `~/.codex/memory/` + `~/.codex/hooks/` links.

### `modules/home/codex.nix` (new)

- Sibling of `claude.nix`; same `mkOutOfStoreSymlink` + `linkEntries` pattern,
  targeting `.codex`.
- Whole-file links: `.codex/AGENTS.md` → `claude/AGENTS.md`;
  `.codex/hooks.json` → `codex/hooks.json`.
- Memory: `.codex/memory/global.md`, `.codex/memory/practices.md` →
  `claude/memory/*`; `.codex/host-memory.md` → `claude/hosts/<hostname>.md`.
- Entry dirs: `linkEntries "skills" ../../claude/skills`,
  `linkEntries "hooks" ../../claude/hooks`, `linkEntries "agents" ../../codex/agents`.
- Add `./codex.nix` to the `imports` list in `modules/home/me.nix` (next to
  `./claude.nix` at line 20).

### `modules/home/me.nix`

- Add `codex` to `home.packages` (alongside `claude-code`, line ~36).
- **Verify** the package source on Linux: `pkgs.codex` vs. an overlay / flake
  input (claude-code uses the `claude-code-nix` input). The Windows install is
  the OpenAI Codex desktop/Sky build; the nixpkgs `codex` is likely the leaner
  open-source CLI. Same config dir either way, so the sync wiring is unaffected.
  If only an older/different binary is available, surface the mismatch rather
  than silently pinning.

### Root `.gitignore`

- Add `.openclaude/` (machine-local agent dir, just removed; prevent recurrence).

## Out of scope

- Gemini home-wiring. A `.gemini/` dir exists (project `settings.json` only). If
  Gemini later wants the same treatment, factor `link` / `linkEntries` into a
  shared Nix lib + bootstrap function (rule-of-three). For two consumers,
  `codex.nix` stays a focused sibling — no premature abstraction.
- Tracking gortex's machine-local enforcement hooks or `config.toml`.

## Verification

- `bash claude/bootstrap.sh` on Windows: `~/.codex/AGENTS.md`, `memory/*`,
  `host-memory.md`, `hooks/*.sh`, `skills/*`, `hooks.json`, `agents/quick-tasks.toml`
  all resolve to the intended sources; no dangling `@import`; `linked/failed`
  summary clean.
- `just quick` (syntax) and `just check` (`nix flake check`) pass with
  `codex.nix` added.
- Codex launches, reads `AGENTS.md`, SessionStart hooks fire, skills appear.
- `git status` shows only intended tracked files under `codex/`; machine-local
  artifacts ignored.
