# TorrentOS — default Zsh config
# Override anything in ~/.zshrc.local (sourced at the bottom).

# ---- terminal key fixes ----
# Ensure backspace (DEL ^? and BS ^H) always work regardless of terminal type.
# This is needed because agetty autologin can leave stty erase in an odd state.
[[ -t 0 ]] && stty erase '^?' 2>/dev/null || true
bindkey "^?"  backward-delete-char   # DEL  (127) — standard backspace
bindkey "^H"  backward-delete-char   # BS   (8)   — Ctrl+H / some terminals
bindkey "^[[3~" delete-char          # Del key (forward delete)

# ---- history ----
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt SHARE_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_SPACE INC_APPEND_HISTORY HIST_VERIFY

# ---- directory stack ----
setopt AUTO_PUSHD PUSHD_IGNORE_DUPS PUSHD_MINUS

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

# Git shortcuts
alias gs='git status'
alias gd='git diff'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph --decorate --all -15'

# Python / dev tools
alias py='python3'
alias ports='ss -tulpn'
alias myip='curl -s ifconfig.me && echo'
alias weather='curl wttr.in'
alias ff='fastfetch'
alias neofetch='fastfetch'

# Safety
alias rm='rm -i'
alias mv='mv -i'
alias cp='cp -i'

# ---- TorrentOS helpers ----
# System update
alias update='if command -v paru >/dev/null; then paru -Syu; else sudo pacman -Syu; fi'
alias toros-version='grep TORRENTOS_VERSION /etc/torrentos/version 2>/dev/null | cut -d= -f2 | tr -d '"'"'"'"'"''
alias torrentos-update='torrentos-update-gui'

# Quick open
alias settings='torrentos-settings & disown'
alias files='nautilus & disown'
alias browser='xdg-open https:// 2>/dev/null & disown'
alias screenshot='torrentos-screenshot & disown'
alias doctor='torrentos-doctor'
alias get-browser='torrentos-get-browser'

# Clipboard
alias pbcopy='wl-copy'
alias pbpaste='wl-paste'
alias clip='wl-copy'

# Network
alias ip='ip --color=auto'
alias wifi='nmtui'
alias vpn='nmtui'

# Quick package search / info
alias pkgs='pacman -Ss'
alias pkgi='pacman -Qi'
alias pkgf='pacman -Ql'
alias pkgl='pacman -Qe'       # explicitly installed packages
alias pkgo='pacman -Qtdq'     # orphan packages
alias pkgclean='sudo pacman -Rns $(pacman -Qtdq) 2>/dev/null || echo "No orphans."'

# Disk / memory
alias disk='df -h | grep -v tmpfs'
alias mem='free -h'

# ---- functions ----

# Create a directory and immediately cd into it
mkcd() { mkdir -p "$1" && cd "$1" }

# Universal archive extractor
extract() {
    if [[ -z "$1" ]]; then
        echo "Usage: extract <archive>"
        return 1
    fi
    if [[ ! -f "$1" ]]; then
        echo "extract: '$1' is not a file"
        return 1
    fi
    case "$1" in
        *.tar.gz|*.tgz)      tar xzf "$1"        ;;
        *.tar.bz2|*.tbz2)    tar xjf "$1"        ;;
        *.tar.xz|*.txz)      tar xJf "$1"        ;;
        *.tar.zst)            tar --zstd -xf "$1" ;;
        *.tar)                tar xf  "$1"        ;;
        *.gz)                 gunzip  "$1"        ;;
        *.bz2)                bunzip2 "$1"        ;;
        *.xz)                 unxz    "$1"        ;;
        *.zst)                zstd -d "$1"        ;;
        *.zip)                unzip   "$1"        ;;
        *.7z)                 7z x    "$1"        ;;
        *.rar)                unrar x "$1"        ;;
        *.Z)                  uncompress "$1"     ;;
        *)  echo "extract: unknown archive format '$1'" ; return 1 ;;
    esac
}

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
    printf "${_dim}    Super + Shift + F   ${_rst}${_white}Maximize (no bar)${_rst}\n"
    printf "${_dim}    Super + Tab         ${_rst}${_white}Cycle windows${_rst}\n"
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
    printf "${_dim}    mkcd <dir>          ${_rst}${_white}Create directory and cd into it${_rst}\n"
    printf "${_dim}    extract <file>      ${_rst}${_white}Extract any archive format${_rst}\n"
    printf "${_dim}    ports               ${_rst}${_white}Show listening ports${_rst}\n"
    printf "${_dim}    weather             ${_rst}${_white}Show weather forecast${_rst}\n"
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

# ---- welcome banner (only in interactive login shells, only after first-boot) ----
# Suppress the banner during first-boot so it doesn't collide with the wizard logo.
if [[ -o interactive ]] && [[ -o login ]] && command -v tput >/dev/null \
   && [[ -f "$HOME/.config/torrentos/.firstboot-done" ]]; then
    _blue='\033[38;2;30;111;255m'
    _cyan='\033[38;2;91;192;235m'
    _white='\033[1;37m'
    _dim='\033[2;37m'
    _rst='\033[0m'
    _ver="$(grep '^TORRENTOS_VERSION=' /etc/torrentos/version 2>/dev/null | cut -d= -f2 | tr -d '"' || echo 0.4)"
    _uptime="$(uptime -p 2>/dev/null | sed 's/up //' || echo '?')"
    echo
    printf "${_blue}  +-----------------------------+${_rst}\n"
    printf "${_blue}  |${_rst}  ${_white}TorrentOS${_rst}  ${_dim}v${_ver}${_rst}             ${_blue}|${_rst}\n"
    printf "${_blue}  |${_rst}  ${_dim}Uptime: ${_cyan}${_uptime}${_rst}           ${_blue}|${_rst}\n"
    printf "${_blue}  +-----------------------------+${_rst}\n"
    printf "  ${_dim}Super+Space ${_rst}launcher  ${_dim}Super+Return ${_rst}terminal  ${_dim}Super+L ${_rst}lock\n"
    printf "  ${_dim}Type ${_rst}${_white}help${_dim} for a full reference.${_rst}\n\n"
fi

# ---- per-machine overrides ----
[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"