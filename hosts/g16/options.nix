{
  config,
  lib,
  pkgs,
  ...
}: {
  # Host-specific configuration options
  # This file contains all the customizable options for this specific host
  # Modify these values to match your hardware and preferences

  options.hostConfig = {
    # Hardware identification
    hostname = lib.mkOption {
      type = lib.types.str;
      default = "g16";
      description = "System hostname";
    };

    # Graphics configuration
    graphics = {
      nvidia = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable NVIDIA GPU support";
        };

        busIds = {
          intel = lib.mkOption {
            type = lib.types.str;
            default = "PCI:0:2:0";
            description = "Intel GPU bus ID (find with: lspci | grep VGA)";
          };

          nvidia = lib.mkOption {
            type = lib.types.str;
            default = "PCI:1:0:0";
            description = "NVIDIA GPU bus ID (find with: lspci | grep 3D)";
          };
        };

        driver = lib.mkOption {
          type = lib.types.enum ["stable" "beta" "production"];
          default = "stable";
          description = "NVIDIA driver version to use";
        };

        openKernel = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Use open-source NVIDIA kernel modules (recommended for RTX 20xx and newer)";
        };
      };
    };

    # System preferences
    system = {
      timeZone = lib.mkOption {
        type = lib.types.str;
        default = "Asia/Almaty";
        description = "System timezone";
      };

      locale = lib.mkOption {
        type = lib.types.str;
        default = "ru_RU.UTF-8";
        description = "System locale";
      };

      keyboardLayout = lib.mkOption {
        type = lib.types.str;
        default = "us";
        description = "Keyboard layout";
      };

      enableLaptopOptimizations = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable laptop-specific optimizations (power management, etc.)";
      };

      enableGaming = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable gaming optimizations and Steam";
      };
    };

    # Desktop environment
    desktop = {
      environment = lib.mkOption {
        type = lib.types.enum ["gnome" "kde" "xfce"];
        default = "gnome";
        description = "Desktop environment to use";
      };

      scaling = lib.mkOption {
        type = lib.types.float;
        default = 1.15;
        description = "UI scaling factor for high-DPI displays";
      };

      wayland = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Use Wayland instead of X11";
      };
    };

    # Development environment
    development = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable development tools and environments";
      };

      languages = lib.mkOption {
        type = lib.types.listOf (lib.types.enum ["python" "nodejs" "rust" "go" "java"]);
        default = ["python" "nodejs" "rust"];
        description = "Programming languages to install";
      };

      enableDocker = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Docker containerization";
      };

      editors = lib.mkOption {
        type = lib.types.listOf (lib.types.enum ["vim" "neovim" "vscode" "sublime" "pycharm"]);
        default = ["vim" "pycharm"];
        description = "Text editors and IDEs to install";
      };
    };

    # User configuration
    user = {
      name = lib.mkOption {
        type = lib.types.str;
        default = "me";
        description = "Primary user account name";
      };

      fullName = lib.mkOption {
        type = lib.types.str;
        default = "Maxim";
        description = "User's full name";
      };

      shell = lib.mkOption {
        type = lib.types.enum ["bash" "fish" "zsh"];
        default = "fish";
        description = "Default shell for the user";
      };

      extraGroups = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = ["networkmanager" "wheel" "docker"];
        description = "Additional groups for the user";
      };
    };

    # Network configuration
    network = {
      enableWifi = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable WiFi support";
      };

      enableBluetooth = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Bluetooth support";
      };

      openFirewallForGaming = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Open firewall ports for gaming (Steam, etc.)";
      };
    };

    # Security settings
    security = {
      enableFirewall = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable system firewall";
      };

      allowUnfreePackages = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Allow installation of unfree packages";
      };

      sudoTimeout = lib.mkOption {
        type = lib.types.int;
        default = 15;
        description = "Sudo timeout in minutes";
      };
    };

    # Hardware features
    hardware = {
      enableFirmware = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable all firmware (including non-free)";
      };

      enablePrinting = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable printing support";
      };

      enableSound = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable sound support with PipeWire";
      };
    };

    # Performance tuning
    performance = {
      enableZramSwap = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable ZRAM swap for better memory management";
      };

      zramPercentage = lib.mkOption {
        type = lib.types.int;
        default = 50;
        description = "Percentage of RAM to use for ZRAM swap";
      };

      cpuGovernor = lib.mkOption {
        type = lib.types.enum ["performance" "powersave" "ondemand" "conservative"];
        default = "powersave";
        description = "CPU frequency governor";
      };
    };

    # Boot configuration
    boot = {
      useSystemdBoot = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Use systemd-boot instead of GRUB";
      };

      bootEntryLimit = lib.mkOption {
        type = lib.types.int;
        default = 10;
        description = "Number of boot entries to keep";
      };

      kernelVariant = lib.mkOption {
        type = lib.types.enum ["latest" "lts" "zen" "hardened"];
        default = "latest";
        description = "Linux kernel variant to use";
      };
    };
  };
}
