# Zsh configuration with starship
# Clean and simple setup using pacman packages

# ============================================================================
# Load theme colors
# ============================================================================
THEME_CONFIG="$HOME/.config/theme/colors.sh"
if [ -f "$THEME_CONFIG" ]; then
    source "$THEME_CONFIG"
fi

# ============================================================================
# Environment variables
# ============================================================================
export EDITOR="nvim"
export VISUAL="nvim"
export PAGER="less"

# ============================================================================
# PATH
# ============================================================================
export PATH="$HOME/.local/bin:$PATH"

# ============================================================================
# Zsh options
# ============================================================================
setopt AUTO_CD              # Auto cd when typing directory name
setopt AUTO_PUSHD           # Push old directory to stack
setopt PUSHD_IGNORE_DUPS    # Don't push duplicates
setopt INTERACTIVE_COMMENTS # Allow comments in interactive shell
setopt HIST_IGNORE_DUPS     # Don't save duplicate commands
setopt HIST_IGNORE_SPACE    # Don't save commands starting with space
setopt SHARE_HISTORY        # Share history across sessions
setopt EXTENDED_HISTORY     # Save timestamp in history

# History settings
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000

# ============================================================================
# Key bindings
# ============================================================================
bindkey -e  # Emacs key bindings

# ============================================================================
# Zsh plugins (installed via pacman)
# ============================================================================

# Load zsh-autosuggestions
if [ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
    source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
fi

# Load zsh-syntax-highlighting (must be loaded last)
if [ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
    source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# Load zsh-history-substring-search
if [ -f /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh ]; then
    source /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh
    # Bind arrow keys for history search
    bindkey '^[[A' history-substring-search-up
    bindkey '^[[B' history-substring-search-down
fi

# ============================================================================
# Completion system
# ============================================================================
autoload -Uz compinit
compinit

# Use zsh-completions if available
if [ -d /usr/share/zsh/site-functions ]; then
    fpath=(/usr/share/zsh/site-functions $fpath)
fi

# ============================================================================
# Aliases
# ============================================================================
alias ls='ls --color=auto'
alias ll='ls -lh'
alias la='ls -lah'
alias grep='grep --color=auto'
alias vim='nvim'
alias v='nvim'

# Git aliases
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph'

# System aliases
alias update='sudo pacman -Syu'
alias install='sudo pacman -S'
alias search='pacman -Ss'

# ============================================================================
# Starship prompt (must be at the end)
# ============================================================================
if command -v starship >/dev/null 2>&1; then
    eval "$(starship init zsh)"
fi
