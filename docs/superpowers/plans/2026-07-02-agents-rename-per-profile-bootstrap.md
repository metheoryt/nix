# Agents Rename + Per-Profile Bootstrap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename the synced agent config `claude/` → `agents/` and make `bootstrap.sh` profile-aware so it can be run per profile (personal, work) without clobbering a secondary profile's `settings.json`.

**Architecture:** `git mv` the source-of-truth tree (`claude/`→`agents/`, inner `agents/`→`subagents/`, `codex/`→`agents/codex/`), then repoint every consumer (two Nix home-modules, `bootstrap.sh`, `justfile`, a git-hook, docs). `bootstrap.sh` classifies its target profile from `$CLAUDE_CONFIG_DIR`: the personal `~/.claude` gets shared + personal-only (`settings.json`) + Codex; any secondary profile gets the shared set only.

**Tech Stack:** Nix (home-manager, `mkOutOfStoreSymlink`), Bash, `just`, git.

## Global Constraints

- **Preserve git history** — all directory moves via `git mv`, never delete-and-recreate.
- **Never touch a secondary profile's `settings.json`** — it holds `PURE_SENTRY_TOKEN` + a distinct plugin set.
- **Tool-dictated names are fixed** — config dirs `~/.claude` / `~/.claude-work` / `~/.codex`, the `CLAUDE.md` filename Claude Code reads, and the `~/.codex/agents/` target dir Codex reads. Only *source* names change.
- **Source-vs-target decoupling** — subagent defs live in source `subagents/` but link into target `agents/` (both `~/.claude/agents/` and `~/.codex/agents/`).
- **Sharing tiers:** shared = `AGENTS.md`(→`CLAUDE.md`), `memory/`, `hosts/`(→`host-memory.md`), `hooks/`, `skills/`, `subagents/`, `commands/`, `statusline-command.sh`, `balance-refresh.py`; personal-only = `settings.json`.
- **Nix module filenames stay** `claude.nix` / `codex.nix` (they name the target, not the source).
- **Nix owns `~/.claude` + `~/.codex` only**; the work profile is bootstrap-managed.
- Validation commands: `nix-instantiate --parse <file>`, `bash -n <file>`, `nix flake check`, and `bootstrap.sh` must report `failed=0`.

---

### Task 1: Rename the tree and repoint all consumers (one atomic commit)

Intermediate states don't evaluate/run, so the rename and every reference update land in a single commit. Start from the committed structure by discarding the three interim stopgap edits from the exploration session.

**Files:**
- Discard working-tree edits: `claude/AGENTS.md`, `claude/bootstrap.sh`, `modules/home/claude.nix`
- Move: `claude/`→`agents/`, `agents/agents/`→`agents/subagents/`, `codex/`→`agents/codex/`, `agents/codex/agents/`→`agents/codex/subagents/`
- Modify: `modules/home/claude.nix`, `modules/home/codex.nix`, `agents/bootstrap.sh`, `justfile`, `agents/git-hooks/_refresh-claude-config`

**Interfaces:**
- Produces: source tree rooted at `agents/`; `bootstrap.sh` env contract — reads `$CLAUDE_CONFIG_DIR` (default `~/.claude`), links shared set into it, links `settings.json` + Codex only when the target resolves to `~/.claude`.

- [ ] **Step 1: Discard the interim stopgaps (return to committed structure)**

```bash
cd /home/me/gh/nix
git checkout -- claude/AGENTS.md claude/bootstrap.sh modules/home/claude.nix
git status --short   # expect: clean
```

- [ ] **Step 2: Rename the directory tree with git mv**

```bash
cd /home/me/gh/nix
git mv claude agents
git mv agents/agents agents/subagents
git mv codex agents/codex
git mv agents/codex/agents agents/codex/subagents
git status --short   # expect: renamed: entries only, no add/delete
```

Expected: tree is `agents/{AGENTS.md,CLAUDE.md,memory,hosts,hooks,skills,subagents,commands,settings.json,statusline-command.sh,balance-refresh.py,bootstrap.sh,git-hooks,README.md,codex/{hooks.json,subagents/}}`.

