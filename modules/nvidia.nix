{
  config,
  lib,
  pkgs,
  ...
}: {
  # Enable graphics support
  hardware.graphics = {
    enable = true;
    enable32Bit = true; # Support for 32-bit applications

    extraPackages = with pkgs; [
      nvidia-vaapi-driver
      vaapiVdpau
      libvdpau-va-gl
    ];

    extraPackages32 = with pkgs.pkgsi686Linux; [
      nvidia-vaapi-driver
      vaapiVdpau
      libvdpau-va-gl
    ];
  };

  # Set video drivers
  services.xserver.videoDrivers = ["nvidia"];

  # NVIDIA configuration
  hardware.nvidia = {
    # Modesetting is required for Wayland
    modesetting.enable = true;

    # Power management settings
    powerManagement = {
      enable = true;
      finegrained = false; # Experimental feature, may cause issues
    };

    # Use open source kernel modules (recommended for newer GPUs)
    open = true;

    # Enable nvidia-settings GUI
    nvidiaSettings = true;

    # PRIME configuration for hybrid graphics
    prime = {
      # Enable NVIDIA Optimus support
      offload = {
        enable = true;
        enableOffloadCmd = true; # Provides nvidia-offload command
      };

      # Uncomment for always-on NVIDIA (higher power consumption)
      # sync.enable = true;

      # Find your GPU bus IDs with: lspci | grep -E "VGA|3D"
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };

    # Use stable driver by default
    package = config.boot.kernelPackages.nvidiaPackages.stable;

    # Alternative driver versions (uncomment if needed)
    # package = config.boot.kernelPackages.nvidiaPackages.beta;
    # package = config.boot.kernelPackages.nvidiaPackages.production;
  };

  # Kernel parameters for better NVIDIA support
  boot.kernelParams = [
    # Preserve video memory allocations on suspend/resume
    "nvidia.NVreg_PreserveVideoMemoryAllocations=1"

    # Set temporary file path
    "nvidia.NVreg_TemporaryFilePath=/var/tmp"

    # Enable DRM kernel mode setting
    "nvidia_drm.modeset=1"

    # Disable nouveau (open source NVIDIA driver)
    "nouveau.modeset=0"
  ];

  # Blacklist nouveau driver
  boot.blacklistedKernelModules = ["nouveau"];

  # Load NVIDIA modules early
  boot.kernelModules = [
    "nvidia"
    "nvidia_modeset"
    "nvidia_uvm"
    "nvidia_drm"
  ];

  # Extra kernel module packages
  boot.extraModulePackages = [config.boot.kernelPackages.nvidia_x11];

  # Environment variables
  environment.variables = {
    # Hardware video acceleration
    LIBVA_DRIVER_NAME = "nvidia";

    # Force GPU acceleration for VDPAU
    VDPAU_DRIVER = "nvidia";

    # CUDA support
    CUDA_CACHE_PATH = "$XDG_CACHE_HOME/nv";

    # OpenGL
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";

    # Wayland support
    GBM_BACKEND = "nvidia-drm";
    __GL_GSYNC_ALLOWED = "1";
    __GL_VRR_ALLOWED = "0";
  };

  # Session variables for Wayland compatibility
  environment.sessionVariables = {
    # Enable Wayland for Electron apps
    NIXOS_OZONE_WL = "1";

    # Firefox Wayland
    MOZ_ENABLE_WAYLAND = "1";

    # Qt Wayland
    QT_QPA_PLATFORM = "wayland;xcb";

    # SDL Wayland
    SDL_VIDEODRIVER = "wayland";

    # Clutter backend
    CLUTTER_BACKEND = "wayland";

    # XDG session
    XDG_SESSION_TYPE = "wayland";
  };

  # System packages for NVIDIA support
  environment.systemPackages = with pkgs; [
    # NVIDIA tools
    nvtop # NVIDIA GPU monitoring
    nvidia-docker # Docker with NVIDIA support

    # GPU monitoring and control
    nvitop

    # CUDA development (optional, uncomment if needed)
    # cudatoolkit
    # cudnn

    # Vulkan support
    vulkan-loader
    vulkan-validation-layers
    vulkan-tools

    # OpenCL support
    ocl-icd
    opencl-headers

    # Video encoding/decoding
    ffmpeg-full
  ];

  # Services for GPU management
  services = {
    # Xorg configuration
    xserver = {
      # Screen tearing prevention
      screenSection = ''
        Option "metamodes" "nvidia-auto-select +0+0 {ForceFullCompositionPipeline=On}"
        Option "AllowIndirectGLXProtocol" "off"
        Option "TripleBuffer" "on"
      '';
    };

    # Automatic GPU switching (for laptops)
    # supergfxd.enable = true; # Usually enabled in main config for ROG laptops
  };

  # Virtualization with GPU passthrough support
  virtualisation.docker = {
    enableNvidia = true; # Enable NVIDIA container runtime
  };

  # Security settings for NVIDIA
  security.wrappers.nvidia-smi = {
    owner = "root";
    group = "root";
    capabilities = "cap_sys_admin+ep";
    source = "${config.hardware.nvidia.package.bin}/bin/nvidia-smi";
  };

  # Systemd services for better power management
  systemd.services.nvidia-suspend = {
    description = "NVIDIA GPU suspend";
    before = ["systemd-suspend.service"];
    wantedBy = ["systemd-suspend.service"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${config.hardware.nvidia.package.bin}/bin/nvidia-sleep.sh suspend";
    };
  };

  systemd.services.nvidia-resume = {
    description = "NVIDIA GPU resume";
    after = ["systemd-suspend.service"];
    wantedBy = ["systemd-suspend.service"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${config.hardware.nvidia.package.bin}/bin/nvidia-sleep.sh resume";
    };
  };

  systemd.services.nvidia-hibernate = {
    description = "NVIDIA GPU hibernate";
    before = ["systemd-hibernate.service"];
    wantedBy = ["systemd-hibernate.service"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${config.hardware.nvidia.package.bin}/bin/nvidia-sleep.sh hibernate";
    };
  };

  # Udev rules for NVIDIA
  services.udev.extraRules = ''
    # NVIDIA device permissions
    KERNEL=="nvidia", RUN+="${pkgs.runtimeShell} -c 'mknod -m 666 /dev/nvidiactl c 195 255'"
    KERNEL=="nvidia_modeset", RUN+="${pkgs.runtimeShell} -c 'mknod -m 666 /dev/nvidia-modeset c 195 254'"
    KERNEL=="nvidia_uvm", RUN+="${pkgs.runtimeShell} -c 'mknod -m 666 /dev/nvidia-uvm c 510 0'"
  '';

  # Performance tuning
  boot.kernel.sysctl = {
    # Improve GPU memory management
    "vm.max_map_count" = 2147483642;
  };
}
