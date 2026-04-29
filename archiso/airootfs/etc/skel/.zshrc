# TorrentOS — default Zsh config
# Override anything in ~/.zshrc.local (sourced at the bottom).

# ---- history ----
HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_SPACE INC_APPEND_HISTORY

# ---- completion ----
autoload -Uz compinit
compinit -d "$HOME/.cache/zcompdump"
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

# ---- prompt: starship ----
if command -v starship >/dev/null; then
    eval "$(starship init zsh)"
fi

# ---- integrations ----
command -v zoxide >/dev/null && eval "$(zoxide init zsh --cmd cd)"
command -v fzf    >/dev/null && source <(fzf --zsh)
command -v mise   >/dev/null && eval "$(mise activate zsh)"

# ---- aliases ----
alias ls='eza --icons --group-directories-first'
alias ll='eza -lh --icons --group-directories-first'
alias la='eza -lah --icons --group-directories-first'
alias tree='eza --tree --icons'
alias cat='bat --paging=never --style=plain'
alias less='bat'
alias grep='grep --color=auto'
alias dc='docker compose'
alias k='kubectl'
alias g='git'
alias gs='git status'
alias gd='git diff'
alias gp='git pull'
alias ..='cd ..'
alias ...='cd ../..'

# ---- TorrentOS helpers ----
alias torrentos-update='topgrade'

# ---- per-machine overrides ----
[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
