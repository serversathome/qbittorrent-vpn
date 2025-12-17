# qBittorrent-VPN (serversatho.me)

A lightweight, leak-proof qBittorrent container with built-in WireGuard support.

This image merges **WireGuard** and **qBittorrent** into a single container:
- Starts a WireGuard tunnel from your supplied `wg0.conf`
- Automatically detects network interfaces
- Adds LAN / Tailscale / NetBird bypass routes
- Launches qBittorrent only after the VPN is active
- Monitors the tunnel and pauses qBittorrent if the VPN drops (kill switch)

---

## 🔧 Usage

```yaml
services:
  qbittorrent-vpn:
    image: registry.serversatho.me/qbittorrent-vpn:latest
    container_name: qbittorrent-vpn
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun
    sysctls:
      - net.ipv4.conf.all.src_valid_mark=1
    volumes:
      - ./config:/config         # place wg0.conf here
      - /media:/media            # your downloads
    environment:
      - PUID=568
      - PGID=568
      - WEBUI_PORT=8080
    ports:
      - "8080:8080"
    restart: unless-stopped
