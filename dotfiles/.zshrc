# ~/.zshrc
ZSH_CONFIG="$HOME/.config/zsh"

for conf in options completions plugins keybindings aliases tools; do
  [[ -f "$ZSH_CONFIG/$conf.zsh" ]] && source "$ZSH_CONFIG/$conf.zsh"
done

# secrets (untracked, gitignored) — API keys 等敏感信息
[[ -f "$ZSH_CONFIG/secrets.zsh" ]] && source "$ZSH_CONFIG/secrets.zsh"