- [ ] **Step 3: Repoint `modules/home/claude.nix` — source path var + generalized `linkEntries`**

Replace the `let` binding source path and the `linkEntries` helper + calls. New content for the relevant regions:

```nix
  # Repo agents/ dir on this machine (fish helpers cd to ~/nix, which is the flake).
  agents = "${config.home.homeDirectory}/nix/agents";
  link = config.lib.file.mkOutOfStoreSymlink;

  # Link each entry inside a source subdir into ~/.claude/<targetSub>/ individually.
  # targetSub and srcSub differ only for subagents (source `subagents/`, target the
  # tool-dictated `agents/`). srcDir is the in-tree literal (enumeration only).
  linkEntries = targetSub: srcSub: srcDir:
    lib.mapAttrs'
    (name: _:
      lib.nameValuePair ".claude/${targetSub}/${name}" {
        source = link "${agents}/${srcSub}/${name}";
      })
    (lib.filterAttrs (name: _: name != ".gitkeep") (builtins.readDir srcDir));
```

And the whole-file links block + entry-dir calls become:

```nix
      ".claude/settings.json".source = link "${agents}/settings.json";
      ".claude/statusline-command.sh".source = link "${agents}/statusline-command.sh";
      ".claude/balance-refresh.py".source = link "${agents}/balance-refresh.py";

      ".claude/CLAUDE.md".source = link "${agents}/AGENTS.md";
      ".claude/memory/global.md".source = link "${agents}/memory/global.md";
      ".claude/memory/practices.md".source = link "${agents}/memory/practices.md";
      ".claude/host-memory.md".source = link "${agents}/hosts/${osConfig.networking.hostName}.md";
    }
    // linkEntries "hooks" "hooks" ../../agents/hooks
    // linkEntries "skills" "skills" ../../agents/skills
    // linkEntries "agents" "subagents" ../../agents/subagents
    // linkEntries "commands" "commands" ../../agents/commands;
```

Note: the `.claude-work/*` block from the stopgap is gone (discarded in Step 1). Update the file's top comment `claude/` → `agents/`.

- [ ] **Step 4: Repoint `modules/home/codex.nix` — source vars + generalized `linkEntries`**

```nix
  agents = "${config.home.homeDirectory}/nix/agents";
  codex = "${agents}/codex";
  link = config.lib.file.mkOutOfStoreSymlink;

  # targetSub = ~/.codex/<targetSub>/; srcBase/srcSub = source location under the repo.
  linkEntries = targetSub: srcBase: srcSub: srcDir:
    lib.mapAttrs'
    (name: _:
      lib.nameValuePair ".codex/${targetSub}/${name}" {
        source = link "${srcBase}/${srcSub}/${name}";
      })
    (lib.filterAttrs (name: _: name != ".gitkeep") (builtins.readDir srcDir));
```

Whole-file links + calls:

```nix
      ".codex/AGENTS.md".source = link "${agents}/AGENTS.md";
      ".codex/hooks.json".source = link "${codex}/hooks.json";
      ".codex/memory/global.md".source = link "${agents}/memory/global.md";
      ".codex/memory/practices.md".source = link "${agents}/memory/practices.md";
      ".codex/host-memory.md".source = link "${agents}/hosts/${osConfig.networking.hostName}.md";
    }
    // linkEntries "skills" agents "skills" ../../agents/skills
    // linkEntries "hooks" agents "hooks" ../../agents/hooks
    // linkEntries "agents" codex "subagents" ../../agents/codex/subagents;
```

Update the file's top comment `claude/`/`codex/` → `agents/`/`agents/codex/`.

- [ ] **Step 5: Rewrite `agents/bootstrap.sh` — profile classification + tiered linking**

`SRC_DIR` already self-locates (now `agents/`), so most paths follow automatically. Make these edits:

(a) Update the header comment `claude/` → `agents/` and the usage line to `bash agents/bootstrap.sh`.

(b) After the `mkdir -p "$CLAUDE_DIR"` line, add profile classification:

