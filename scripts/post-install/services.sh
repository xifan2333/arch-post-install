#!/bin/bash
# Enable and start services

print_substep "Check and enable services..."

# Check if NetworkManager is installed and enabled
if systemctl list-unit-files | grep -q NetworkManager.service; then
    if ! systemctl is-enabled NetworkManager &> /dev/null; then
        sudo systemctl enable --now NetworkManager
        print_success "NetworkManager enabled"
    else
        print_info "NetworkManager already enabled"
    fi
else
    print_warning "NetworkManager not installed: sudo pacman -S networkmanager"
fi

print_success "Services configured"
