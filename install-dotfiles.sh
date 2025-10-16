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

# Check required tools
for tool in stow rsync; do
    if ! command -v "$tool" &> /dev/null; then
        print_error "$tool is not installed"
        print_info "Please run install-user.sh first to install all required packages"
        exit 1
    fi
done

# Sync dotfiles to ~/.dotfiles
print_substep "Sync dotfiles to ~/.dotfiles"
rsync -a --delete "$DOTFILES_SRC/" "$DOTFILES_TARGET/"

# Get list of packages (subdirectories in dotfiles)
cd "$DOTFILES_TARGET" || exit 1
PACKAGES=($(ls -d */ 2>/dev/null | sed 's/\///g'))

if [ ${#PACKAGES[@]} -eq 0 ]; then
    print_warning "No dotfile packages found"
    exit 0
fi

# Stow each package individually
# First unstow to remove old symlinks, then stow to create new ones
print_substep "Stowing packages: ${PACKAGES[*]}"
for package in "${PACKAGES[@]}"; do
    # Unstow first (ignore errors if not previously stowed)
    stow -D -t "$HOME" "$package" 2>/dev/null || true

    # Remove any regular files that conflict with stow
    # This handles the case where Edit tool converts symlinks to regular files
    if ! stow -n -t "$HOME" "$package" 2>&1 | grep -q "would cause conflicts"; then
        # No conflicts, proceed
        :
    else
        # Find and remove conflicting regular files
        stow -n -t "$HOME" "$package" 2>&1 | grep "existing target" | sed 's/.*existing target //' | sed 's/ since.*//' | while read -r conflict; do
            target="$HOME/$conflict"
            if [ -f "$target" ] && [ ! -L "$target" ]; then
                print_warning "Removing conflicting file: $target"
                rm -f "$target"
            fi
        done
    fi

    # Now stow the package
    if stow -t "$HOME" "$package"; then
        print_success "Stowed: $package"
    else
        print_error "Failed to stow: $package"
        exit 1
    fi
done

print_success "All dotfiles deployed: ~/.dotfiles/* -> ~/"
