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
    stow
    tmux
    vim
    zsh
  ];

  # These same files can be used with GNU Stow when Nix is unavailable.
  home.file = {
    ".zshrc".source = ../zsh/.zshrc;
    ".tmux.conf".source = ../tmux/.tmux.conf;
    ".vimrc".source = ../vim/.vimrc;
    ".config/starship.toml".source = ../starship/.config/starship.toml;
    ".local/bin/zsh-plugin-sync".source = ../zsh/.local/bin/zsh-plugin-sync;

    ".local/share/zsh/plugins/fzf-tab".source = inputs."fzf-tab";
    ".local/share/zsh/plugins/zsh-autosuggestions".source = inputs."zsh-autosuggestions";
    ".local/share/zsh/plugins/zsh-autopair".source = inputs."zsh-autopair";
    ".local/share/zsh/plugins/zsh-history-substring-search".source = inputs."zsh-history-substring-search";
    ".local/share/zsh/plugins/zsh-syntax-highlighting".source = inputs."zsh-syntax-highlighting";
  };
}
