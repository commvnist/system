# Keep commands from Home Manager available to interactive and noninteractive
# Zsh sessions, including shells launched by editors and desktop apps.
if [[ -d "$HOME/.nix-profile/bin" && ":$PATH:" != *":$HOME/.nix-profile/bin:"* ]]; then
  export PATH="$HOME/.nix-profile/bin:$PATH"
fi

if [[ -d "$HOME/.local/bin" && ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
  export PATH="$HOME/.local/bin:$PATH"
fi
