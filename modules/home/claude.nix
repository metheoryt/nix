# Claude Code config, version-controlled in this repo under claude/ and symlinked
# into ~/.claude. This is the idiomatic nix path for Linux/macOS; Windows uses
# claude/bootstrap.sh (which produces the identical symlinks).
#
# mkOutOfStoreSymlink points the live config straight at the repo working tree
# (not a read-only /nix/store copy), so:
#   - editing ~/.claude/<file> from ANY repo edits the tracked file here, and
#   - changes take effect immediately, with no `nixos-rebuild` to iterate.
# Commit from this repo and pull on the other machines to propagate.
#
# The entry-dir links (hooks/skills/agents/commands) are AUTO-DISCOVERED from the
# filesystem via `linkEntries`, mirroring bootstrap.sh's `link_entries`. That's
# what keeps this file in sync with bootstrap.sh: adding a hook/skill/agent/
# command needs NO edit here — both mechanisms derive the same set from the repo.
# (readDir reads the flake source, i.e. git-tracked files, so commit a new entry
# for `switch` to pick it up; bootstrap reads the working tree directly.)
#
# Secrets, transcripts, caches and plugins/ are intentionally NOT linked — they
# stay machine-local in ~/.claude (see claude/.gitignore for the full list).
{
  config,
  osConfig,
  lib,
  ...
}: let
  # Repo checkout location on this machine. The fish helpers cd to ~/nix, so the
  # flake lives there. Change this if you clone the repo elsewhere.
  claude = "${config.home.homeDirectory}/nix/claude";
  link = config.lib.file.mkOutOfStoreSymlink;

  # Symlink each entry inside claude/<sub> into ~/.claude/<sub>, individually
  # (not the whole dir) so machine-local skills/agents added directly in
  # ~/.claude keep working alongside the tracked ones. `srcDir` is the in-tree
  # path literal (used only to enumerate names — pure-eval safe); the symlink
  # target stays the out-of-store `claude` string so edits are live.
  linkEntries = sub: srcDir:
    lib.mapAttrs'
    (name: _:
      lib.nameValuePair ".claude/${sub}/${name}" {
        source = link "${claude}/${sub}/${name}";
      })
    (lib.filterAttrs (name: _: name != ".gitkeep") (builtins.readDir srcDir));
in {
  home.file =
    {
      # Whole-file links.
      ".claude/settings.json".source = link "${claude}/settings.json";
      ".claude/statusline-command.sh".source = link "${claude}/statusline-command.sh";
      ".claude/balance-refresh.py".source = link "${claude}/balance-refresh.py";

      # Memory & knowledge base (always-loaded CLAUDE.md hierarchy). Global
      # instructions + global memory store are shared across machines; the
      # per-host file is selected by this machine's hostname and surfaced as
      # host-memory.md, which claude/CLAUDE.md @imports.
      ".claude/CLAUDE.md".source = link "${claude}/CLAUDE.md";
      ".claude/memory/global.md".source = link "${claude}/memory/global.md";
      ".claude/memory/practices.md".source = link "${claude}/memory/practices.md";
      ".claude/host-memory.md".source = link "${claude}/hosts/${osConfig.networking.hostName}.md";
    }
    # Auto-discovered entry dirs (kept in sync with bootstrap.sh's link_entries).
    // linkEntries "hooks" ../../claude/hooks
    // linkEntries "skills" ../../claude/skills
    // linkEntries "agents" ../../claude/agents
    // linkEntries "commands" ../../claude/commands;
}
