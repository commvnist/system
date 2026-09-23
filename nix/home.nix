{ pkgs, inputs, config, ... }:
let
  # Nixpkgs 26.05 still ships an older mise. Pin the official release for
  # each supported host so project tasks use the same version everywhere.
  miseVersion = "2026.9.12";
  miseReleases = {
    x86_64-linux = { asset = "linux-x64-musl"; hash = "sha256-5Zo4aDydd24OpsezXJgp3pFbt98V0W0L9okK+gJ4vXw="; };
    aarch64-linux = { asset = "linux-arm64-musl"; hash = "sha256-LSmCsS96E4lKqIJy5M02DmhZH+EFtDz/KbGsRYjG/oM="; };
    x86_64-darwin = { asset = "macos-x64"; hash = "sha256-+h41RW8eJ6RVWhzOyC1TZ9cDfztPRtSLg8SjvOtNePI="; };
    aarch64-darwin = { asset = "macos-arm64"; hash = "sha256-8g18xVWlsO57ilBKy8JYO+GwhI1kEVz76EEZzrcFAls="; };
  };
  release = miseReleases.${pkgs.stdenv.hostPlatform.system};
  misePackage = pkgs.stdenvNoCC.mkDerivation {
    pname = "mise";
    version = miseVersion;
    src = pkgs.fetchurl {
      url = "https://github.com/jdx/mise/releases/download/v${miseVersion}/mise-v${miseVersion}-${release.asset}";
      inherit (release) hash;
    };
    dontUnpack = true;
    dontStrip = true;
    installPhase = ''
      mkdir -p "$out/bin"
      cp "$src" "$out/bin/mise"
      chmod 755 "$out/bin/mise"
    '';
  };
in {
  assertions = [
    {
      assertion = config.home.username != "" && config.home.homeDirectory != "";
      message = "Set USER and HOME and evaluate with --impure (use bootstrap/home.sh).";
    }
  ];

  home.stateVersion = "26.05";
  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    actionlint
    bat
    bottom
    delta
    difftastic
    dust
    eza
    fd
    fzf
    gh
    git
    gum
    hyperfine
    jq
    lazygit
    python3
    ripgrep
    sesh
    shellcheck
    shfmt
    starship
    tealdeer
    tmux
    watchexec
    yq-go
    zsh
    zoxide
  ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
    wl-clipboard
    xclip
  ];

  programs.atuin = {
    enable = true;
    enableZshIntegration = false; # Keep the Vim keymap in the linked .zshrc.
    settings = {
      auto_sync = false;
      update_check = false;
    };
  };

  programs.direnv = {
    enable = true;
    enableZshIntegration = false; # The linked .zshrc loads this after the prompt.
    nix-direnv.enable = true;
  };

  programs.mise = {
    enable = true;
    package = misePackage;
    enableZshIntegration = false; # mise run works without shell activation.
  };

  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    defaultEditor = true;
    initLua = builtins.readFile ../nvim/init.lua;
    plugins = with pkgs.vimPlugins; [
      fzf-lua
      gitsigns-nvim
      mini-nvim
      nvim-lspconfig
      (nvim-treesitter.withPlugins (parsers: with parsers; [
        bash
        json
        lua
        markdown
        markdown_inline
        nix
        python
        toml
        vim
        vimdoc
        yaml
      ]))
    ];
    extraPackages = with pkgs; [
      bash-language-server
      lua-language-server
      nixd
      pyright
    ];
  };

  # Home Manager is the sole owner of these dotfiles and pinned plugins.
  home.file = {
    ".zshenv".source = ../zsh/.zshenv;
    ".zshrc".source = ../zsh/.zshrc;
    ".tmux.conf".source = ../tmux/.tmux.conf;
    ".local/bin/clipboard-copy" = {
      source = ../clipboard/clipboard-copy;
      executable = true;
    };

    ".local/share/zsh/plugins/fzf-tab".source = inputs."fzf-tab";
    ".local/share/zsh/plugins/zsh-completions".source = inputs."zsh-completions";
    ".local/share/zsh/plugins/zsh-syntax-highlighting".source = inputs."zsh-syntax-highlighting";
  };

  xdg.configFile."starship.toml".source = ../starship/.config/starship.toml;
  xdg.configFile."nix/nix.conf".text = ''
    extra-experimental-features = nix-command flakes
  '';
}
