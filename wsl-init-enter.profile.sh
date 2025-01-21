#!/bin/sh

if [ ! "${WSL_INIT_NSENTER_FLAG-}" ]; then

    # Check if /opt/wsl-init/wsl-init-enter.sh exists
    if [ ! -x "/opt/wsl-init/wsl-init-enter.sh" ]; then
        export WSL_INIT_NSENTER_FLAG=3
    fi

    # If the current environment already in wsl-init, skip
    WSL_INIT_CMDLINE="$(tr '\0' ' ' </proc/1/cmdline 2>/dev/null || true)"
    if [ "${WSL_INIT_CMDLINE%% *}" = "/sbin/init" ]; then
        export WSL_INIT_NSENTER_FLAG=1
    fi
    unset WSL_INIT_CMDLINE

    if [ ! "${WSL_INIT_NSENTER_FLAG-}" ]; then

        wsl_init_enter() {
            # If current user is root
            if [ "$(id -u)" -eq 0 ]; then
                exec /opt/wsl-init/wsl-init-enter.sh "$@"
            fi

            # If can use sudo, and current user is in wsl-init group
            if type sudo >/dev/null 2>&1; then
                for WSL_INIT_SUDO_GROUP in $(groups); do
                    if [ "$WSL_INIT_SUDO_GROUP" = "wsl-init" ]; then
                        exec sudo /opt/wsl-init/wsl-init-enter.sh "$@"
                    fi
                done
                unset WSL_INIT_SUDO_GROUP
            fi
        }

        # Use login shell to reload profile
        if [ "${BASH-}" ] && [ "$BASH" != "/bin/sh" ]; then
            wsl_init_enter /bin/bash --login
        else
            wsl_init_enter /bin/sh -l
        fi

        unset -f wsl_init_enter
    fi
fi
