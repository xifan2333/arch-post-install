# zoxide - smarter cd
if command -v zoxide &> /dev/null; then
    alias cd='z'
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

# janim - fix OpenGL context error
alias janim='LIBGL_ALWAYS_SOFTWARE=1 janim'

# git
alias g='git'
alias ga='git add'
alias gaa='git add -A'
alias gc='git commit'
alias gcm='git commit -m'
alias gp='git push'
alias gl='git pull'
alias gs='git status'
alias gd='git diff'
alias glog='git log --oneline --graph'
alias gb='git branch'
alias gco='git checkout'
alias gsw='git switch'

# systemctl
alias sc='sudo systemctl'
alias scu='systemctl --user'
alias scr='sudo systemctl restart'
alias scs='sudo systemctl status'

# grep -> ripgrep
if command -v rg &> /dev/null; then
    alias grep='rg'
fi

# package management
alias pi='package-install'
alias pia='package-install-aur'
alias pr='package-remove'
if command -v gh &> /dev/null; then
    alias ghpr='gh pr create'
    alias ghprl='gh pr list'
    alias ghprv='gh pr view --web'
    alias ghis='gh issue list'
    alias ghic='gh issue create'
    alias ghiv='gh issue view --web'
    alias ghrc='gh repo clone'
    alias ghrv='gh repo view --web'
    alias ghs='gh search repos'
    alias ghsc='gh search code'
    alias ghsi='gh search issues'
    alias ghrl='gh run list'
    alias ghrw='gh run watch'
    alias ghwl='gh workflow list'
    alias ghwr='gh workflow run'
fi

# dotfiles management
alias dot='cd ~/code/arch-post-install && kiro-cli'