```bash
# Personal profile gets personal-only files (settings.json) + Codex; secondary
# profiles (e.g. ~/.claude-work via ccw) get the SHARED set only, so bootstrapping
# from ccw never clobbers the work profile's own settings.json.
_resolve() { readlink -f "$1" 2>/dev/null || printf '%s' "$1"; }
if [ "$(_resolve "$CLAUDE_DIR")" = "$(_resolve "$HOME/.claude")" ]; then
  IS_PERSONAL=1
else
  IS_PERSONAL=0
  printf 'Secondary profile — linking SHARED set only (settings.json + Codex skipped)\n\n'
fi
```

(c) Replace the whole-file links loop:

```bash
# Shared whole-file links (every profile).
for f in statusline-command.sh balance-refresh.py; do
  link "$SRC_DIR/$f" "$CLAUDE_DIR/$f"
done
# Personal-only.
if [ "$IS_PERSONAL" -eq 1 ]; then
  link "$SRC_DIR/settings.json" "$CLAUDE_DIR/settings.json"
fi
```

(d) Change the claude subagents entry-link source from `$SRC_DIR/agents` to `$SRC_DIR/subagents` (target stays `agents`):

```bash
link_entries_into "$SRC_DIR/skills"   "$CLAUDE_DIR/skills"
link_entries_into "$SRC_DIR/subagents" "$CLAUDE_DIR/agents"
link_entries_into "$SRC_DIR/commands" "$CLAUDE_DIR/commands"
link_entries_into "$SRC_DIR/hooks"    "$CLAUDE_DIR/hooks"
```

(e) Wrap the entire Codex section in the personal guard and fix its paths (`$SRC_DIR/../codex` → `$SRC_DIR/codex`; agents source `subagents/`):

```bash
# ── Codex config (~/.codex) — rides with the personal run only ───────────────
if [ "$IS_PERSONAL" -eq 1 ]; then
  CODEX_SRC="$SRC_DIR/codex"
  CODEX_DIR="${CODEX_CONFIG_DIR:-$HOME/.codex}"
  mkdir -p "$CODEX_DIR"
  printf '\nBootstrapping Codex config\n  live:  %s\n\n' "$CODEX_DIR"

  link "$SRC_DIR/AGENTS.md" "$CODEX_DIR/AGENTS.md"

  mkdir -p "$CODEX_DIR/memory"
  link "$SRC_DIR/memory/global.md"    "$CODEX_DIR/memory/global.md"
  link "$SRC_DIR/memory/practices.md" "$CODEX_DIR/memory/practices.md"
  link "$host_src"                    "$CODEX_DIR/host-memory.md"

  link "$CODEX_SRC/hooks.json" "$CODEX_DIR/hooks.json"

  link_entries_into "$SRC_DIR/skills"       "$CODEX_DIR/skills"
  link_entries_into "$SRC_DIR/hooks"        "$CODEX_DIR/hooks"
  link_entries_into "$CODEX_SRC/subagents"  "$CODEX_DIR/agents"
fi
```

- [ ] **Step 6: Update `justfile` — rename recipe, force personal, add work recipe**

Replace the `claude-bootstrap` recipe (around line 44-47) and both call sites:

```make
# Symlink the version-controlled agent config (agents/) into the personal profile.
agent-bootstrap:
    @echo "🔗 Bootstrapping agent config (personal ~/.claude + ~/.codex)..."
    @env -u CLAUDE_CONFIG_DIR bash {{flake_dir}}/agents/bootstrap.sh

# Bootstrap the work profile (~/.claude-work) — shared set only, settings untouched.
agent-bootstrap-work:
    @echo "🔗 Bootstrapping agent config (work ~/.claude-work)..."
    @CLAUDE_CONFIG_DIR="$HOME/.claude-work" bash {{flake_dir}}/agents/bootstrap.sh
```

In the `switch:` and `update:` recipes, change `@just claude-bootstrap` → `@just agent-bootstrap`.

- [ ] **Step 7: Repoint the git-hook**

In `agents/git-hooks/_refresh-claude-config`, change:

```bash
boot="$repo/agents/bootstrap.sh"
```

(was `$repo/claude/bootstrap.sh`).

- [ ] **Step 8: Validate evaluation + syntax + no stray references**

