#!/bin/bash
# Cleanup and final steps

print_substep "Cleanup..."

# Clean package cache (keep last 2 versions)
sudo pacman -Sc --noconfirm || true

# Remove orphaned packages
orphans=$(pacman -Qdtq 2>/dev/null || true)
if [ -n "$orphans" ]; then
    echo "$orphans" | sudo pacman -Rns --noconfirm - || print_warning "Some orphans couldn't be removed"
    print_success "Orphaned packages removed"
fi

print_success "Cleanup done"
