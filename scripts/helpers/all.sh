#!/bin/bash
# Load all helper functions

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/presentation.sh"
source "$SCRIPT_DIR/logging.sh"
source "$SCRIPT_DIR/errors.sh"

# Export project root
export PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
export SCRIPTS_DIR="$PROJECT_ROOT/scripts"
export DOTFILES_DIR="$PROJECT_ROOT/dotfiles"
export RESOURCES_DIR="$PROJECT_ROOT/resources"
