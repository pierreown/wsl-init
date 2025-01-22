# wsl-init shell script

`wsl-init` 是一套通用的 wsl2 初始化系统启动脚本。wsl2 已经支持启动 systemd，但不支持其它初始化系统（sysvinit，upstart，openrc 等），本脚本使用 `unshare` `nsenter` `sudoer` 实现在独立的 PID Namespace 中启动初始化系统，理论上可以支持任何初始化系统。脚本设计遵循 **最小依赖原则** 和 **最小权限原则**。

## 安装

要安装 `wsl-init`，请运行以下命令：

```bash
sh -c "$(wget -qO- https://raw.githubusercontent.com/pierreown/wsl-init/main/install.sh)"
```

或

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/pierreown/wsl-init/main/install.sh)"
```

使用 CDN 加速：(可能会因为 CDN 缓存影响导致脚本版本不一致)

```bash
sh -c "$(wget -fsSL https://cdn.jsdelivr.net/gh/pierreown/wsl-init@main/install.sh)" -- --cdn
```

## 使用

```bash
wsl-init enable                         # 启用
wsl-init disable                        # 禁用
wsl-init-boot                           # 手动前台启动 /sbin/init
wsl-init-enter [command [args...]]      # 进入 wsl-init 命名空间执行命令
```

**注意**

-   开启 wsl-init 后, 使用 Login Shell 会自动进入 wsl-init 命名空间。**默认只支持 root 用户，非 root 用户参考下一节**

    -   `wsl` ：从宿主机进入，默认就是 Login Shell。
    -   `bash -l` `wsl bash -l` `wsl --shell-type login` ：明确使用 Login Shell。

-   开启 wsl-init 后, 使用非 Login Shell 会进入原始命名空间。

    -   `wsl bash` `wsl --shell-type standard` ：明确使用非 Login Shell。
    -   `wsl wsl-init disable`: 遇到问题,可在直接禁用 wsl-init。

## 非 root 用户

因安全要求，脚本对 **非 root 用户** 有一定限制。非 root 用户想要有完整体验，请手动完成以下配置，并严格控制权限。

配置步骤

1. 创建特定用户组

    脚本使用固定的用户组 wsl-init 作为提权组。如果不希望使用默认组名，需要同步修改脚本中相关的组名检查逻辑。

    ```bash
    addgroup wsl-init # 或 groupadd wsl-init
    ```

2. 配置 sudo 权限

    编辑或新建文件 /etc/sudoers.d/wsl-init，确保允许 wsl-init 组的用户免密码执行 wsl-init-enter.sh。

    ```bash
    tee /etc/sudoers.d/wsl-init <<EOF
    %wsl-init ALL=(root) NOPASSWD: /opt/wsl-init/wsl-init-enter.sh
    %wsl-init ALL=(root) /usr/local/bin/wsl-init, /usr/local/bin/wsl-init-boot, /usr/local/bin/wsl-init-enter
    EOF

    # 不允许非 root 用户修改规则
    chmod 0440 /etc/sudoers.d/wsl-init
    ```

    **注意**

    - 此配置仅允许 wsl-init 组用户通过 sudo 免密执行 wsl-init-enter.sh 脚本，避免其他命令的误用。

    - 确保配置文件权限为只读，避免被非 root 用户修改。

3. 将用户添加到 wsl-init 组

    ```bash
    usermod -a -G wsl-init [用户名]
    ```

## 已测试系统

-   Ubuntu 20.04+
-   Debian 11+
-   Alpine 3.16+
-   Rocky 8+
-   OpenSUSE 15.4+
