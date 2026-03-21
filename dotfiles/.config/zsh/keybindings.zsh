# History substring search
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

# Cheatsheet (Ctrl+/)
zsh-cheatsheet() {
  local file="$HOME/.config/zsh/cheatsheet.txt"
  if [[ -f "$file" ]]; then
    local selected
    selected=$(cat "$file" | fzf --prompt="Cheatsheet: " --print-query | tail -1)
    if [[ -n "$selected" ]]; then
      LBUFFER="$selected"
    fi
  fi
  zle redisplay
}
zle -N zsh-cheatsheet
bindkey '^_' zsh-cheatsheet
