#!/bin/sh

fmt() {
    FMT_TYPE="$1"
    case "$FMT_TYPE" in
    TIT) shift && printf "\033[34m--- %s ---\033[0m\n" "$*" && return ;;
    SUC) shift && printf "\033[32m%s\033[0m " "$FMT_TYPE" ;;
    ERR) shift && printf "\033[31m%s\033[0m " "$FMT_TYPE" ;;
    WRN | TIP) shift && printf "\033[33m%s\033[0m " "$FMT_TYPE" ;;
    INF) shift && printf "\033[37m%s\033[0m " "$FMT_TYPE" ;;
    esac
    printf "%s\n" "$*"
}

[ "$(id -u)" -ne 0 ] && echo "Please run as root" >&2 && exit 1

cd "$(dirname "$0")/../" || exit

PREFIX="/opt/wsl-init" LINK_PREFIX="/usr/local/bin"
rm -rf $PREFIX && mkdir -p $PREFIX

for ITEM in wsl-init*.sh; do
    cp "$ITEM" "$PREFIX/$ITEM"
    chmod 755 "$PREFIX/$ITEM"
    fmt SUC "Downloaded $PREFIX/$ITEM"
done

for ITEM in wsl-init.sh wsl-init-boot.sh wsl-init-enter.sh; do
    ln -sf "$PREFIX/$ITEM" "$LINK_PREFIX/${ITEM%.sh}"
    fmt SUC "Linked $PREFIX/$ITEM => $LINK_PREFIX/${ITEM%.sh}"
done
