#!/bin/bash
# Presentation helpers for colored output and progress display

# Color definitions
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export MAGENTA='\033[0;35m'
export CYAN='\033[0;36m'
export WHITE='\033[1;37m'
export RESET='\033[0m'

# Print functions
print_error() {
    echo -e "${RED}[ERROR]${RESET} $1" >&2
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${RESET} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${RESET} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${RESET} $1"
}

print_step() {
    echo -e "\n${CYAN}==>${RESET} ${WHITE}$1${RESET}"
}

print_substep() {
    echo -e "  ${MAGENTA}->${RESET} $1"
}

# Progress spinner
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while ps -p "$pid" > /dev/null 2>&1; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Banner
print_banner() {
    clear
    echo -e "${CYAN}"
    cat << 'EOF'
    ╔═══════════════════════════════════════════╗
    ║   Arch Linux Post-Install Setup           ║
    ╚═══════════════════════════════════════════╝
EOF
    echo -e "${RESET}\n"
}
