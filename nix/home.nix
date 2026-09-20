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
    fzf
    git
    ripgrep
    starship
    tmux
    vim
    zsh
  ];

  # Home Manager is the sole owner of these dotfiles and pinned plugins.
  home.file = {
    ".zshrc".source = ../zsh/.zshrc;
    ".tmux.conf".source = ../tmux/.tmux.conf;
    ".vimrc".source = ../vim/.vimrc;

    ".local/share/zsh/plugins/fzf-tab".source = inputs."fzf-tab";
    ".local/share/zsh/plugins/zsh-autosuggestions".source = inputs."zsh-autosuggestions";
    ".local/share/zsh/plugins/zsh-autopair".source = inputs."zsh-autopair";
    ".local/share/zsh/plugins/zsh-history-substring-search".source = inputs."zsh-history-substring-search";
    ".local/share/zsh/plugins/zsh-syntax-highlighting".source = inputs."zsh-syntax-highlighting";
  };

  xdg.configFile."starship.toml".source = ../starship/.config/starship.toml;
}
