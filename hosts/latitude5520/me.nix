{pkgs, ...}: {
  home.username = "me";
  home.homeDirectory = "/home/me";
  home.stateVersion = "25.05";

  # Core packages
  home.packages = with pkgs; [
    # Browsers
    firefox
    google-chrome

    # Communication
    telegram-desktop

    # Development tools
    jetbrains.pycharm
    zed-editor
    claude-code

    # System utilities
    fastfetch

    # Office suite
    libreoffice-qt6-fresh

    # Remote access
    rustdesk

    # Additional utilities
    dconf-editor
    gnome-tweaks
    gnome-extension-manager

    # Media tools
    vlc
    gimp

    # Archive tools
    file-roller

    # Development fonts
    cascadia-code
    source-code-pro

    # Terminal
    ghostty
  ];

  # Git configuration
  programs.git = {
    enable = true;

    settings = {
      user = {
        name = "Maxim Romanyuk";
        email = "metheoryt@gmail.com";
        signingkey = ""; # Add your GPG key if you use one
      };

      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
      core.autocrlf = "input";
      merge.conflictstyle = "diff3";
      diff.tool = "vimdiff";

      alias = {
        st = "status";
        co = "checkout";
        br = "branch";
        up = "pull --rebase";
        ci = "commit";
        unstage = "reset HEAD --";
        last = "log -1 HEAD";
        visual = "!gitk";
        graph = "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit";
      };
    };
  };

  # Firefox configuration (minimal to avoid conflicts)
  programs.firefox.enable = true;

  # Fish shell configuration
  programs.fish = {
    enable = true;

    shellAliases = {
      ll = "ls -alF";
      la = "ls -A";
      l = "ls -CF";
      ".." = "cd ..";
      "..." = "cd ../..";
      grep = "grep --color=auto";
      fgrep = "fgrep --color=auto";
      egrep = "egrep --color=auto";

      # Git shortcuts
      gs = "git status";
      gd = "git diff";
      ga = "git add";
      gc = "git commit";
      gp = "git push";
      gl = "git pull";

      # NixOS specific
      nrs = "sudo nixos-rebuild switch --flake .#latitude5520";
      nrt = "sudo nixos-rebuild test --flake .#latitude5520";
      nrb = "sudo nixos-rebuild boot --flake .#latitude5520";

      # Claude Code (installed via npm)
      cc = "claude";

      # System utilities
      df = "df -h";
      du = "du -h";
      free = "free -h";
      ps = "ps aux";
      top = "htop";
    };

    functions = {
      # Function to rebuild NixOS from anywhere
      rebuild = {
        description = "Rebuild NixOS configuration";
        body = ''
          set current_dir (pwd)
          cd ~/nix
          sudo nixos-rebuild switch --flake .#latitude5520
          cd $current_dir
        '';
      };

      # Function to update flake
      update = {
        description = "Update NixOS flake";
        body = ''
          set current_dir (pwd)
          cd ~/nix
          nix flake update
          cd $current_dir
        '';
      };

      # Function to cleanup system
      cleanup = {
        description = "Cleanup NixOS system";
        body = ''
          sudo nix-collect-garbage -d
          sudo nixos-rebuild switch --flake ~/nix#latitude5520
        '';
      };
    };

    interactiveShellInit = ''
      # Set greeting
      set fish_greeting "Welcome to NixOS on Latitude 5520!"

      # Set editor
      set -x EDITOR nvim

      # Add local bin to path
      fish_add_path ~/.local/bin

      # Set up direnv if available
      if command -v direnv >/dev/null
          direnv hook fish | source
      end
    '';
  };

  # Bash configuration (fallback)
  programs.bash = {
    enable = true;
    enableCompletion = true;

    bashrcExtra = ''
      # Custom prompt
      PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

      # History settings
      HISTCONTROL=ignoreboth
      HISTSIZE=1000
      HISTFILESIZE=2000

      # Colored ls
      alias ls='ls --color=auto'
      alias grep='grep --color=auto'

      # Claude Code alias
      alias cc='claude'
    '';
  };

  # Starship prompt (works with both fish and bash)
  programs.starship = {
    enable = true;

    settings = {
      format = "$all$character";

      character = {
        success_symbol = "[➜](bold green)";
        error_symbol = "[➜](bold red)";
      };

      git_branch = {
        symbol = "🌱 ";
        truncation_length = 20;
      };

      git_status = {
        conflicted = "🏳";
        ahead = "🏎💨";
        behind = "😰";
        diverged = "😵";
        up_to_date = "✓";
        untracked = "🤷";
        stashed = "📦";
        modified = "📝";
        staged = "[++\($count\)](green)";
        renamed = "👅";
        deleted = "🗑";
      };

      nix_shell = {
        disabled = false;
        impure_msg = "[impure shell](bold red)";
        pure_msg = "[pure shell](bold green)";
        format = "via [☃️ $state( \($name\))](bold blue) ";
      };
    };
  };

  # Direnv integration
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # Ghostty terminal
  programs.ghostty = {
    enable = true;
    settings = {
      font-family = "JetBrainsMono Nerd Font";
      font-size = 10;
      shell-integration = "fish";
      theme = "dark:Dracula,light:GitHub Light";
      window-decoration = false;
      quit-after-last-window-closed = true;
    };
  };

  # Home Manager's dconf settings for GNOME
  dconf = {
    enable = true;
    settings = {
      # UI scaling and theme settings
      "org/gnome/desktop/interface" = {
        text-scaling-factor = 1;
        gtk-theme = "Adwaita";
        icon-theme = "Adwaita";
        cursor-theme = "Adwaita";
        font-name = "Noto Sans 11";
        document-font-name = "Noto Sans 11";
        monospace-font-name = "JetBrainsMono Nerd Font 10";
        show-battery-percentage = true;
        clock-show-weekday = true;
        clock-show-seconds = false;
      };

      # Window manager preferences
      "org/gnome/desktop/wm/preferences" = {
        button-layout = "appmenu:minimize,maximize,close";
        titlebar-font = "Noto Sans Bold 11";
        resize-with-right-button = true;
      };

      # Keyboard shortcuts
      "org/gnome/desktop/wm/keybindings" = {
        close = ["<Alt>F4"];
        toggle-fullscreen = ["F11"];
        switch-to-workspace-left = ["<Control><Alt>Left"];
        switch-to-workspace-right = ["<Control><Alt>Right"];
        move-to-workspace-left = ["<Control><Alt><Shift>Left"];
        move-to-workspace-right = ["<Control><Alt><Shift>Right"];
      };

      # Custom keybindings
      "org/gnome/settings-daemon/plugins/media-keys" = {
        custom-keybindings = [
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
        ];
      };

      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
        binding = "<Control><Alt>t";
        command = "ghostty";
        name = "Terminal";
      };

      # Privacy settings
      "org/gnome/desktop/privacy" = {
        disable-microphone = false;
        disable-camera = false;
        report-technical-problems = false;
      };

      # Power settings
      "org/gnome/settings-daemon/plugins/power" = {
        sleep-inactive-ac-type = "nothing";
        sleep-inactive-battery-type = "suspend";
        sleep-inactive-battery-timeout = 1800; # 30 minutes
      };

      # Nautilus (file manager) settings
      "org/gnome/nautilus/preferences" = {
        default-folder-viewer = "list-view";
        search-filter-time-type = "last_modified";
        show-hidden-files = false;
      };

    };
  };

  # XDG user directories (minimal to avoid conflicts)
  xdg.enable = true;

  # Enable Home Manager
  programs.home-manager.enable = true;
}