```bash
cd /home/me/gh/nix
nix-instantiate --parse modules/home/claude.nix >/dev/null && echo "OK claude.nix"
nix-instantiate --parse modules/home/codex.nix  >/dev/null && echo "OK codex.nix"
bash -n agents/bootstrap.sh && echo "OK bootstrap.sh"
bash -n agents/git-hooks/_refresh-claude-config && echo "OK git-hook"
# No stray references to the OLD source layout (tool dirs ~/.claude, new agents/codex/ are fine):
grep -rn --include="*.nix" --include="justfile" --include="*.sh" \
  -E "\.\./\.\./claude/|/nix/claude\b|\\\$repo/claude/|claude-bootstrap|SRC_DIR/\.\./codex|\.\./\.\./codex/" . \
  | grep -vE "\.git/|docs/superpowers" || echo "no stray source refs"
nix flake check 2>&1 | tail -5
```

Expected: all `OK`, `no stray source refs`, and `nix flake check` passes.

- [ ] **Step 9: Commit the atomic refactor**

```bash
cd /home/me/gh/nix
git add -A
git commit -m "refactor: claude/ -> agents/, per-profile bootstrap

Rename the synced agent config to an agent-neutral layout (agents/, inner
subagents/, agents/codex/) and make bootstrap.sh profile-aware: shared content
links into any \$CLAUDE_CONFIG_DIR profile; settings.json + Codex only into the
personal ~/.claude. Bootstrapping from a secondary profile (ccw) no longer
clobbers its settings. Rename justfile recipe claude-bootstrap -> agent-bootstrap
and add agent-bootstrap-work.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Update the prose docs to the new names and model

**Files:**
- Modify: `agents/README.md`, `agents/AGENTS.md` (persistent-memory section), `agents/hosts/ME-G614JV.md` (Windows notes), root `CLAUDE.md`/repo `README.md` if they reference the old paths.

**Interfaces:**
- Consumes: the layout + recipe names produced by Task 1.
- Produces: docs that describe `agents/`, the shared/personal-only tiers, and the per-profile bootstrap (`agent-bootstrap` / `agent-bootstrap-work`).

- [ ] **Step 1: Find every doc reference to the old names**

```bash
cd /home/me/gh/nix
# (^|[^.])claude/ excludes the legitimate tool dir ~/.claude/
grep -rn --include="*.md" -E "(^|[^.])claude/|claude-bootstrap" . | grep -vE "\.git/|docs/superpowers/(plans|specs)"
```

Expected: hits in `agents/README.md`, `agents/AGENTS.md`, `agents/hosts/ME-G614JV.md`.

- [ ] **Step 2: Rewrite `agents/AGENTS.md` persistent-memory section**

In the "Persistent memory" + "Wiring" sections: state the stores live in `agents/` and are shared into **every** profile bootstrapped (`~/.claude`, `~/.codex`, and secondary profiles like `~/.claude-work`); describe the shared vs personal-only (`settings.json`) tiers; reference `agent-bootstrap` / `agent-bootstrap-work` and `modules/home/claude.nix`. Replace all `claude/` path mentions with `agents/`.

- [ ] **Step 3: Rewrite `agents/README.md`**

Replace `claude/`→`agents/`, `~/.claude` linking table paths, the `agents/`→`subagents/` note, the folded `agents/codex/` (was top-level `codex/`), and document per-profile bootstrap + the two `just` recipes. Update the `bash ~/nix/claude/bootstrap.sh` example → `bash ~/nix/agents/bootstrap.sh`.

- [ ] **Step 4: Fix Windows note in `agents/hosts/ME-G614JV.md`**

Change `claude/bootstrap.sh` → `agents/bootstrap.sh` in both the run example and the warning line.

- [ ] **Step 5: Verify no old references remain in docs**

```bash
cd /home/me/gh/nix
grep -rn --include="*.md" -E "(^|[^.])claude/|claude-bootstrap" . | grep -vE "\.git/|docs/superpowers/(plans|specs)" || echo "docs clean"
```

Expected: `docs clean`.

- [ ] **Step 6: Commit**

```bash
cd /home/me/gh/nix
git add -A
git commit -m "docs: describe agents/ layout + per-profile bootstrap

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Activate and verify on this machine

