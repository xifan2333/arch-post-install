#!/bin/bash
# Logging helpers

export LOG_FILE="/tmp/arch-post-install-$(date +%Y%m%d-%H%M%S).log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

run_logged() {
    local script=$1
    log "Running: $script"
    print_step "$(basename "$script" .sh)"

    if bash "$script" 2>&1 | tee -a "$LOG_FILE"; then
        log "SUCCESS: $script"
        return 0
    else
        log "FAILED: $script"
        return 1
    fi
}

show_log() {
    if [ -f "$LOG_FILE" ]; then
        print_info "Log file: $LOG_FILE"
    fi
}
