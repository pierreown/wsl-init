#!/bin/sh

# Enter PID namespace of the init process

# Check if the script is run by root user
[ "$(id -u)" -ne 0 ] && echo "Please run as root" >&2 && exit 1

# If the current environment already in wsl-init, exit immediately
CMDLINE="$(tr '\0' ' ' </proc/1/cmdline 2>/dev/null || true)"
if [ "${CMDLINE%% *}" = "/sbin/init" ]; then
    echo "Already in wsl-init, no need enter again" >&2
    exit 1
fi

INIT_PREFIX="/var/run/wsl-init"
INIT_PID_FILE="$INIT_PREFIX/init.pid"

wait_for_init() {
    INIT_PID=""

    # Retry up to 10 times to get init PID
    while [ -f "$INIT_PID_FILE" ] && [ "${RETRY_TIMES:=0}" -lt 10 ]; do
        INIT_PID="$(tr '\0' ' ' <"$INIT_PID_FILE" 2>/dev/null || true)"
        if [ -n "$INIT_PID" ] && [ -e "/proc/$INIT_PID" ]; then
            echo "$INIT_PID"
            return 0
        fi
        sleep 0.3
        RETRY_TIMES=$((RETRY_TIMES + 1))
    done
    return 1
}

# If the script is run without arguments, use the default shell
if [ $# -eq 0 ]; then
    set -- "${SHELL:-/bin/sh}"
fi
# shellcheck disable=SC2016
set -- sh -c 'cd "$_PWD_"; unset _PWD_ OLDPWD SHLVL; exec "$@"' -- "$@"

# Wait for the init process
INIT_PID="$(wait_for_init)"

# If the script is run without sudo，current user is root, directly enter
if [ -z "$SUDO_USER" ]; then
    case "$INIT_PID" in
    '')
        echo "Cannot find init process, cannot enter wsl-init environment" >&2
        exec \
            env WSL_INIT_NSENTER_FLAG=2 _PWD_="${PWD:-/}" "$@"
        ;;
    *)
        exec nsenter -aF -t "$INIT_PID" -- setsid -cw \
            env WSL_INIT_NSENTER_FLAG=1 _PWD_="${PWD:-/}" "$@"
        ;;
    esac
fi

# Switch to the original user to prevent privilege escalation
: "${SUDO_UID:=$(id -u "$SUDO_USER" 2>/dev/null || true)}"
: "${SUDO_GID:=$(id -g "$SUDO_USER" 2>/dev/null || true)}"

case "$INIT_PID" in
'')
    echo "Cannot find init process, cannot enter wsl-init environment" >&2
    exec setpriv --reuid "${SUDO_UID:?}" --regid "${SUDO_GID:?}" --init-groups --reset-env -- \
        env WSL_INIT_NSENTER_FLAG=2 _PWD_="${PWD:-/}" "$@"
    ;;
*)
    exec nsenter -aF -t "$INIT_PID" -- setsid -cw \
        setpriv --reuid "${SUDO_UID:?}" --regid "${SUDO_GID:?}" --init-groups --reset-env -- \
        env WSL_INIT_NSENTER_FLAG=1 _PWD_="${PWD:-/}" "$@"
    ;;
esac