Runtime verification only — no repo commit. Confirms the rename produced working links for all three profiles and that the work profile's secret/plugins survived.

**Files:** none (activation + inspection).

**Interfaces:**
- Consumes: Task 1 output (renamed tree, new `bootstrap.sh`, `just` recipes).

- [ ] **Step 1: Capture the work profile's current settings fingerprint (baseline)**

```bash
jq '{secret:(.env.PURE_SENTRY_TOKEN!=null), hooks:(.hooks.SessionStart[0].hooks|length), plugins:(.enabledPlugins|keys)}' ~/.claude-work/settings.json
```

Expected: `secret:true`, `hooks:2`, the 5 work plugins. Note these values.

- [ ] **Step 2: Bootstrap the work profile (shared-only) and confirm settings untouched**

```bash
cd /home/me/gh/nix
just agent-bootstrap-work
echo "--- exit: bootstrap must report failed=0 above ---"
# settings.json must be a REAL file, unchanged:
file ~/.claude-work/settings.json
jq '{secret:(.env.PURE_SENTRY_TOKEN!=null), hooks:(.hooks.SessionStart[0].hooks|length), plugins:(.enabledPlugins|keys)}' ~/.claude-work/settings.json
# shared links present, pointing at agents/:
find ~/.claude-work -maxdepth 2 -type l -printf '%p -> %l\n' | grep -E "agents/" | sort
```

Expected: `failed=0`; `settings.json` is `JSON text data` (not a symlink) with identical fingerprint to Step 1; `memory/`, `hosts→host-memory.md`, `hooks/`, `skills/`, `agents/`(subagents), `commands`, `statusline`, `balance-refresh.py`, `CLAUDE.md` all symlinked into `.../nix/agents/...`; **no** `settings.json` symlink.

- [ ] **Step 3: Re-register the memory hook path if needed**

The work `settings.json` SessionStart already runs `bash "$HOME/.claude-work/hooks/global-memory-load.sh"`; the linked hook path is unchanged by the rename. Confirm it still fires:

```bash
bash "$HOME/.claude-work/hooks/global-memory-load.sh" | head -3
bash "$HOME/.claude-work/hooks/global-memory-load.sh" | wc -c   # expect > 0
```

Expected: emits the global-memory header + non-zero byte count.

- [ ] **Step 4: Bootstrap the personal profile (or `just switch` on NixOS) and verify**

On NixOS the personal `~/.claude` + `~/.codex` are owned by home-manager; run a full switch to re-link them declaratively, or run the bootstrap directly for a quick check:

```bash
cd /home/me/gh/nix
just agent-bootstrap        # personal + codex; must report failed=0
# spot-check personal links now point at agents/:
readlink ~/.claude/CLAUDE.md ~/.claude/host-memory.md ~/.codex/AGENTS.md
ls -la ~/.claude/agents/ | head   # subagent defs linked into the tool's agents/ dir
```

Expected: `failed=0`; targets resolve under `.../nix/agents/...`; `~/.claude/agents/` contains the subagent entries.

- [ ] **Step 5: Full flake check**

```bash
cd /home/me/gh/nix
just switch   # applies claude.nix/codex.nix declaratively; runs agent-bootstrap after
```

Expected: switch succeeds; post-switch `agent-bootstrap` reports `failed=0`.

---

## Notes for the implementer

- **Do not** run `just agent-bootstrap` (personal) from a `ccw` shell before Task 1 lands — pre-rename `bootstrap.sh` still clobbers whatever `$CLAUDE_CONFIG_DIR` points at. After Task 1, the personal recipe force-unsets `CLAUDE_CONFIG_DIR`, so it is safe from any shell.
- The `~/.claude-work/settings.json` hook registration (SessionStart → `global-memory-load.sh`) was already added during design; it is a real file and survives all bootstraps. If a fresh secondary profile is ever created, that one-line registration is the only manual step.
- `link_entries_into` and (post-edit) `linkEntries` already accept distinct source/target subdir names — the `subagents/`→`agents/` mapping needs no further helper changes beyond passing the right arguments.
