#!/bin/bash
# Deploy dotfiles using stow

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_SRC="$SCRIPT_DIR/dotfiles"
DOTFILES_TARGET="$HOME/.dotfiles"

# Copy dotfiles to ~/.dotfiles
mkdir -p "$DOTFILES_TARGET"
cp -r "$DOTFILES_SRC/.config" "$DOTFILES_TARGET/"

# Use stow to create symlinks
cd "$DOTFILES_TARGET" || exit 1
stow -t "$HOME" .
if [ $? -ne 0 ]; then
  echo "Error: stow failed to create symlinks." >&2
  exit 1
fi

echo "Dotfiles deployed with stow"
echo "Config symlinked from ~/.dotfiles to ~/"
