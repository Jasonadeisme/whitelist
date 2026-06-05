# VPS 白名单

这是一个用于 Debian 系统的小型防火墙管理脚本。安装后可以通过 `whitelist` 命令进入菜单，只允许白名单中的 IP 连接到你的 VPS，未加入白名单的 IP 会被阻止建立新的入站连接。

[English README](README.md)

## 功能

- 增加白名单 IP 或 CIDR 网段
- 删除白名单条目
- 查看已有 IPv4 和 IPv6 白名单
- 阻止非白名单 IP 的新入站连接
- 保留已建立连接，降低当前 SSH 会话被断开的风险
- 使用 `systemd` 在重启后自动恢复防火墙规则

## 系统要求

- Debian 或基于 Debian 的 Linux 系统
- root 权限
- 如果尚未安装 `iptables`，系统需要可用的 `apt-get`
- 可选：如果需要 IPv6 过滤，需要 `ip6tables`

## 安装

把安装脚本上传到 VPS 后执行：

```bash
sudo bash install_whitelist.sh
```

如果你是通过 SSH 登录 VPS 执行安装，脚本会尝试自动把当前 SSH 来源 IP 加入白名单。如果无法检测到当前 IP，脚本会要求你先输入第一个白名单 IP，然后才会启用防火墙规则。

如果系统尚未安装 `iptables`，安装脚本会尝试通过 `apt-get` 自动安装。

## 使用

进入管理菜单：

```bash
sudo whitelist
```

菜单选项：

```text
1) Add whitelist IP
2) Delete whitelist IP
3) View whitelist IPs
4) Exit
```

可以输入单个 IP，也可以输入 CIDR 网段，例如：

```text
203.0.113.10
203.0.113.0/24
2001:db8::1
```

## 文件位置

- `/usr/local/bin/whitelist` - 命令快捷入口
- `/usr/local/sbin/vps-whitelist` - 安装后的管理脚本
- `/etc/vps-whitelist/ipv4.list` - IPv4 白名单
- `/etc/vps-whitelist/ipv6.list` - IPv6 白名单
- `/etc/systemd/system/vps-whitelist.service` - 开机恢复服务

## 注意

关闭 SSH 会话前，请确认你自己的公网 IP 已经在白名单中。否则可能会把自己锁在 VPS 外面，需要通过服务商控制台恢复访问。
