# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a personal NixOS flake-based system configuration for an ASUS ROG G16 laptop (hostname: `g16`) with Intel/NVIDIA hybrid graphics. It uses Home Manager for user-level configuration.

## Common Commands

All commands are run from the repo root. Most system-modifying commands require `sudo`.

```bash
# Validate syntax quickly (no build)
just quick
# or: bash quick-check.sh

# Full flake evaluation check
just check
# or: nix flake check

# Format all Nix files
just fmt
# or: nix fmt

# Build without activating
just build

# Build and activate immediately (may fail if NVIDIA driver changes)
just switch

# Safe upgrade path for NVIDIA: update inputs + set for next boot, then reboot
just upgrade

# Temporarily test a configuration (reverts on next boot)
just test

# Enter development shell with Nix tooling
just shell

# Clean old generations (>7 days)
just clean

# Update flake inputs only
just update
```

## Architecture

### Flake structure

- **`flake.nix`** — Central entry point. Defines inputs (nixpkgs unstable + stable 25.05, home-manager, nixos-hardware, flake-utils), outputs (NixOS config, Home Manager config, devShells, packages, checks, formatter).
- **Stable overlay**: `pkgs.stable.*` is available everywhere via an overlay — use it to pin critical packages like drivers/kernel to the stable channel while the rest runs unstable.
- **`specialArgs`** passes `inputs`, `system`, and `nixpkgs-stable` into all modules.

### Host configuration (`hosts/g16/`)

- **`configuration.nix`** — Top-level system config. Imports all modules, sets hostname/locale/timezone (Asia/Almaty), configures the `me` user, enables ASUS ROG services (`asusd`, `supergfxd`), and integrates Home Manager.
- **`hardware-configuration.nix`** — Auto-generated; do not edit manually.
- **`me.nix`** — Home Manager config for user `me`: packages, git, Fish shell, Starship prompt, direnv, GNOME dconf settings.

### Module structure (`modules/`)

Each module is self-contained (options + config + services):

| Module | Responsibility |
|---|---|
| `system/base.nix` | Boot (systemd-boot), Nix daemon settings, binary caches, networking, ZRAM, garbage collection, core packages |
| `system/laptop.nix` | Power profiles daemon, thermal management (thermald), touchpad, backlight, lid behavior, S3 deep sleep |
| `desktop/gnome.nix` | GDM + GNOME (Wayland), PipeWire audio, XDG portals, fonts, excluded GNOME apps |
| `nvidia.nix` | NVIDIA open-source kernel modules, PRIME offload mode (Intel primary, NVIDIA on-demand via `nvidia-offload`), fine-grained power management, Wayland env vars, hardware video acceleration |
| `hardware/asus-rog.nix` | Battery charge threshold service (`charge-upto` command), ROG keyboard evdev fixes, DPCD backlight kernel params |
| `programs/development.nix` | Dev tools, Docker, Python 3.13, nix-ld with libraries for dynamically linked binaries |

### Key patterns

- **Module composition**: `configuration.nix` imports modules; modules don't import each other. Add new functionality by creating a module and adding it to the imports list.
- **Conditional includes**: Use `lib.optionals` for optional features within modules (see `asus-rog.nix`).
- **Override precedence**: Use `lib.mkDefault` in modules to allow host-level overrides; use `lib.mkForce` only when a value must not be overridden.
- **NVIDIA upgrade safety**: NVIDIA driver changes can cause `nixos-rebuild switch` to fail mid-session. Prefer `just upgrade` (sets next boot) over `just upgrade-now` when updating.

### Home Manager integration

Home Manager runs at system level (`nixosModules.default`), not standalone. `useGlobalPkgs = true` and `useUserPackages = true` mean user packages share the system nixpkgs — do not add `nixpkgs` as an input in home-manager configs.

## Hardware context

- CPU: Intel (microcode updates enabled, power governor managed by `power-profiles-daemon`)
- GPU: Intel integrated (primary) + NVIDIA discrete (PRIME offload, on-demand; fine-grained power management enabled — GPU powers off when idle)
- Bus IDs for PRIME: Intel `PCI:00:02:0`, NVIDIA `PCI:01:00:0` — verify with `lspci | grep -E "VGA|3D"` if GPU offload seems broken
- Battery charge limit defaults to 85% (configurable via `charge-upto <percent>`)
- Bluetooth is off at boot by default — enable manually when needed
