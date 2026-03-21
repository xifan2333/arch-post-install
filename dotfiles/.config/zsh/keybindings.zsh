# History substring search
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

# Cheatsheet (Ctrl+/)
zsh-cheatsheet() {
  local file="$HOME/.config/zsh/cheatsheet.txt"
  if [[ -f "$file" ]]; then
    local selected
    selected=$(fzf --prompt="Cheatsheet: " --print-query < "$file" | head -1)
    if [[ -n "$selected" ]]; then
      LBUFFER="$selected"
      zle accept-line
    fi
  fi
  zle redisplay
}
zle -N zsh-cheatsheet
bindkey '^_' zsh-cheatsheet
