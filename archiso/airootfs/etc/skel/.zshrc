# TorrentOS — default Zsh config
# Override anything in ~/.zshrc.local (sourced at the bottom).

# ---- history ----
HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_SPACE INC_APPEND_HISTORY

# ---- completion ----
autoload -Uz compinit
# -u suppresses insecure directory warnings (expected on live ISO running as root)
compinit -u -d "$HOME/.cache/zcompdump"
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
# System update — prefers paru (AUR helper), falls back to pacman
alias torrentos-update='if command -v paru >/dev/null; then paru -Syu --noconfirm; else sudo pacman -Syu --noconfirm; fi'
alias update='torrentos-update'
alias toros-version='cat /etc/torrentos/version 2>/dev/null || grep VERSION_ID /etc/os-release'

# Quick system info
alias sysinfo='echo "  TorrentOS $(toros-version 2>/dev/null)" && uname -rmo'

# ---- welcome banner (only in interactive login shells) ----
if [[ -o interactive ]] && [[ -o login ]] && command -v tput >/dev/null; then
    _blue='\033[38;2;30;111;255m'
    _white='\033[1;37m'
    _dim='\033[2;37m'
    _rst='\033[0m'
    printf "\n${_blue}  TorrentOS${_rst}  ${_dim}v$(cat /etc/torrentos/version 2>/dev/null || echo 0.4)${_rst}\n"
    printf "${_dim}  torrentos.github.io  ·  type ${_rst}${_white}help${_dim} for commands${_rst}\n\n"
fi

# ---- per-machine overrides ----
[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
