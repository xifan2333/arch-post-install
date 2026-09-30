# zsh plugins (installed via pacman)
for _plugin in \
    /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
    /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh \
    /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh; do
    [[ -f "$_plugin" ]] && source "$_plugin"
done
unset _plugin
