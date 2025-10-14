#!/bin/bash
# Preflight checks

print_substep "Check environment..."

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    print_error "Do not run as root"
    exit 1
fi

# Check if running on Arch Linux
if [ ! -f /etc/arch-release ]; then
    print_error "Only Arch Linux supported"
    exit 1
fi

# Check internet connectivity
print_substep "Check network..."
if ! ping -c 1 archlinux.org &> /dev/null; then
    print_error "Network unavailable"
    exit 1
fi

print_success "Environment check passed"
