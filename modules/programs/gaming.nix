{
  config,
  pkgs,
  lib,
  ...
}: {
  # Steam configuration
  programs.steam = {
    enable = true;

    # Steam Remote Play
    remotePlay.openFirewall = true;

    # Steam Local Network Game Transfers
    localNetworkGameTransfers.openFirewall = true;

    # Steam Dedicated Server
    dedicatedServer.openFirewall = true;

    # Extra compatibility tools
    extraCompatPackages = with pkgs; [
      proton-ge-bin
    ];

    # Additional Steam package overrides
    package = pkgs.steam.override {
      extraPkgs = pkgs:
        with pkgs; [
          # Audio libraries
          libpulseaudio
          libvorbis
          libsndfile
          libogg

          # Graphics libraries
          libGL
          libGLU

          # Input libraries
          libevdev

          # Networking
          curl

          # System libraries
          systemd

          # Additional compatibility
          xorg.libXcursor
          xorg.libXi
          xorg.libXinerama
          xorg.libXScrnSaver
          xorg.libXrandr
          xorg.libXxf86vm
          xorg.libXcomposite
        ];
    };
  };

  # GameMode for optimized gaming performance
  programs.gamemode = {
    enable = true;
    enableRenice = true;

    settings = {
      general = {
        renice = 10;
        ioprio = 7;
        inhibit_screensaver = 1;
      };

      gpu = {
        apply_gpu_optimisations = "accept-responsibility";
        gpu_device = 0;
        amd_performance_level = "high";
        nvidia_powerlimit = 300;
      };

      cpu = {
        park_cores = "no";
        pin_policy = "none";
      };
    };
  };

  # MangoHud for performance monitoring
  programs.mangohud = {
    enable = true;

    settings = {
      # Performance metrics
      gpu_stats = true;
      cpu_stats = true;
      ram = true;
      vram = true;

      # Frame timing
      fps = true;
      frametime = true;
      frame_timing = 1;

      # Temperatures
      gpu_temp = true;
      cpu_temp = true;

      # Layout
      position = "top-left";
      width = 280;
      height = 140;

      # Visual settings
      background_alpha = 0.4;
      font_size = 16;

      # Logging
      output_folder = "/tmp";
      log_duration = 30;

      # Toggle key
      toggle_hud = "Shift_R+F12";
      toggle_logging = "Shift_L+F2";
    };
  };

  # Gaming-related system packages
  environment.systemPackages = with pkgs; [
    # Game launchers and clients
    lutris
    heroic
    bottles

    # Compatibility layers
    wine
    winetricks
    wine64
    wineWowPackages.stable

    # Game development tools
    godot_4

    # Emulation
    retroarch
    dolphin-emu
    pcsx2

    # Gaming utilities
    goverlay # MangoHud GUI
    protontricks
    steamtinkerlaunch

    # Controller support
    antimicrox
    qjoypad

    # Performance monitoring
    nvtop
    htop

    # Audio tools for gaming
    pavucontrol
    pulseeffects-legacy

    # Screen capture and streaming
    obs-studio
    obs-studio-plugins.wlrobs
    obs-studio-plugins.obs-pipewire-audio-capture

    # Communication
    discord
    mumble
    teamspeak_client

    # Game-specific tools
    minecraft

    # System optimization
    gamemode
    mangohud
  ];

  # Hardware support for gaming
  hardware = {
    # Enable 32-bit graphics support for games
    graphics.enable32Bit = true;

    # Steam hardware support
    steam-hardware.enable = true;

    # Xbox controller support
    xpadneo.enable = true;

    # PlayStation controller support
    # (handled by kernel modules)
  };

  # System optimizations for gaming
  boot = {
    # Kernel parameters for gaming performance
    kernelParams = [
      "mitigations=off" # Disable security mitigations for performance (use with caution)
      # "processor.max_cstate=1" # Reduce CPU latency (may increase power usage)
      # "intel_idle.max_cstate=0" # Disable deep sleep states for lower latency
    ];

    # Use performance-oriented kernel
    kernelPackages = lib.mkDefault pkgs.linuxPackages_zen;
  };

  # Gaming-optimized system settings
  boot.kernel.sysctl = {
    # Network optimizations for online gaming
    "net.core.netdev_max_backlog" = 5000;
    "net.core.rmem_default" = 262144;
    "net.core.rmem_max" = 16777216;
    "net.core.wmem_default" = 262144;
    "net.core.wmem_max" = 16777216;
    "net.ipv4.tcp_rmem" = "4096 65536 16777216";
    "net.ipv4.tcp_wmem" = "4096 65536 16777216";
    "net.ipv4.tcp_congestion_control" = "bbr";

    # Memory management optimizations
    "vm.swappiness" = 10;
    "vm.dirty_ratio" = 15;
    "vm.dirty_background_ratio" = 5;

    # File system optimizations
    "fs.file-max" = 2097152;
  };

  # Audio optimizations for gaming
  services.pipewire = {
    extraConfig.pipewire = {
      "10-gaming" = {
        "context.properties" = {
          "default.clock.rate" = 48000;
          "default.clock.quantum" = 512;
          "default.clock.min-quantum" = 512;
          "default.clock.max-quantum" = 8192;
        };
      };
    };
  };

  # Firewall settings for gaming
  networking.firewall = {
    allowedTCPPorts = [
      # Steam
      27036
      27037
      # Discord
      # (handled by the application)
    ];

    allowedUDPPorts = [
      # Steam
      27031
      27036
      # Game-specific ports can be added here
    ];

    allowedTCPPortRanges = [
      # Steam Remote Play
      {
        from = 27036;
        to = 27037;
      }
    ];

    allowedUDPPortRanges = [
      # Steam Voice Chat
      {
        from = 3478;
        to = 4379;
      }
      # Steam P2P
      {
        from = 27000;
        to = 27100;
      }
    ];
  };

  # User groups for gaming
  users.groups.gamemode = {};

  # Services for gaming
  services = {
    # Automatic CPU frequency scaling for gaming
    # cpupower-gui.enable = true; # GUI for CPU power management

    # Reduce input lag
    udev.extraRules = ''
      # Reduce mouse polling rate for gaming mice
      SUBSYSTEM=="usb", ATTRS{idVendor}=="046d", ATTRS{idProduct}=="c332", ATTR{power/autosuspend}="-1"

      # Set I/O scheduler for SSDs to improve game loading
      ACTION=="add|change", KERNEL=="sd[a-z]*", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"

      # Set I/O scheduler for NVMe drives
      ACTION=="add|change", KERNEL=="nvme[0-9]*n[0-9]*", ATTR{queue/scheduler}="none"
    '';
  };

  # Environment variables for gaming
  environment.variables = {
    # AMD GPU optimizations
    "RADV_PERFTEST" = "aco";

    # NVIDIA optimizations
    "__GL_SHADER_DISK_CACHE" = "1";
    "__GL_SHADER_DISK_CACHE_SKIP_CLEANUP" = "1";

    # Proton/Wine optimizations
    "PROTON_HIDE_NVIDIA_GPU" = "0";
    "PROTON_ENABLE_NVIDIA_GPU" = "1";

    # Gaming-specific environment variables
    "GAMEMODERUNEXEC" = "mangohud";
  };

  # Security considerations for gaming
  security = {
    # Allow memory overcommit for games
    pam.loginLimits = [
      {
        domain = "@gamemode";
        type = "-";
        item = "nice";
        value = "-10";
      }
      {
        domain = "@gamemode";
        type = "-";
        item = "rtprio";
        value = "20";
      }
    ];
  };
}
