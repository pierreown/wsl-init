#!/bin/sh

apk add bash bash-completion wget sudo

{
    tee /etc/sudoers.d/wsl-init <<EOF
%wsl-init ALL=(root) NOPASSWD: /opt/wsl-init/wsl-init-enter.sh
%wsl-init ALL=(root) /usr/local/bin/wsl-init, /usr/local/bin/wsl-init-boot, /usr/local/bin/wsl-init-enter
EOF
    chmod 0440 /etc/sudoers.d/wsl-init
}

{
    addgroup wsl-init
    adduser -h /home/wsl-init -s /bin/bash -D -G wsl-init test-user

    tee /etc/wsl.conf <<EOF
[user]
default = "test-user"
EOF
}

{
    bash -c "$(wget -qO- https://raw.githubusercontent.com/pierreown/wsl-init-script/main/install.sh)"

    # disable services
    rc-update del networking default
}
