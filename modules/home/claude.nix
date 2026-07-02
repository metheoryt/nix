# Claude Code config, version-controlled in this repo under agents/ and symlinked
# into ~/.claude. This is the idiomatic nix path for Linux/macOS; Windows uses
# agents/bootstrap.sh (which produces the identical symlinks).
#
# mkOutOfStoreSymlink points the live config straight at the repo working tree
# (not a read-only /nix/store copy), so:
#   - editing ~/.claude/<file> from ANY repo edits the tracked file here, and
#   - changes take effect immediately, with no `nixos-rebuild` to iterate.
# Commit from this repo and pull on the other machines to propagate.
#
# The entry-dir links (hooks/skills/agents/commands) are AUTO-DISCOVERED from the
# filesystem via `linkEntries`, mirroring bootstrap.sh's `link_entries_into`. That's
# what keeps this file in sync with bootstrap.sh: adding a hook/skill/agent/
# command needs NO edit here — both mechanisms derive the same set from the repo.
# (readDir reads the flake source, i.e. git-tracked files, so commit a new entry
# for `switch` to pick it up; bootstrap reads the working tree directly.)
#
# Secrets, transcripts, caches and plugins/ are intentionally NOT linked — they
# stay machine-local in ~/.claude (see agents/.gitignore for the full list).
{
  config,
  osConfig,
  lib,
  ...
}: let
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
in {
  home.file =
    {
      # Whole-file links.
      ".claude/settings.json".source = link "${agents}/settings.json";
      ".claude/statusline-command.sh".source = link "${agents}/statusline-command.sh";
      ".claude/balance-refresh.py".source = link "${agents}/balance-refresh.py";

      # Memory & knowledge base. Global instructions + memory stores are shared
      # across machines; the per-host file is selected by this machine's hostname
      # and surfaced as host-memory.md. The stores load each session via the
      # global-memory-load.sh SessionStart hook (auto-discovered under hooks/),
      # not via CLAUDE.md @imports.
      # AGENTS.md is canonical; ~/.claude/CLAUDE.md links straight to the real file.
      ".claude/CLAUDE.md".source = link "${agents}/AGENTS.md";
      ".claude/memory/global.md".source = link "${agents}/memory/global.md";
      ".claude/memory/practices.md".source = link "${agents}/memory/practices.md";
      ".claude/host-memory.md".source = link "${agents}/hosts/${osConfig.networking.hostName}.md";
    }
    # Auto-discovered entry dirs (kept in sync with bootstrap.sh's link_entries_into).
    // linkEntries "hooks" "hooks" ../../agents/hooks
    // linkEntries "skills" "skills" ../../agents/skills
    // linkEntries "agents" "subagents" ../../agents/subagents
    // linkEntries "commands" "commands" ../../agents/commands;
}
