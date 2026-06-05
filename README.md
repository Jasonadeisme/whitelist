# VPS Whitelist

A small Debian firewall helper that only allows whitelisted IP addresses to connect to your VPS. After installation, run `whitelist` to open a simple menu for managing allowed IP addresses.

[中文说明](README.zh-CN.md)

## Features

- Add whitelist IP addresses or CIDR ranges
- Remove whitelist entries
- View existing IPv4 and IPv6 whitelist entries
- Block new inbound connections from non-whitelisted IP addresses
- Keep established connections active to reduce the risk of disconnecting the current SSH session
- Restore firewall rules automatically after reboot with `systemd`

## Requirements

- Debian-based Linux system
- Root privileges
- `apt-get` if `iptables` is not already installed
- Optional: `ip6tables` for IPv6 filtering

## Installation

Upload the installer to your VPS, then run:

```bash
sudo bash install_whitelist.sh
```

If you are already logged in over SSH, the installer attempts to add your current SSH client IP to the whitelist automatically. If it cannot detect the IP, it asks you to enter the first whitelist IP before enabling firewall rules.

If `iptables` is not installed, the installer attempts to install it automatically with `apt-get`.

## Usage

Open the management menu:

```bash
sudo whitelist
```

Menu options:

```text
1) Add whitelist IP
2) Delete whitelist IP
3) View whitelist IPs
4) Exit
```

You can enter either a single IP address or a CIDR range, for example:

```text
203.0.113.10
203.0.113.0/24
2001:db8::1
```

## Files

- `/usr/local/bin/whitelist` - command shortcut
- `/usr/local/sbin/vps-whitelist` - installed management script
- `/etc/vps-whitelist/ipv4.list` - IPv4 whitelist
- `/etc/vps-whitelist/ipv6.list` - IPv6 whitelist
- `/etc/systemd/system/vps-whitelist.service` - startup restore service

## Warning

Make sure your own public IP address is in the whitelist before closing your SSH session. Otherwise, you may lock yourself out of the VPS and need console access from your hosting provider to recover.
