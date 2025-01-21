#!/bin/sh

# Boot the init process in a new PID namespace

# Check if the script is run by root user
[ "$(id -u)" -ne 0 ] && echo "Please run as root" >&2 && exit 1

# Check if /sbin/init exists
if [ ! -x "/sbin/init" ]; then
    echo "/sbin/init not found"
    exit 1
fi

# If the current environment already in wsl-init, exit immediately
CMDLINE="$(tr '\0' ' ' </proc/1/cmdline 2>/dev/null || true)"
if [ "${CMDLINE%% *}" = "/sbin/init" ]; then
    echo "Already in wsl-init, cannot boot again" >&2
    exit 1
fi

INIT_PREFIX="/var/run/wsl-init"
INIT_PID_FILE="$INIT_PREFIX/init.pid"
INIT_PIPE_FILE="$INIT_PREFIX/boot.pipe"

mkdir -p /var/run/lock
exec 9>"/var/run/lock/wsl-init.lock"

if ! flock -nx 9; then
    echo "Another instance is running, cannot boot again" >&2
    exit 1
fi

# Cleanup old files
rm -rf "${INIT_PREFIX:?}" && mkdir -p "${INIT_PREFIX:?}"

# Setup the cleanup function
cleanup() {
    rm -rf "${INIT_PREFIX:?}"
    if [ -n "$BOOT_PID" ]; then
        kill -kill "$BOOT_PID" >/dev/null 2>&1
    fi
}
trap 'cleanup' EXIT
trap 'exit 0' INT TERM

# Clear the init PID file
: >"$INIT_PID_FILE"

# Create a named pipe (FIFO)
mkfifo "$INIT_PIPE_FILE"

# Start unshare with a new PID and mount namespace, and run /sbin/init.
# Two levels of unshare: let PID and MOUNT namespaces on same process.
#   - PID namespace need fork.
#   - MOUNT namespace to mount /proc, /proc is private mount, other mounts are shared.
unshare -p -f --kill-child -- unshare --mount-proc --propagation shared -- \
    sh -c "echo 'ready' >'$INIT_PIPE_FILE'; exec /sbin/init;" &
BOOT_PID=$!

# Wait for the child process to notify the parent
read -r _ <"$INIT_PIPE_FILE"
rm -f "$INIT_PIPE_FILE"

# Check unshare process
if ! kill -0 "$BOOT_PID" >/dev/null 2>&1; then
    echo "Failed to start unshare process"
    exit 1
fi

# Read the children PIDs
eval set -- "$(tr '\0' ' ' <"/proc/$BOOT_PID/task/$BOOT_PID/children" 2>/dev/null || true)"

# Find the init process, default to the first child
INIT_PID="$1"
for CHILD_PID in "$@"; do
    CMD_FILE="/proc/$CHILD_PID/cmdline"
    [ -f "$CMD_FILE" ] || continue
    CMDLINE="$(tr '\0' ' ' <"$CMD_FILE" 2>/dev/null || true)"
    [ "${CMDLINE%% *}" = "/sbin/init" ] || continue
    INIT_PID="$CHILD_PID"
    break
done

# Check init process
if [ -z "$INIT_PID" ] || ! kill -0 "$INIT_PID" >/dev/null 2>&1; then
    echo "Failed to start init process"
    exit 1
fi

# Write the init PID to the file
echo "$INIT_PID" >"$INIT_PID_FILE"

# Wait for the unshare process to exit
wait "$BOOT_PID"
