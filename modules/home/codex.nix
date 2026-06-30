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
