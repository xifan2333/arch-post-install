# fzf - fuzzy finder
if [ -f /usr/share/fzf/key-bindings.zsh ]; then
    source /usr/share/fzf/key-bindings.zsh
fi
if [ -f /usr/share/fzf/completion.zsh ]; then
    source /usr/share/fzf/completion.zsh
fi

# mise (development environment manager)
if command -v mise &> /dev/null; then
    eval "$(mise activate zsh)"
fi

# starship prompt
if command -v starship &> /dev/null; then
    eval "$(starship init zsh)"
fi

# zoxide - smarter cd
if command -v zoxide &> /dev/null; then
    eval "$(zoxide init zsh)"
fi
