# ~/.zshrc - Minimal zsh configuration

# PATH
export PATH="$HOME/.local/bin:$PATH"

# History
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE

# Basic options
setopt AUTO_CD
setopt CORRECT

# Load zsh-completions
if [ -d /usr/share/zsh/site-functions ]; then
    fpath=(/usr/share/zsh/site-functions $fpath)
fi

# Initialize completion system
autoload -Uz compinit
compinit

# Load zsh plugins
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh

# Bind keys for history-substring-search
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

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

# eza - modern ls replacement
if command -v eza &> /dev/null; then
    alias ls='eza'
    alias ll='eza -l --icons --git'
    alias la='eza -la --icons --git'
    alias lt='eza --tree --level=2 --icons'
    alias l='eza -lah --icons --git'
    alias tree='eza --tree --icons'
fi



# starship prompt (must be at the end)
if command -v starship &> /dev/null; then
    eval "$(starship init zsh)"
fi

# zoxide - smarter cd

if command -v zoxide &> /dev/null; then
    eval "$(zoxide init zsh)"
fi

# Codex Config Manager - auto-generated
[[ -f "/home/xifan/.config/codex/env" ]] && source "/home/xifan/.config/codex/env"

# Claude Config Manager - auto-generated
[[ -f "/home/xifan/.config/claude/env" ]] && source "/home/xifan/.config/claude/env"
