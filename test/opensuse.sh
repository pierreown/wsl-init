#!/bin/sh

zypper -q ref
zypper -q install -y bash bash-completion wget sudo

{
    tee /etc/sudoers.d/wsl-init <<EOF
%wsl-init ALL=(root) NOPASSWD: /opt/wsl-init/wsl-init-enter.sh
%wsl-init ALL=(root) /usr/local/bin/wsl-init, /usr/local/bin/wsl-init-boot, /usr/local/bin/wsl-init-enter
EOF
    chmod 0440 /etc/sudoers.d/wsl-init
}

{
    groupadd wsl-init
    useradd -m -s /bin/bash -g wsl-init test-user

    tee /etc/wsl.conf <<EOF
[user]
default = "test-user"
EOF
}

{

    bash -c "$(wget -qO- https://raw.githubusercontent.com/pierreown/wsl-init/main/install.sh)"

    # disable services

    systemctl disable NetworkManager.service 2>/dev/null
    systemctl disable systemd-networkd.socket systemd-networkd.service 2>/dev/null
    systemctl disable systemd-resolved.service 2>/dev/null

    systemctl mask NetworkManager.service
    systemctl mask systemd-networkd.socket systemd-networkd.service
    systemctl mask systemd-resolved.service
    systemctl mask systemd-tmpfiles-setup.service
    systemctl mask systemd-tmpfiles-clean.service
    systemctl mask systemd-tmpfiles-clean.timer
    systemctl mask systemd-tmpfiles-setup-dev-early.service
    systemctl mask systemd-tmpfiles-setup-dev.service
    systemctl mask systemd-binfmt.service
    systemctl mask tmp.mount
}
