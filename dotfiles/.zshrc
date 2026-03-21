# ~/.zshrc
ZSH_CONFIG="$HOME/.config/zsh"

for conf in options completions plugins keybindings aliases tools; do
  [[ -f "$ZSH_CONFIG/$conf.zsh" ]] && source "$ZSH_CONFIG/$conf.zsh"
done
