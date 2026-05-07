# TorrentOS — default Zsh config
# Override anything in ~/.zshrc.local (sourced at the bottom).

# ---- history ----
HISTFILE="$HOME/.zsh_history"
HISTSIZE=20000
SAVEHIST=20000
setopt SHARE_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_SPACE INC_APPEND_HISTORY HIST_VERIFY

# ---- completion ----
autoload -Uz compinit
# -u suppresses insecure directory warnings (expected on live ISO running as root)
compinit -u -d "$HOME/.cache/zcompdump"
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*:descriptions' format '%F{blue}── %d ──%f'
zstyle ':completion:*' group-name ''

# ---- prompt: starship ----
if command -v starship >/dev/null; then
    eval "$(starship init zsh)"
fi

# ---- integrations ----
command -v zoxide >/dev/null && eval "$(zoxide init zsh --cmd cd)"
command -v fzf    >/dev/null && source <(fzf --zsh)
command -v mise   >/dev/null && eval "$(mise activate zsh)"

# ---- fzf options ----
export FZF_DEFAULT_OPTS="
  --color=bg+:#0e1c37,bg:#070f1d,spinner:#1E6FFF,hl:#7AADFF
  --color=fg:#F4F7FB,header:#7AADFF,info:#B0C4DE,pointer:#1E6FFF
  --color=marker:#5BC0EB,fg+:#F4F7FB,prompt:#1E6FFF,hl+:#5BC0EB
  --border=rounded --layout=reverse --height=50%
  --preview-window=right:50%:wrap
"
export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers {} 2>/dev/null || ls -la {}'"
export FZF_ALT_C_OPTS="--preview 'eza --tree --icons --color=always {} | head -50'"

# ---- aliases ----
# File listing
alias ls='eza --icons --group-directories-first'
alias ll='eza -lh --icons --group-directories-first --git'
alias la='eza -lah --icons --group-directories-first --git'
alias lt='eza --tree --icons --level=2'
alias lta='eza --tree --icons --level=3 -a'
alias tree='eza --tree --icons'

# Pagers
alias cat='bat --paging=never --style=plain'
alias less='bat --paging=always'
alias more='bat --paging=always'
alias grep='grep --color=auto'
alias diff='diff --color=auto'

# System
alias df='df -h'
alias du='du -h'
alias free='free -h'
alias top='btop'
alias htop='btop'
alias ps='ps aux'

# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias ~='cd ~'
alias -- -='cd -'

# Containers / dev
alias dc='docker compose'
alias dcu='docker compose up -d'
alias dcd='docker compose down'
alias dcl='docker compose logs -f'
alias k='kubectl'
alias kns='kubectl config set-context --current --namespace'
alias g='git'
alias gs='git status'
alias gd='git diff'
alias gp='git pull'
alias gl='git log --oneline --graph --decorate'

# Safety
alias rm='rm -i'
alias mv='mv -i'
alias cp='cp -i'

# ---- TorrentOS helpers ----
# System update
alias update='if command -v paru >/dev/null; then paru -Syu; else sudo pacman -Syu; fi'
alias toros-version='grep TORRENTOS_VERSION /etc/torrentos/version 2>/dev/null | cut -d= -f2'

# Quick open
alias settings='torrentos-settings & disown'
alias files='nautilus & disown'
alias browser='firefox & disown'
alias screenshot='torrentos-screenshot & disown'
alias doctor='torrentos-doctor'

# Clipboard
alias pbcopy='wl-copy'
alias pbpaste='wl-paste'

# Network
alias ip='ip --color=auto'
alias myip='curl -s https://api.ipify.org && echo'

# Quick package search / info
alias pkgs='pacman -Ss'
alias pkgi='pacman -Qi'
alias pkgf='pacman -Ql'

# ---- help command ----
help() {
    local _blue='\033[38;2;30;111;255m'
    local _cyan='\033[38;2;91;192;235m'
    local _white='\033[1;37m'
    local _dim='\033[2;37m'
    local _rst='\033[0m'
    echo
    printf "${_blue}  TorrentOS — Quick Reference${_rst}\n"
    printf "${_dim}  ─────────────────────────────────────────────────────${_rst}\n"
    echo
    printf "${_cyan}  Desktop shortcuts:${_rst}\n"
    printf "${_dim}    Super + Space       ${_rst}${_white}App launcher (Spotlight)${_rst}\n"
    printf "${_dim}    Super + Return      ${_rst}${_white}Open terminal${_rst}\n"
    printf "${_dim}    Super + E           ${_rst}${_white}Open file manager${_rst}\n"
    printf "${_dim}    Super + L           ${_rst}${_white}Lock screen${_rst}\n"
    printf "${_dim}    Super + Q           ${_rst}${_white}Close window${_rst}\n"
    printf "${_dim}    Super + F           ${_rst}${_white}Fullscreen${_rst}\n"
    printf "${_dim}    Super + Shift + F   ${_rst}${_white}Float / tile toggle${_rst}\n"
    printf "${_dim}    Super + 1-9         ${_rst}${_white}Switch workspace${_rst}\n"
    printf "${_dim}    Super + Shift + S   ${_rst}${_white}Screenshot (region)${_rst}\n"
    printf "${_dim}    Print               ${_rst}${_white}Screenshot (full, to clipboard)${_rst}\n"
    echo
    printf "${_cyan}  Terminal aliases:${_rst}\n"
    printf "${_dim}    update              ${_rst}${_white}Update all packages${_rst}\n"
    printf "${_dim}    ll                  ${_rst}${_white}Long file listing with icons${_rst}\n"
    printf "${_dim}    lt                  ${_rst}${_white}Tree view (2 levels)${_rst}\n"
    printf "${_dim}    btop                ${_rst}${_white}System monitor${_rst}\n"
    printf "${_dim}    pbcopy / pbpaste    ${_rst}${_white}Clipboard (like macOS)${_rst}\n"
    printf "${_dim}    cd <fuzzy>          ${_rst}${_white}Smart directory jump (zoxide)${_rst}\n"
    echo
    printf "${_cyan}  System:${_rst}\n"
    printf "${_dim}    settings            ${_rst}${_white}Open TorrentOS Settings${_rst}\n"
    printf "${_dim}    update              ${_rst}${_white}Full system upgrade${_rst}\n"
    printf "${_dim}    doctor              ${_rst}${_white}System health check${_rst}\n"
    printf "${_dim}    toros-version       ${_rst}${_white}Show OS version${_rst}\n"
    printf "${_dim}    myip                ${_rst}${_white}Show public IP address${_rst}\n"
    echo
    printf "${_dim}  Run ${_rst}${_white}torrentos-help${_dim} for the full reference.  Site: torrentos.org${_rst}\n"
    echo
}

# ---- welcome banner (only in interactive login shells) ----
if [[ -o interactive ]] && [[ -o login ]] && command -v tput >/dev/null; then
    _blue='\033[38;2;30;111;255m'
    _cyan='\033[38;2;91;192;235m'
    _white='\033[1;37m'
    _dim='\033[2;37m'
    _rst='\033[0m'
    _ver="$(grep '^TORRENTOS_VERSION=' /etc/torrentos/version 2>/dev/null | cut -d= -f2 | tr -d '"' || echo 0.4)"
    printf "\n${_blue}  TorrentOS${_rst}  ${_dim}v${_ver}${_rst}"
    printf "   ${_dim}$(uname -r | cut -d- -f1) kernel${_rst}\n"
    printf "${_dim}  Type ${_rst}${_white}help${_dim} for a quick reference.${_rst}\n\n"
fi

# ---- per-machine overrides ----
[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
