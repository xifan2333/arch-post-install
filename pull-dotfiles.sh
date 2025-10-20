#!/bin/bash
# Pull dotfiles changes from ~/.dotfiles back to development directory
# This is the reverse operation of install-dotfiles.sh
# Usage: ./pull-dotfiles.sh [--dry-run]

# Simple output functions
print_step() { echo -e "\n\033[0;34m==>\033[0m \033[1;37m$1\033[0m"; }
print_substep() { echo -e "  \033[0;35m->\033[0m $1"; }
print_error() { echo -e "\033[0;31m[ERROR]\033[0m $1" >&2; }
print_success() { echo -e "\033[0;32m[OK]\033[0m $1"; }
print_info() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
print_warning() { echo -e "\033[1;33m[WARNING]\033[0m $1"; }

# --- Variables and tool checks ---
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_SRC="$SCRIPT_DIR/dotfiles"
DOTFILES_TARGET="$HOME/.dotfiles"

# Check for dry-run flag
DRY_RUN=false
if [ "$1" = "--dry-run" ] || [ "$1" = "-n" ]; then
    DRY_RUN=true
    print_warning "DRY RUN MODE - No files will be modified"
fi

# Check required tools
for tool in rsync git; do
    if ! command -v "$tool" &> /dev/null; then
        print_error "$tool is not installed. Please install it."
        exit 1
    fi
done

# Verify directories exist
if [ ! -d "$DOTFILES_TARGET" ]; then
    print_error "Target directory $DOTFILES_TARGET does not exist."
    print_info "Run install-dotfiles.sh first to set up the environment."
    exit 1
fi

if [ ! -d "$DOTFILES_SRC" ]; then
    print_error "Source directory $DOTFILES_SRC does not exist."
    exit 1
fi

# --- Step 1: Check for uncommitted changes in ~/.dotfiles ---
print_step "Checking Git status in $DOTFILES_TARGET"

cd "$DOTFILES_TARGET" || exit 1

if [ -d ".git" ]; then
    if ! git diff-index --quiet HEAD -- 2>/dev/null; then
        print_warning "Uncommitted changes detected in $DOTFILES_TARGET"
        git status -s
        print_info "These changes will be synced back to the development directory."
    else
        print_success "No uncommitted changes in $DOTFILES_TARGET"
    fi
else
    print_warning "$DOTFILES_TARGET is not a Git repository"
fi

# --- Step 2: Prepare rsync exclusions ---
print_step "Preparing sync exclusions"

EXCLUDE_ARGS=()
IGNORE_FILE="$SCRIPT_DIR/.dotsignore"

# Read exclusions from .dotsignore if it exists
if [ -f "$IGNORE_FILE" ]; then
    while IFS= read -r line; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        # Add to exclude args
        EXCLUDE_ARGS+=(--exclude="$line")
    done < "$IGNORE_FILE"
    print_substep "Loaded $(( ${#EXCLUDE_ARGS[@]} / 2 )) patterns from .dotsignore"
else
    print_warning ".dotsignore not found, using minimal exclusions"
    EXCLUDE_ARGS+=(--exclude=".git")
fi

# --- Step 3: Sync from ~/.dotfiles to development directory ---
print_step "Syncing changes: $DOTFILES_TARGET -> $DOTFILES_SRC"

RSYNC_OPTS=(
    -av                    # Archive mode + verbose
    --delete               # Delete files that don't exist in source
    --delete-excluded      # Also delete excluded files in destination
    "${EXCLUDE_ARGS[@]}"   # Apply exclusions
)

if [ "$DRY_RUN" = true ]; then
    RSYNC_OPTS+=(--dry-run)
fi

# Perform the sync
if rsync "${RSYNC_OPTS[@]}" "$DOTFILES_TARGET/" "$DOTFILES_SRC/"; then
    if [ "$DRY_RUN" = true ]; then
        print_info "Dry run completed. No files were modified."
        print_info "Run without --dry-run to apply changes."
    else
        print_success "Dotfiles synced: $DOTFILES_TARGET -> $DOTFILES_SRC"
    fi
else
    print_error "Failed to sync dotfiles"
    exit 1
fi

# --- Step 4: Show Git status in development directory ---
if [ "$DRY_RUN" = false ]; then
    print_step "Checking Git status in development directory"

    cd "$SCRIPT_DIR" || exit 1

    if [ -d ".git" ]; then
        if ! git diff-index --quiet HEAD -- 2>/dev/null; then
            print_warning "Changes detected in development directory"
            git status -s
            print_info "Review changes and commit with:"
            print_info "  cd $SCRIPT_DIR"
            print_info "  git add -p"
            print_info "  git commit -m 'Update dotfiles from ~/.dotfiles'"
        else
            print_success "No changes in development directory"
        fi
    else
        print_warning "Development directory is not a Git repository"
    fi
fi

# --- Step 5: Summary ---
print_step "Summary"
print_success "Pull operation completed successfully"
print_info "Source: $DOTFILES_TARGET"
print_info "Target: $DOTFILES_SRC"

if [ "$DRY_RUN" = false ]; then
    print_info ""
    print_info "Next steps:"
    print_info "  1. Review changes: cd $SCRIPT_DIR && git status"
    print_info "  2. Commit changes: git add -p && git commit"
    print_info "  3. Push to remote: git push"
fi

exit 0
