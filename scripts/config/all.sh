#!/bin/bash
# Run all configuration scripts

run_logged "$SCRIPTS_DIR/config/localization.sh"
run_logged "$SCRIPTS_DIR/config/fcitx5-setup.sh"
run_logged "$SCRIPTS_DIR/config/git.sh"
