{
  description = "Personal NixOS Configuration with Home Manager";

  inputs = {
    # Main nixpkgs - tracking unstable for latest packages
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Stable nixpkgs for critical packages that need stability
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.05";

    # Home Manager for user-specific configuration
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Hardware-specific configurations
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    # Flake utilities for better development experience
    flake-utils.url = "github:numtide/flake-utils";

    # NUR (Nix User Repository) for additional packages
    nur.url = "github:nix-community/NUR";

    # Nix-colors for consistent theming
    nix-colors.url = "github:misterio77/nix-colors";
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-stable,
    home-manager,
    nixos-hardware,
    flake-utils,
    nur,
    nix-colors,
    ...
  } @ inputs: let
    # System configuration
    system = "x86_64-linux";

    # Overlay for stable packages
    stableOverlay = final: prev: {
      stable = import nixpkgs-stable {
        inherit system;
        config.allowUnfree = true;
      };
    };

    # Common overlays
    overlays = [
      stableOverlay
      nur.overlay
    ];

    # Common nixpkgs configuration
    nixpkgsConfig = {
      inherit system;
      config = {
        allowUnfree = true;
        allowBroken = false;
        allowUnsupportedSystem = false;
      };
      overlays = overlays;
    };

    # Special arguments passed to all modules
    specialArgs = {
      inherit inputs;
      inherit system;
      inherit nixpkgs-stable;
    };
  in {
    # NixOS Configurations
    nixosConfigurations = {
      # Main laptop configuration
      g16 = nixpkgs.lib.nixosSystem {
        inherit system;
        inherit specialArgs;

        modules = [
          # Hardware configuration
          ./hosts/g16/configuration.nix
          ./hosts/g16/hardware-configuration.nix

          # Hardware-specific optimizations from nixos-hardware
          nixos-hardware.nixosModules.common-cpu-intel
          nixos-hardware.nixosModules.common-pc-laptop
          nixos-hardware.nixosModules.common-pc-laptop-ssd

          # Home Manager integration
          home-manager.nixosModules.default

          # System-wide nixpkgs configuration
          ({config, ...}: {
            nixpkgs = nixpkgsConfig;
          })
        ];
      };
    };

    # Home Manager Configurations (standalone)
    homeConfigurations = {
      "me@g16" = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs nixpkgsConfig;
        extraSpecialArgs =
          specialArgs
          // {
            inherit nix-colors;
          };
        modules = [
          ./hosts/g16/me.nix
          nix-colors.homeManagerModules.default
        ];
      };
    };

    # Development shells for different purposes
    devShells.${system} = {
      # Default development shell
      default = nixpkgs.legacyPackages.${system}.mkShell {
        name = "nixos-config-shell";
        packages = with nixpkgs.legacyPackages.${system}; [
          # Nix tools
          nixfmt-classic
          nil # Nix language server
          nixd # Alternative Nix language server
          alejandra # Nix formatter

          # Development tools
          git
          just # Command runner
          direnv # Environment management

          # System tools
          wget
          curl

          # Text processing
          jq
          yq
        ];

        shellHook = ''
          echo "🚀 NixOS Configuration Development Shell"
          echo "Available commands:"
          echo "  - nixos-rebuild: Build and switch configuration"
          echo "  - home-manager: Manage user configuration"
          echo "  - nix fmt: Format Nix files"
          echo "  - just: Run predefined commands (see justfile)"

          # Set up direnv if available
          if command -v direnv >/dev/null 2>&1; then
            eval "$(direnv hook bash)"
          fi
        '';
      };

      # Python development shell
      python = nixpkgs.legacyPackages.${system}.mkShell {
        name = "python-dev";
        packages = with nixpkgs.legacyPackages.${system}; [
          python312
          python312Packages.pip
          python312Packages.virtualenv
          uv # Fast Python package manager
          ruff # Fast Python linter
          black # Python formatter
        ];
      };

      # Web development shell
      web = nixpkgs.legacyPackages.${system}.mkShell {
        name = "web-dev";
        packages = with nixpkgs.legacyPackages.${system}; [
          nodejs_22
          nodePackages.npm
          nodePackages.yarn
          nodePackages.pnpm
          nodePackages.typescript
          nodePackages.eslint
          nodePackages.prettier
        ];
      };

      # Rust development shell
      rust = nixpkgs.legacyPackages.${system}.mkShell {
        name = "rust-dev";
        packages = with nixpkgs.legacyPackages.${system}; [
          rustc
          cargo
          rustfmt
          clippy
          rust-analyzer
        ];
      };
    };

    # Packages - custom packages and overrides
    packages.${system} = {
      # Custom installer script
      nixos-installer = nixpkgs.legacyPackages.${system}.writeShellScriptBin "install-nixos" ''
        #!/usr/bin/env bash
        set -euo pipefail

        echo "🔧 Installing NixOS configuration..."

        # Clone this repository if not already present
        if [ ! -d ~/nix ]; then
          git clone https://github.com/metheoryt/nix.git ~/nix
          cd ~/nix
        else
          cd ~/nix
          git pull
        fi

        # Build and switch to the configuration
        sudo nixos-rebuild switch --flake .#g16

        echo "✅ NixOS configuration installed successfully!"
        echo "💡 You may need to reboot to apply all changes."
      '';

      # Update script
      update-system = nixpkgs.legacyPackages.${system}.writeShellScriptBin "update-system" ''
        #!/usr/bin/env bash
        set -euo pipefail

        cd ~/nix

        echo "📦 Updating flake inputs..."
        nix flake update

        echo "🔧 Rebuilding system..."
        sudo nixos-rebuild switch --flake .#g16

        echo "🏠 Updating Home Manager..."
        home-manager switch --flake .#me@g16

        echo "🧹 Cleaning up old generations..."
        sudo nix-collect-garbage --delete-older-than 7d
        nix-collect-garbage --delete-older-than 7d

        echo "✅ System update complete!"
      '';
    };

    # Formatters for different file types
    formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt-classic;

    # Checks - validation and tests
    checks.${system} = {
      # Check that configurations build successfully
      nixos-config = self.nixosConfigurations.g16.config.system.build.toplevel;
      home-manager-config = self.homeConfigurations."me@g16".activationPackage;
    };

    # Templates for creating new configurations
    templates = {
      # Basic NixOS configuration template
      basic = {
        path = ./templates/basic;
        description = "Basic NixOS configuration template";
      };

      # Laptop configuration template
      laptop = {
        path = ./templates/laptop;
        description = "Laptop-optimized NixOS configuration template";
      };

      # Gaming configuration template
      gaming = {
        path = ./templates/gaming;
        description = "Gaming-optimized NixOS configuration template";
      };
    };

    # Apps - executable applications
    apps.${system} = {
      # Default app - system rebuilder
      default = {
        type = "app";
        program = "${self.packages.${system}.update-system}/bin/update-system";
      };

      # Install app
      install = {
        type = "app";
        program = "${self.packages.${system}.nixos-installer}/bin/install-nixos";
      };
    };
  };
}
