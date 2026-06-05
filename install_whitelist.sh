#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root: sudo bash $0"
  exit 1
fi

if ! command -v iptables >/dev/null 2>&1; then
  echo "iptables is required. Install it first: apt update && apt install -y iptables"
  exit 1
fi

install -d /usr/local/sbin /usr/local/bin /etc/vps-whitelist

cat >/usr/local/sbin/vps-whitelist <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail

IPV4_FILE="/etc/vps-whitelist/ipv4.list"
IPV6_FILE="/etc/vps-whitelist/ipv6.list"
CHAIN4="VPS_WHITELIST"
CHAIN6="VPS_WHITELIST6"

need_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo "Please run with root privileges: sudo whitelist"
    exit 1
  fi
}

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

is_ipv4() {
  [[ "$1" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}(/[0-9]{1,2})?$ ]] || return 1
  local ip="${1%%/*}" cidr=""
  [[ "$1" == */* ]] && cidr="${1#*/}"
  IFS='.' read -r a b c d <<<"$ip"
  for n in "$a" "$b" "$c" "$d"; do
    [[ "$n" =~ ^[0-9]+$ ]] && (( n >= 0 && n <= 255 )) || return 1
  done
  [[ -z "$cidr" || ( "$cidr" =~ ^[0-9]+$ && "$cidr" -ge 0 && "$cidr" -le 32 ) ]]
}

is_ipv6() {
  [[ "$1" == *:* ]] || return 1
  if has_cmd python3; then
    python3 - "$1" >/dev/null 2>&1 <<'PY'
import ipaddress, sys
ipaddress.ip_network(sys.argv[1], strict=False)
PY
  else
    [[ "$1" =~ ^[0-9A-Fa-f:]+(/[0-9]{1,3})?$ ]]
  fi
}

detect_family() {
  if is_ipv4 "$1"; then
    echo 4
  elif is_ipv6 "$1"; then
    echo 6
  else
    echo 0
  fi
}

ensure_files() {
  touch "$IPV4_FILE" "$IPV6_FILE"
  chmod 600 "$IPV4_FILE" "$IPV6_FILE"
}

ipt6_available() {
  has_cmd ip6tables
}

ensure_rules_v4() {
  iptables -N "$CHAIN4" 2>/dev/null || true
  iptables -F "$CHAIN4"
  iptables -A "$CHAIN4" -i lo -j RETURN
  iptables -A "$CHAIN4" -m conntrack --ctstate ESTABLISHED,RELATED -j RETURN

  while IFS= read -r ip; do
    [[ -n "$ip" ]] && iptables -A "$CHAIN4" -s "$ip" -j RETURN
  done < "$IPV4_FILE"

  iptables -A "$CHAIN4" -j DROP
  iptables -C INPUT -j "$CHAIN4" 2>/dev/null || iptables -I INPUT 1 -j "$CHAIN4"
}

ensure_rules_v6() {
  ipt6_available || return 0
  ip6tables -N "$CHAIN6" 2>/dev/null || true
  ip6tables -F "$CHAIN6"
  ip6tables -A "$CHAIN6" -i lo -j RETURN
  ip6tables -A "$CHAIN6" -m conntrack --ctstate ESTABLISHED,RELATED -j RETURN

  while IFS= read -r ip; do
    [[ -n "$ip" ]] && ip6tables -A "$CHAIN6" -s "$ip" -j RETURN
  done < "$IPV6_FILE"

  ip6tables -A "$CHAIN6" -j DROP
  ip6tables -C INPUT -j "$CHAIN6" 2>/dev/null || ip6tables -I INPUT 1 -j "$CHAIN6"
}

apply_rules() {
  ensure_files
  ensure_rules_v4
  ensure_rules_v6
}

normalize_list() {
  local file="$1"
  sort -u "$file" -o "$file"
}

add_ip() {
  read -r -p "Enter IP or CIDR to whitelist: " ip
  ip="${ip//[[:space:]]/}"
  add_ip_value "$ip"
  apply_rules
  echo "Added: $ip"
}

add_ip_value() {
  local ip="$1"
  local family
  family="$(detect_family "$ip")"

  if [[ "$family" == "0" ]]; then
    echo "Invalid IP/CIDR: $ip"
    return 1
  fi

  if [[ "$family" == "4" ]]; then
    grep -Fxq "$ip" "$IPV4_FILE" 2>/dev/null || echo "$ip" >> "$IPV4_FILE"
    normalize_list "$IPV4_FILE"
  else
    grep -Fxq "$ip" "$IPV6_FILE" 2>/dev/null || echo "$ip" >> "$IPV6_FILE"
    normalize_list "$IPV6_FILE"
  fi
}

