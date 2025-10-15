#!/bin/bash
# Deploy dotfiles using stow

# Simple output functions
print_step() { echo -e "\n\033[0;34m==>\033[0m \033[1;37m$1\033[0m"; }
print_substep() { echo -e "  \033[0;35m->\033[0m $1"; }
print_error() { echo -e "\033[0;31m[ERROR]\033[0m $1" >&2; }
print_success() { echo -e "\033[0;32m[OK]\033[0m $1"; }
print_info() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
print_warning() { echo -e "\033[1;33m[WARNING]\033[0m $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_SRC="$SCRIPT_DIR/dotfiles"
DOTFILES_TARGET="$HOME/.dotfiles"

# Check and install stow if needed
if ! command -v stow &> /dev/null; then
    print_substep "Installing stow"
    if sudo pacman -S --needed --noconfirm stow; then
        print_success "stow installed"
    else
        print_error "Failed to install stow"
        exit 1
    fi
fi

# Copy dotfiles to ~/.dotfiles
print_substep "Copy dotfiles to ~/.dotfiles"
rm -rf "$DOTFILES_TARGET"
cp -r "$DOTFILES_SRC" "$DOTFILES_TARGET"

# Get list of packages (subdirectories in dotfiles)
cd "$DOTFILES_TARGET" || exit 1
PACKAGES=($(ls -d */ 2>/dev/null | sed 's/\///g'))

if [ ${#PACKAGES[@]} -eq 0 ]; then
    print_warning "No dotfile packages found"
    exit 0
fi

# Stow each package individually
print_substep "Stowing packages: ${PACKAGES[*]}"
for package in "${PACKAGES[@]}"; do
    if stow -t "$HOME" "$package"; then
        print_success "Stowed: $package"
    else
        print_error "Failed to stow: $package"
        exit 1
    fi
done

print_success "All dotfiles deployed: ~/.dotfiles/* -> ~/"
