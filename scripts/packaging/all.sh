#!/bin/bash
# Install all packages

run_logged "$SCRIPTS_DIR/packaging/base.sh"
run_logged "$SCRIPTS_DIR/packaging/fonts.sh"
run_logged "$SCRIPTS_DIR/packaging/fcitx5.sh"
run_logged "$SCRIPTS_DIR/packaging/wayland.sh"
run_logged "$SCRIPTS_DIR/packaging/desktop.sh"
run_logged "$SCRIPTS_DIR/packaging/themes.sh"
run_logged "$SCRIPTS_DIR/packaging/apps.sh"
