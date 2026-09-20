{
  description = "Portable Neovim and Vim-style shell setup";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    fzf-tab = {
      url = "github:Aloxaf/fzf-tab";
      flake = false;
    };
    zsh-completions = {
      url = "github:zsh-users/zsh-completions";
      flake = false;
    };
    zsh-syntax-highlighting = {
      url = "github:zsh-users/zsh-syntax-highlighting";
      flake = false;
    };
  };

  outputs = inputs@{ nixpkgs, home-manager, ... }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      mkHome = system: username: homeDirectory:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};
          extraSpecialArgs = { inherit inputs; };
          modules = [
            ./nix/home.nix
            { home = { inherit username homeDirectory; }; }
          ];
        };
    in {
      # Only this entry point reads host identity. The checks below use fixed
      # identities so their builds remain pure and reproducible in CI.
      homeConfigurations = nixpkgs.lib.genAttrs systems (system:
        mkHome system (builtins.getEnv "USER") (builtins.getEnv "HOME"));

      packages = nixpkgs.lib.genAttrs systems (system: {
        home-manager = inputs.home-manager.packages.${system}.home-manager;
      });

      checks = nixpkgs.lib.genAttrs systems (system: {
        activation = (mkHome system "ci" (if nixpkgs.lib.hasSuffix "darwin" system
          then "/Users/ci" else "/home/ci")).activationPackage;
      });
    };
}
