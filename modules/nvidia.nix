{ config, lib, pkgs, ... }:

{
  hardware.graphics.enable = true;
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;   # better idle/suspend
    open = true;                     # open kernel module works well on Ada/Lovelace
    nvidiaSettings = true;
    prime = {
      offload.enable = true;
      # Adjust with: lspci | grep -E "VGA|3D"
      intelBusId = "PCI:00:02:0";
      nvidiaBusId = "PCI:01:00:0";
    };
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # Smoother suspend/resume; safe on recent drivers
  boot.kernelParams = [
    "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
    "nvidia.NVreg_TemporaryFilePath=/var/tmp"
  ];
  # Hardware video decode path on NVIDIA, and Wayland/Electron goodness
  environment.variables.LIBVA_DRIVER_NAME = "nvidia";
  environment.sessionVariables.NIXOS_OZONE_WL = "1";  # Electron/Chromium use Wayland
  hardware.graphics.extraPackages = with pkgs; [ nvidia-vaapi-driver ];
}
