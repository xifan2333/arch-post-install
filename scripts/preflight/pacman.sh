#!/bin/bash
# Configure pacman and install base tools

print_substep "Configure pacman..."

# Update pacman databases
sudo pacman -Sy --noconfirm

# Enable multilib (for 32-bit support)
if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
    print_substep "Enable multilib..."
    sudo sed -i '/^\[multilib\]/,/^Include/ s/^#//' /etc/pacman.conf
    sudo pacman -Sy --noconfirm
fi

# Add archlinuxcn repository if not present
if ! grep -q "^\[archlinuxcn\]" /etc/pacman.conf; then
    print_substep "Add archlinuxcn repo..."
    echo "" | sudo tee -a /etc/pacman.conf
    echo "[archlinuxcn]" | sudo tee -a /etc/pacman.conf
    echo "Server = https://repo.archlinuxcn.org/\$arch" | sudo tee -a /etc/pacman.conf
    sudo pacman -Sy --noconfirm

    # Install archlinuxcn-keyring
    sudo pacman -S --needed --noconfirm archlinuxcn-keyring
fi

# Install yay if not present
if ! check_command yay; then
    print_substep "Install yay..."
    sudo pacman -S --needed --noconfirm base-devel git

    ORIGINAL_DIR="$(pwd)"
    cd /tmp
    rm -rf yay  # Clean old build if exists

    if git clone https://aur.archlinux.org/yay.git; then
        cd yay
        if makepkg -si --noconfirm; then
            print_success "yay installed"
        else
            print_error "yay installation failed"
            cd "$ORIGINAL_DIR"
            exit 1
        fi
        cd /tmp
        rm -rf yay
    else
        print_error "Failed to clone yay repo"
        cd "$ORIGINAL_DIR"
        exit 1
    fi

    cd "$ORIGINAL_DIR"
fi

print_success "Pacman configured"
