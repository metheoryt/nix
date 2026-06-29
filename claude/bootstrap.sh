#!/usr/bin/env bash
# Bootstrap: symlink this repo's version-controlled Claude config (claude/) into
# the live Claude config dir so the same skills/agents/commands/statusline/
# settings are reused on every machine. Portable baseline for Windows (Git Bash),
# macOS and Linux. On NixOS/nix-darwin the same links are also declared in
# modules/home/claude.nix — either mechanism produces identical symlinks.
#
# The links point straight at the repo working tree, so editing a file in
# ~/.claude (from ANY repo you're working in) edits the tracked file here; commit
# from this repo and pull elsewhere to propagate.
#
# Idempotent. Re-run any time. Usage:
#   bash claude/bootstrap.sh
set -u

# ── Windows Git Bash: make `ln -s` create real native symlinks. Requires either
# Windows Developer Mode ON (Settings → Privacy & security → For developers) or
# running the shell as Administrator; otherwise ln -s fails under nativestrict. ─
IS_WINDOWS=0
case "$(uname -s)" in
  MINGW* | MSYS* | CYGWIN*)
    export MSYS=winsymlinks:nativestrict
    IS_WINDOWS=1
    ;;
esac

# Repo claude/ dir = the directory this script lives in (absolute).
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
# Backups go OUTSIDE the scanned skills/agents/commands dirs (a *.bak sibling
# inside skills/ would be picked up by Claude as a stray duplicate skill).
BAK_ROOT="$CLAUDE_DIR/.bootstrap-bak"

mkdir -p "$CLAUDE_DIR"

linked=0
skipped=0
backed=0
failed=0

# Move an existing real target into BAK_ROOT, mirroring its path under
# CLAUDE_DIR. If a backup already exists, the repo copy is canonical so we just
# drop the current file. Returns 0 if a fresh backup was made.
backup_target() {
  local dest="$1"
  local rel="${dest#"$CLAUDE_DIR"/}"
  local bak="$BAK_ROOT/$rel"
  if [ -e "$bak" ]; then
    rm -rf "$dest"
    return 1
  fi
  mkdir -p "$(dirname "$bak")"
  mv "$dest" "$bak"
  printf '  ~ backed up: %s -> %s\n' "$dest" "$bak"
  return 0
}

# Restore the most recent backup of dest (used when a symlink attempt fails so we
# never leave the live config missing a file).
restore_target() {
  local dest="$1"
  local rel="${dest#"$CLAUDE_DIR"/}"
  local bak="$BAK_ROOT/$rel"
  [ -e "$bak" ] || return 1
  rm -rf "$dest"
  mv "$bak" "$dest"
  printf '  ↩ restored from backup: %s\n' "$dest"
}

# link <abs-src> <abs-dest>: symlink dest -> src, backing up any real target
# first and restoring it if the symlink can't be created.
link() {
  local src="$1" dest="$2"
  if [ ! -e "$src" ]; then
    printf '  ! missing in repo, skipping: %s\n' "$src"
    return
  fi
  # Already pointing at the repo file — possibly via a chain (home-manager links
  # dest -> /nix/store/.../home-manager-files -> repo). `-ef` compares the final
  # inode, so we skip (and crucially do NOT replace) Nix-managed symlinks; a
  # direct readlink check would only match our own one-hop links and would clobber
  # the HM ones, breaking the next `nixos-rebuild switch`.
  if [ "$dest" -ef "$src" ]; then
    printf '  = already linked: %s\n' "$dest"
    skipped=$((skipped + 1))
    return
  fi
  if [ -L "$dest" ]; then
    if [ "$(readlink "$dest")" = "$src" ]; then
      printf '  = already linked: %s\n' "$dest"
      skipped=$((skipped + 1))
      return
    fi
    rm -f "$dest"  # wrong/old symlink target — replace it
  elif [ -e "$dest" ]; then
    backup_target "$dest" && backed=$((backed + 1))
  fi
  if ln -s "$src" "$dest" 2>/dev/null && [ -L "$dest" ]; then
    printf '  + linked: %s -> %s\n' "$dest" "$src"
    linked=$((linked + 1))
  else
    rm -f "$dest" 2>/dev/null  # clean up any partial entry
    restore_target "$dest"
    printf '  ✗ could not create symlink: %s\n' "$dest"
    failed=$((failed + 1))
  fi
}

# host_id: this machine's hostname, sanitized to a filename. Prefers Windows
# COMPUTERNAME (ME-G614JV), else `hostname` (g16 / latitude5520 on the nix
# laptops). Must match modules/home/claude.nix (osConfig.networking.hostName)
# and balance-refresh.py's device id.
host_id() {
  local h="${COMPUTERNAME:-$(hostname 2>/dev/null)}"
  h="${h%%.*}"                                   # strip any DNS suffix
  printf '%s' "$h" | tr -c 'A-Za-z0-9_-' '_'
}

