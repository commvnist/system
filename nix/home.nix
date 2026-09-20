{ pkgs, inputs, config, ... }: {
  assertions = [
    {
      assertion = config.home.username != "" && config.home.homeDirectory != "";
      message = "Set USER and HOME and evaluate with --impure (use bootstrap/home.sh).";
    }
  ];

  home.stateVersion = "26.05";
  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    fd
    fzf
    git
    ripgrep
    starship
    tmux
    zsh
    zoxide
  ];

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
    ".zshrc".source = ../zsh/.zshrc;
    ".tmux.conf".source = ../tmux/.tmux.conf;

    ".local/share/zsh/plugins/fzf-tab".source = inputs."fzf-tab";
    ".local/share/zsh/plugins/zsh-completions".source = inputs."zsh-completions";
    ".local/share/zsh/plugins/zsh-history-substring-search".source = inputs."zsh-history-substring-search";
    ".local/share/zsh/plugins/zsh-syntax-highlighting".source = inputs."zsh-syntax-highlighting";
  };

  xdg.configFile."starship.toml".source = ../starship/.config/starship.toml;
}
