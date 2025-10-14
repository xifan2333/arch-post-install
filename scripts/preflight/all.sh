#!/bin/bash
# Run all preflight checks

run_logged "$SCRIPTS_DIR/preflight/guard.sh"
run_logged "$SCRIPTS_DIR/preflight/pacman.sh"
