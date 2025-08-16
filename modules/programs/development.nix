{
  config,
  pkgs,
  lib,
  ...
}: {
  # Development tools and environments
  environment.systemPackages = with pkgs; [
    # Version control
    git
    git-lfs
    gh # GitHub CLI

    # Text editors and IDEs
    vim
    neovim

    # Development utilities
    curl
    wget
    jq
    yq

    # Build tools
    gnumake
    cmake
    pkg-config

    # Debugging and profiling
    gdb
    valgrind
    strace
    ltrace

    # Network tools
    netcat
    nmap
    tcpdump
    wireshark

    # Container tools
    docker-compose

    # Language servers and formatters
    nixd
    alejandra

    # Database tools
    sqlite
    postgresql

    # File utilities
    fd
    ripgrep
    bat
    eza
    fzf

    # System monitoring
    htop
    btop
    iotop

    # Archive tools
    unzip
    zip
    p7zip
    tar

    # Development libraries
    openssl
    zlib
    libxml2
    libxslt
  ];

  # Python development environment
  environment.systemPackages = with pkgs; [
    python312
    python312Packages.pip
    python312Packages.virtualenv
    uv # Fast Python package manager
  ];

  # Node.js development
  environment.systemPackages = with pkgs; [
    nodejs_22
    nodePackages.npm
    nodePackages.yarn
    nodePackages.pnpm
  ];

  # Rust development
  environment.systemPackages = with pkgs; [
    rustc
    cargo
    rustfmt
    clippy
    rust-analyzer
  ];

  # Go development
  environment.systemPackages = with pkgs; [
    go
    gopls
    delve # Go debugger
  ];

  # Java development
  environment.systemPackages = with pkgs; [
    openjdk17
    maven
    gradle
  ];

  # Docker support
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };

  # Podman as Docker alternative
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    defaultNetwork.settings.dns_enabled = true;
  };

  # Enable AppImage support
  programs.appimage = {
    enable = true;
    binfmt = true;
  };

  # Direnv for project-specific environments
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # Shell improvements
  programs.fish.enable = true;
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;
  };

  # Git configuration
  programs.git = {
    enable = true;
    config = {
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
      core.autocrlf = "input";
      merge.conflictstyle = "diff3";
    };
  };

  # Development fonts
  fonts.packages = with pkgs; [
    (nerdfonts.override {fonts = ["FiraCode" "JetBrainsMono" "Hack"];})
    fira-code
    fira-code-symbols
  ];

  # Environment variables for development
  environment.variables = {
    EDITOR = "vim";
    PAGER = "less";
    BROWSER = "firefox";
    TERMINAL = "gnome-terminal";
  };

  # User groups for development
  users.groups.docker = {};

  # Development services
  services = {
    # PostgreSQL for development
    postgresql = {
      enable = false; # Enable per project needs
      package = pkgs.postgresql_15;
      enableTCPIP = true;
    };

    # Redis for development
    redis.servers.development = {
      enable = false; # Enable per project needs
      port = 6379;
    };
  };
}