# link_entries <subdir>: symlink each ENTRY inside claude/<subdir> into
# ~/.claude/<subdir> individually, so machine-local additions coexist.
link_entries() {
  local sub="$1"
  local src_sub="$SRC_DIR/$sub"
  [ -d "$src_sub" ] || return
  mkdir -p "$CLAUDE_DIR/$sub"
  local entry base
  for entry in "$src_sub"/* "$src_sub"/.[!.]*; do
    [ -e "$entry" ] || continue           # no matches → skip the literal glob
    base="$(basename "$entry")"
    [ "$base" = ".gitkeep" ] && continue  # placeholder, not real config
    link "$entry" "$CLAUDE_DIR/$sub/$base"
  done
}

printf 'Bootstrapping Claude config\n  repo:  %s\n  live:  %s\n\n' "$SRC_DIR" "$CLAUDE_DIR"

# Whole-file links.
for f in settings.json statusline-command.sh balance-refresh.py; do
  link "$SRC_DIR/$f" "$CLAUDE_DIR/$f"
done

# Memory & knowledge base. Global instructions + global memory store are shared
# across all machines; the per-host file is chosen by hostname (imported by
# CLAUDE.md as host-memory.md). All are git-tracked and loaded into every
# session — see README.md "Memory & knowledge base".
link "$SRC_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
mkdir -p "$CLAUDE_DIR/memory"
link "$SRC_DIR/memory/global.md" "$CLAUDE_DIR/memory/global.md"
link "$SRC_DIR/memory/practices.md" "$CLAUDE_DIR/memory/practices.md"

# Per-host memory: link claude/hosts/<host>.md -> ~/.claude/host-memory.md. Seed
# an empty stub in the repo the first time a new host runs this, so the import
# never dangles (commit it to start recording host-scoped memory there).
HOST_ID="$(host_id)"
host_src="$SRC_DIR/hosts/$HOST_ID.md"
if [ ! -e "$host_src" ]; then
  mkdir -p "$SRC_DIR/hosts"
  {
    printf '# Host: %s\n\n' "$HOST_ID"
    printf '<!--\nPer-host memory + instructions for this machine. Symlinked to\n'
    printf '~/.claude/host-memory.md and imported by claude/CLAUDE.md, so it loads ONLY\n'
    printf 'when the hostname matches. Tracked in git, synced everywhere, inert on other\n'
    printf 'hosts. Do NOT put secrets here.\n-->\n\n## Notes\n'
  } > "$host_src"
  printf '  + seeded host memory stub: %s\n' "$host_src"
fi
link "$host_src" "$CLAUDE_DIR/host-memory.md"

# Entry-by-entry links (each skill subdir / agent file / command / hook).
link_entries skills
link_entries agents
link_entries commands
link_entries hooks

# Auto-refresh: point this clone's git hooks at claude/git-hooks so future pulls
# (merge / rebase / checkout) re-link without a manual bootstrap run. core.hooksPath
# is LOCAL (per-clone) config, so this only affects this checkout. Skipped on NixOS,
# where `nixos-rebuild switch` owns the links — the hooks no-op there anyway.
install_git_hooks() {
  [ -e /etc/NIXOS ] && return 0
  command -v git >/dev/null 2>&1 || return 0
  local repo hp cur
  repo="$(git -C "$SRC_DIR" rev-parse --show-toplevel 2>/dev/null)" || return 0
  hp="$SRC_DIR/git-hooks"
  [ -d "$hp" ] || return 0
  cur="$(git -C "$repo" config --local --get core.hooksPath 2>/dev/null || true)"
  if [ "$cur" = "$hp" ]; then
    printf '  = git hooks already installed (core.hooksPath)\n'
  elif [ -n "$cur" ]; then
    # Respect a hooksPath the user set themselves — don't clobber it.
    printf '  ! core.hooksPath already set to %s — leaving it; auto-refresh not installed\n' "$cur"
  else
    git -C "$repo" config --local core.hooksPath "$hp" \
      && printf '  + git hooks installed (core.hooksPath -> %s)\n' "$hp"
  fi
}
install_git_hooks

# Prune empty backup dirs left behind by restores (keeps real backups).
[ -d "$BAK_ROOT" ] && find "$BAK_ROOT" -type d -empty -delete 2>/dev/null

printf '\nDone. linked=%d  skipped=%d  backed-up=%d  failed=%d\n' \
  "$linked" "$skipped" "$backed" "$failed"
[ -d "$BAK_ROOT" ] && printf 'Previous real files saved under %s\n' "$BAK_ROOT"

if [ "$failed" -gt 0 ]; then
  printf '\n%s\n' "⚠ Some symlinks could not be created."
  if [ "$IS_WINDOWS" -eq 1 ]; then
    cat <<'EOF'

On Windows, creating symlinks requires elevated rights. Enable ONE of:
  • Developer Mode: Settings → Privacy & security → For developers → Developer Mode = On
  • or run Git Bash "as Administrator"
Then re-run:  bash claude/bootstrap.sh
(Your live config was left intact — originals were restored from backup.)
EOF
  fi
  exit 1
fi
