#!/bin/bash
# Error handling

# Note: Do NOT use 'set -e' as it will exit on expected failures
# Each script should handle errors explicitly

handle_error() {
    local line_number=$1
    print_error "Error at line ${line_number}"
    log "ERROR at line ${line_number}"
    show_log
    exit 1
}

check_command() {
    if ! command -v "$1" &> /dev/null; then
        print_error "Command '$1' not found"
        return 1
    fi
    return 0
}

confirm() {
    local prompt="${1:-Continue?}"
    local default="${2:-n}"

    if [ "$default" = "y" ]; then
        prompt="$prompt [Y/n]: "
    else
        prompt="$prompt [y/N]: "
    fi

    read -p "$prompt" response
    response=${response:-$default}

    case "$response" in
        [yY][eE][sS]|[yY]) return 0 ;;
        *) return 1 ;;
    esac
}
