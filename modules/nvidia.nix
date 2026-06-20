{
  config,
  pkgs,
  ...
}: {
  # Enable graphics support
  hardware.graphics = {
    enable = true;
    enable32Bit = true; # Support for 32-bit applications

    extraPackages = with pkgs; [
      nvidia-vaapi-driver
      libva-vdpau-driver
      libvdpau-va-gl
    ];

    extraPackages32 = with pkgs.pkgsi686Linux; [
      nvidia-vaapi-driver
      libva-vdpau-driver
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
      # Fine-grained power management: powers off GPU when not in use (good for RTX 40-series)
      # Revert to false if you experience suspend/resume issues
      finegrained = true;
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
      intelBusId = "PCI:00:02:0";
      nvidiaBusId = "PCI:01:00:0";
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

    # Enable runtime D3 power state — GPU powers down when idle (pairs with finegrained=true)
    "nvidia.NVreg_DynamicPowerManagement=0x02"

    # PCIe Active State Power Management — reduces power on idle PCIe links
    "pcie_aspm.policy=powersave"
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

  # System packages for NVIDIA support
  environment.systemPackages = with pkgs; [
    # NVIDIA tools
    # nvtop # NVIDIA GPU monitoring (package may not be available)
    # nvidia-docker # Docker with NVIDIA support (deprecated)

    # GPU monitoring and control
    # nvitop # Package may not be available

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

  # Xorg configuration for NVIDIA
  services.xserver.screenSection = ''
    Option "metamodes" "nvidia-auto-select +0+0 {ForceFullCompositionPipeline=On}"
    Option "AllowIndirectGLXProtocol" "off"
    Option "TripleBuffer" "on"
  '';

  # Virtualization with GPU passthrough support
  hardware.nvidia-container-toolkit.enable = true;

  # Security settings for NVIDIA (nvidia-smi is available system-wide by default)

  # Systemd services for better power management are handled by base NixOS NVIDIA module
  # when hardware.nvidia.powerManagement.enable = true; is set

  # Performance tuning
  boot.kernel.sysctl = {
    # Improve GPU memory management
    "vm.max_map_count" = 2147483642;
  };
}
