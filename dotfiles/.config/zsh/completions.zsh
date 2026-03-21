# Load zsh-completions
if [ -d /usr/share/zsh/site-functions ]; then
    fpath=(/usr/share/zsh/site-functions $fpath)
fi

# Initialize completion system
autoload -Uz compinit
compinit
