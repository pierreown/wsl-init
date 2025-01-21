#!/bin/sh

set -e

export E_RED="\033[31m"
export E_GRE="\033[32m"
export E_YEL="\033[33m"
export E_BLU="\033[34m"
export E_WHI="\033[37m"
export E_PLA="\033[0m"

fmt() {
    FMT_TYPE="$1"
    case "$FMT_TYPE" in
    TIT) shift && printf "${E_BLU}--- %s ---${E_PLA}\n" "$*" && return ;;
    SUC) shift && printf "${E_GRE}%s${E_PLA} " "$FMT_TYPE" ;;
    ERR) shift && printf "${E_RED}%s${E_PLA} " "$FMT_TYPE" ;;
    WRN | TIP) shift && printf "${E_YEL}%s${E_PLA} " "$FMT_TYPE" ;;
    INF) shift && printf "${E_WHI}%s${E_PLA} " "$FMT_TYPE" ;;
    esac
    printf "%s\n" "$*"
}

yes() {
    case "$1" in
    [yY] | [yY][eE][sS]) return 0 ;;
    *) return 1 ;;
    esac
}

pkg_install() {
    if type apt-get >/dev/null 2>&1; then
        apt-get update || true
        apt-get install -q -y "$@"
    elif type dnf >/dev/null 2>&1; then
        dnf install -y "$@"
    elif type yum >/dev/null 2>&1; then
        yum install -y "$@"
    elif type apk >/dev/null 2>&1; then
        apk add -q "$@"
    elif type zypper >/dev/null 2>&1; then
        zypper -q install -y "$@"
    elif type pacman >/dev/null 2>&1; then
        pacman -Syu --noconfirm "$@"
    else
        return 1
    fi
}

usage() {
    cat <<EOF

Usage: $0 [options]

Options:
  -f, --force       Force install dependencies
  --cdn             Use CDN for script downloads
  -h, --help        Show this help

EOF
}

check_missing_commands() {
    MISSING=0
    for ITEM in "$@"; do
        CMD_PATH=$(command -v "$ITEM" 2>/dev/null || true)
        if [ -n "$CMD_PATH" ]; then
            CMD_PATH=$(readlink -f "$CMD_PATH" 2>/dev/null || true)
        fi
        case "$CMD_PATH" in
        "")
            fmt TIP "Command missing: $ITEM"
            ;;
        */busybox)
            fmt TIP "Command provided by busybox: $ITEM"
            ;;
        *) continue ;;
        esac
        MISSING=1
    done
    return $MISSING
}

install_dependencies() {
    fmt TIT "Install Dependencies"

    set -- "wget" "unshare"
    if [ "$FLAG_FORCE" -eq 1 ]; then
        fmt INF "Force install dependencies..."
    elif ! check_missing_commands "$@"; then
        fmt INF "Missing some dependencies, trying to install..."
    else
        fmt INF "Founded all dependencies, skip"
        return 0
    fi

    set -- "wget" "util-linux"
    if pkg_install "$@"; then
        fmt SUC "Installed:" "$@"
    else
        fmt ERR "Failed to install dependencies" >&2
        fmt TIP "Please install by yourself:" "$@"
        exit 1
    fi
}

install_scripts() {
    fmt TIT "Download & Install"

    PREFIX="/opt/wsl-init" LINK_PREFIX="/usr/local/bin"

    if [ "$FLAG_CDN" -eq 1 ]; then
        fmt INF "Use CDN"
        BASE_URL="https://cdn.jsdelivr.net/gh/pierreown/wsl-init@main"
    else
        BASE_URL="https://raw.githubusercontent.com/pierreown/wsl-init/main"
    fi

    # Cleanup old files
    rm -rf "$PREFIX" && mkdir -p "$PREFIX"

    # Download Scripts
    set -- wsl-init.sh wsl-init-boot.sh wsl-init-enter.sh wsl-init-enter.profile.sh
    for ITEM in "$@"; do
        if wget -q -t 3 -w 1 -T 5 -O "$PREFIX/$ITEM" "$BASE_URL/$ITEM"; then
            chmod 755 "$PREFIX/$ITEM"
            fmt SUC "Downloaded $PREFIX/$ITEM"
        else
            fmt ERR "Failed to download $PREFIX/$ITEM" >&2 && exit 1
        fi
    done

    # Create Symlink
    set -- wsl-init.sh wsl-init-boot.sh wsl-init-enter.sh
    for ITEM in "$@"; do
        ln -sf "$PREFIX/$ITEM" "$LINK_PREFIX/${ITEM%.sh}"
        fmt SUC "Linked $PREFIX/$ITEM => $LINK_PREFIX/${ITEM%.sh}"
    done
}

main() {
    # Parse Options
    eval set -- "$(getopt -o ':fh' --long 'force,cdn,help' -- "$@" 2>/dev/null)"
    FLAG_FORCE=0 FLAG_CDN=0
    while true; do
        case "$1" in
        --) shift && break ;;
        -f | --force) FLAG_FORCE="1" ;;
        --cdn) FLAG_CDN="1" ;;
        -h | --help) usage && exit ;;
        esac
        shift
    done

    install_dependencies
    install_scripts
}

# Check User
[ "$(id -u)" -ne 0 ] && echo "Please run as root" >&2 && exit 1

main "$@"
