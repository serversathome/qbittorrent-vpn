#!/usr/bin/env bash
set -e

WG_CONF="${WG_CONF:-/config/wg0.conf}"
WG_INTERFACE="wg0"
CHECK_HOST="1.1.1.1"
QBIT_CONF="/config/qBittorrent/qBittorrent.conf"
WEBUI_PORT="${WEBUI_PORT:-8080}"

echo "[INFO] Starting WireGuard VPN setup..."

# Verify config exists
if [ ! -f "$WG_CONF" ]; then
  echo "[ERROR] WireGuard config not found at $WG_CONF"
  exit 1
fi

# Create modified WireGuard config with Table = off to avoid sysctl issues
WG_TEMP="/tmp/wg0-nodns.conf"
{
  grep -v "^DNS" "$WG_CONF"
  echo ""
  echo "Table = off"
} > "$WG_TEMP"

# Set proper permissions
chmod 600 "$WG_TEMP"

# Extract DNS servers if present in original config
DNS_SERVERS=$(grep "^DNS" "$WG_CONF" | head -1 | cut -d= -f2 | tr -d ' ' || echo "1.1.1.1,8.8.8.8")

echo "[INFO] Configuring DNS: $DNS_SERVERS"

# Set DNS manually
echo "# WireGuard DNS" > /etc/resolv.conf
echo "$DNS_SERVERS" | tr ',' '\n' | while read -r dns; do
  [ -n "$dns" ] && echo "nameserver $dns" >> /etc/resolv.conf
done

# Bring up WireGuard interface
echo "[INFO] Bringing up WireGuard interface..."
wg-quick up "$WG_TEMP" || {
  echo "[ERROR] Failed to bring up WireGuard interface."
  cat "$WG_TEMP"
  rm -f "$WG_TEMP"
  exit 1
}

# Wait for interface to be ready
sleep 2

# Verify interface is up
if ! ip link show "$WG_INTERFACE" >/dev/null 2>&1; then
  echo "[ERROR] WireGuard interface $WG_INTERFACE not found after startup"
  wg-quick down "$WG_INTERFACE" 2>/dev/null || true
  rm -f "$WG_TEMP"
  exit 1
fi

echo "[INFO] WireGuard interface is up:"
wg show "$WG_INTERFACE"

# Set up routing manually since we disabled automatic routing with Table = off
echo "[INFO] Setting up VPN routing..."

# Get the default gateway for the physical interface (to reach VPN endpoint)
DEFAULT_GW=$(ip route | grep default | awk '{print $3}' | head -1)
VPN_ENDPOINT=$(grep "^Endpoint" "$WG_CONF" | head -1 | cut -d= -f2 | tr -d ' ' | cut -d: -f1)

if [ -n "$VPN_ENDPOINT" ] && [ -n "$DEFAULT_GW" ]; then
  # Add route for VPN endpoint through default gateway
  ip route add "$VPN_ENDPOINT/32" via "$DEFAULT_GW" 2>/dev/null || true
fi

# Route all other traffic through VPN
ip route add default dev "$WG_INTERFACE" metric 100

echo "[INFO] Setting up killswitch firewall..."

# Flush old rules
iptables -F
iptables -t nat -F
iptables -X

# Default policies
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

# Allow loopback
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Allow established/related connections
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Allow local network access (for WebUI and local services)
iptables -A INPUT -s 10.0.0.0/8 -j ACCEPT
iptables -A INPUT -s 172.16.0.0/12 -j ACCEPT
iptables -A INPUT -s 192.168.0.0/16 -j ACCEPT

iptables -A OUTPUT -d 10.0.0.0/8 -j ACCEPT
iptables -A OUTPUT -d 172.16.0.0/12 -j ACCEPT
iptables -A OUTPUT -d 192.168.0.0/16 -j ACCEPT

# Allow WebUI port from local networks
iptables -A INPUT -p tcp --dport "$WEBUI_PORT" -s 10.0.0.0/8 -j ACCEPT
iptables -A INPUT -p tcp --dport "$WEBUI_PORT" -s 172.16.0.0/12 -j ACCEPT
iptables -A INPUT -p tcp --dport "$WEBUI_PORT" -s 192.168.0.0/16 -j ACCEPT

# Allow output to VPN endpoint (so WireGuard can connect)
if [ -n "$VPN_ENDPOINT" ]; then
  iptables -A OUTPUT -d "$VPN_ENDPOINT" -j ACCEPT
fi

# Allow all traffic through VPN interface
iptables -A INPUT -i "$WG_INTERFACE" -j ACCEPT
iptables -A OUTPUT -o "$WG_INTERFACE" -j ACCEPT

# Allow DNS queries
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT

echo "[INFO] Firewall rules applied (killswitch active)."

# Check VPN connectivity
echo "[INFO] Testing VPN connectivity..."
if ! ping -c 3 -W 5 "$CHECK_HOST" >/dev/null 2>&1; then
  echo "[ERROR] VPN appears down — cannot reach $CHECK_HOST."
  echo "[DEBUG] Interface status:"
  ip addr show "$WG_INTERFACE"
  echo "[DEBUG] Routing table:"
  ip route show
  echo "[DEBUG] WireGuard status:"
  wg show "$WG_INTERFACE"
  wg-quick down "$WG_INTERFACE" 2>/dev/null || true
  rm -f "$WG_TEMP"
  exit 1
fi

echo "[INFO] VPN connectivity verified ✓"

# Clean up temp file
rm -f "$WG_TEMP"

# Configure qBittorrent port forwarding if set
if [ -n "$VPN_PORT_FORWARD" ]; then
  echo "[INFO] Setting qBittorrent listen port to $VPN_PORT_FORWARD"
  mkdir -p "$(dirname "$QBIT_CONF")"

  if [ -f "$QBIT_CONF" ]; then
    sed -i '/Connection\\PortRangeMin=/d' "$QBIT_CONF"
    sed -i "/^\[Preferences\]/a Connection\\\\PortRangeMin=$VPN_PORT_FORWARD" "$QBIT_CONF"
  else
    cat > "$QBIT_CONF" << EOF
[Preferences]
Connection\\PortRangeMin=$VPN_PORT_FORWARD
EOF
  fi

  iptables -I INPUT -i "$WG_INTERFACE" -p tcp --dport "$VPN_PORT_FORWARD" -j ACCEPT
  iptables -I INPUT -i "$WG_INTERFACE" -p udp --dport "$VPN_PORT_FORWARD" -j ACCEPT
  
  echo "[INFO] Port forwarding configured for port $VPN_PORT_FORWARD"
fi

echo "[INFO] Starting VPN watchdog in background..."

# Cleanup function
cleanup() {
  echo "[INFO] Shutting down..."
  pkill -15 qbittorrent-nox 2>/dev/null || true
  sleep 2
  pkill -9 qbittorrent-nox 2>/dev/null || true
  wg-quick down "$WG_INTERFACE" 2>/dev/null || true
  exit 0
}

trap cleanup SIGTERM SIGINT

# VPN watchdog
(
  while sleep 60; do
    if ! ping -c 1 -W 3 "$CHECK_HOST" >/dev/null 2>&1; then
      echo "[WARN] Lost VPN connectivity — shutting down."
      pkill -9 qbittorrent-nox || true
      wg-quick down "$WG_INTERFACE" 2>/dev/null || true
      exit 1
    fi
  done
) &

echo "[INFO] Starting qBittorrent WebUI on port $WEBUI_PORT..."
chown -R abc:abc /config 2>/dev/null || true

exec s6-setuidgid abc qbittorrent-nox --webui-port="$WEBUI_PORT"
