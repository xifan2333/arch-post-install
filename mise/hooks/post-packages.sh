#!/usr/bin/env bash
# Post-packages hook: install or update pixel fonts from GitHub releases
set -euo pipefail

# Ensure required tools are available
for cmd in gh unzip fc-cache; do
    if ! command -v "$cmd" &>/dev/null; then
        printf 'post-packages: %s not found, skipping pixel fonts download\n' "$cmd"
        exit 0
    fi
done

dest="${XDG_DATA_HOME:-$HOME/.local/share}/fonts"
mkdir -p "$dest"

# Check if pixel fonts are already present
if compgen -G "$dest/fusion-pixel-12px-monospaced-*.ttf" >/dev/null &&
    compgen -G "$dest/Uranus_Pixel*.ttf" >/dev/null &&
    compgen -G "$dest/BoutiqueBitmap7x7_*.ttf" >/dev/null; then
    printf 'post-packages: pixel fonts already installed in %s\n' "$dest"
    exit 0
fi

printf 'post-packages: downloading and installing pixel fonts...\n'
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/fusion" "$tmp/uranus" "$tmp/boutique"

# 1. Fusion Pixel 12px
if ! compgen -G "$dest/fusion-pixel-12px-monospaced-*.ttf" >/dev/null; then
    if gh release download --repo TakWolf/fusion-pixel-font \
        --pattern 'fusion-pixel-font-12px-monospaced-ttf-v*.zip' \
        --dir "$tmp/fusion" 2>/dev/null; then
        rm -f "$dest"/fusion-pixel-12px-monospaced-*.ttf
        unzip -oj "$tmp/fusion"/*.zip -d "$dest" >/dev/null 2>&1 || true
        printf 'post-packages: Fusion Pixel 12px installed\n'
    fi
fi

# 2. Uranus Pixel 11px
if ! compgen -G "$dest/Uranus_Pixel*.ttf" >/dev/null; then
    if gh release download --repo scott0107000/Uranus-Pixel \
        --pattern 'Uranus_Pixel.zip' \
        --dir "$tmp/uranus" 2>/dev/null; then
        rm -f "$dest"/Uranus_Pixel*.ttf
        unzip -oj "$tmp/uranus"/*.zip -d "$dest" >/dev/null 2>&1 || true
        printf 'post-packages: Uranus Pixel 11px installed\n'
    fi
fi

# 3. BoutiqueBitmap 7x7
if ! compgen -G "$dest/BoutiqueBitmap7x7_*.ttf" >/dev/null; then
    if gh release download --repo scott0107000/BoutiqueBitmap7x7 \
        --pattern 'BoutiqueBitmap7x7_[0-9]*.ttf' \
        --dir "$tmp/boutique" 2>/dev/null; then
        rm -f "$dest"/BoutiqueBitmap7x7_*.ttf
        install -m 0644 "$tmp/boutique"/BoutiqueBitmap7x7_*.ttf "$dest/" 2>/dev/null || true
        printf 'post-packages: BoutiqueBitmap7x7 installed\n'
    fi
fi

fc-cache -f "$dest" 2>/dev/null || true
printf 'post-packages: pixel fonts setup complete.\n'
