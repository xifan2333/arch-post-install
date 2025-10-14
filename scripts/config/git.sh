#!/bin/bash
# Configure git

print_substep "Configure Git..."

# Ask for git user name and email if not configured
if ! git config --global user.name &> /dev/null; then
    read -p "Enter Git username: " git_username
    git config --global user.name "$git_username"
fi

if ! git config --global user.email &> /dev/null; then
    read -p "Enter Git email: " git_email
    git config --global user.email "$git_email"
fi

# Set default editor to vim
git config --global core.editor vim

# Set default branch name to main
git config --global init.defaultBranch main

print_success "Git configured"