delete_ip() {
  read -r -p "Enter IP or CIDR to remove: " ip
  ip="${ip//[[:space:]]/}"
  local family
  family="$(detect_family "$ip")"

  if [[ "$family" == "4" ]]; then
    grep -Fxv "$ip" "$IPV4_FILE" > "${IPV4_FILE}.tmp" || true
    mv "${IPV4_FILE}.tmp" "$IPV4_FILE"
  elif [[ "$family" == "6" ]]; then
    grep -Fxv "$ip" "$IPV6_FILE" > "${IPV6_FILE}.tmp" || true
    mv "${IPV6_FILE}.tmp" "$IPV6_FILE"
  else
    echo "Invalid IP/CIDR: $ip"
    return
  fi

  chmod 600 "$IPV4_FILE" "$IPV6_FILE"
  apply_rules
  echo "Removed if it existed: $ip"
}

list_ips() {
  echo
  echo "IPv4 whitelist:"
  if [[ -s "$IPV4_FILE" ]]; then
    nl -ba "$IPV4_FILE"
  else
    echo "  (empty)"
  fi

  echo
  echo "IPv6 whitelist:"
  if [[ -s "$IPV6_FILE" ]]; then
    nl -ba "$IPV6_FILE"
  else
    echo "  (empty)"
  fi
  echo
}

main_menu() {
  need_root
  ensure_files
  apply_rules

  while true; do
    echo "========== VPS IP Whitelist =========="
    echo "1) Add whitelist IP"
    echo "2) Delete whitelist IP"
    echo "3) View whitelist IPs"
    echo "4) Exit"
    read -r -p "Choose an option [1-4]: " choice

    case "$choice" in
      1) add_ip ;;
      2) delete_ip ;;
      3) list_ips ;;
      4) exit 0 ;;
      *) echo "Invalid option." ;;
    esac
    echo
  done
}

case "${1:-menu}" in
  menu) main_menu ;;
  apply) need_root; apply_rules ;;
  add) need_root; ensure_files; add_ip_value "${2:-}"; apply_rules ;;
  *) echo "Usage: whitelist [menu|apply|add IP_OR_CIDR]"; exit 1 ;;
esac
SCRIPT

chmod 700 /usr/local/sbin/vps-whitelist
ln -sf /usr/local/sbin/vps-whitelist /usr/local/bin/whitelist

touch /etc/vps-whitelist/ipv4.list /etc/vps-whitelist/ipv6.list
chmod 600 /etc/vps-whitelist/ipv4.list /etc/vps-whitelist/ipv6.list

if [[ -n "${SSH_CLIENT:-}" ]]; then
  current_ip="${SSH_CLIENT%% *}"
  if [[ "$current_ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    grep -Fxq "$current_ip" /etc/vps-whitelist/ipv4.list || echo "$current_ip" >> /etc/vps-whitelist/ipv4.list
    echo "Added current SSH client IPv4 to whitelist: $current_ip"
  elif [[ "$current_ip" == *:* ]]; then
    grep -Fxq "$current_ip" /etc/vps-whitelist/ipv6.list || echo "$current_ip" >> /etc/vps-whitelist/ipv6.list
    echo "Added current SSH client IPv6 to whitelist: $current_ip"
  fi
fi

if [[ ! -s /etc/vps-whitelist/ipv4.list && ! -s /etc/vps-whitelist/ipv6.list ]]; then
  echo "No current SSH client IP was detected."
  echo "You must add at least one whitelist IP before firewall rules are enabled."
  read -r -p "Enter your first whitelist IP/CIDR: " first_ip
  first_ip="${first_ip//[[:space:]]/}"
  if [[ -z "$first_ip" ]]; then
    echo "Aborted. No firewall rules were enabled."
    exit 1
  fi
  /usr/local/sbin/vps-whitelist add "$first_ip"
  echo "Added first whitelist IP: $first_ip"
fi

cat >/etc/systemd/system/vps-whitelist.service <<'SERVICE'
[Unit]
Description=Apply VPS IP whitelist firewall rules
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/whitelist apply
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable vps-whitelist.service >/dev/null
/usr/local/bin/whitelist apply

echo
echo "Installed successfully."
echo "Run the menu with: sudo whitelist"
echo "Whitelist files:"
echo "  /etc/vps-whitelist/ipv4.list"
echo "  /etc/vps-whitelist/ipv6.list"
