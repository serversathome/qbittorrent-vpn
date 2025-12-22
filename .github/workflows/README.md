# GitHub Workflows

This directory contains automated workflows for maintaining the qBittorrent-WireGuard container.

## Workflows

### docker-rebuild.yml
**Purpose:** Automatically rebuild and push the Docker image when the base image is updated.

**Triggers:**
- Daily at 06:00 UTC (scheduled)
- Manual trigger via workflow_dispatch
- Push to main branch or version tags

**Process:**
1. Fetches the digest of `linuxserver/qbittorrent:latest`
2. Compares with the last known digest (stored in `.base_digest`)
3. If changed, builds and pushes new image to `serversathome/qbittorrent-wireguard:latest`
4. Updates the digest file and commits it
