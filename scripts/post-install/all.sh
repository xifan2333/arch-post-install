#!/bin/bash
# Post-installation tasks

run_logged "$SCRIPTS_DIR/post-install/services.sh"
run_logged "$SCRIPTS_DIR/post-install/cleanup.sh"
