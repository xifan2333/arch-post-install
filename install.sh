#!/bin/bash
# Arch Linux Post-Install Setup
# Main installation script

# Do NOT use set -e, handle errors explicitly

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SCRIPTS_DIR="$SCRIPT_DIR/scripts"

# Load helpers
source "$SCRIPTS_DIR/helpers/all.sh"

# Show banner
print_banner

# Main installation flow
main() {
    print_info "Arch Linux Post-Install Setup"
    echo ""

    if ! confirm "Start installation?" "y"; then
        print_info "Installation cancelled"
        exit 0
    fi

    log "=== Installation started ==="

    # Phase 1: Preflight checks
    print_step "Phase 1: Preflight"
    source "$SCRIPTS_DIR/preflight/all.sh"

    # Phase 2: Package installation
    print_step "Phase 2: Packages"
    source "$SCRIPTS_DIR/packaging/all.sh"

    # Phase 3: Configuration
    print_step "Phase 3: Configuration"
    source "$SCRIPTS_DIR/config/all.sh"

    # Phase 4: Post-installation
    print_step "Phase 4: Post-install"
    source "$SCRIPTS_DIR/post-install/all.sh"

    # Done
    echo ""
    print_success "Installation complete!"
    echo ""
    print_info "Next steps:"
    print_substep "1. Logout and login to apply input method"
    print_substep "2. Start River WM from display manager"
    print_substep "3. Run fcitx5-configtool to add rime"
    echo ""

    show_log
    log "=== Installation completed successfully ==="
}

# Run main installation
main "$@"
