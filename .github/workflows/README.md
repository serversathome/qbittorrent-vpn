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

## Setup Instructions

### Required Secrets

Add these secrets to your repository at https://github.com/serversathome/qbittorrent-wireguard/settings/secrets/actions:

1. **DOCKERHUB_USERNAME**: Your Docker Hub username
2. **DOCKERHUB_TOKEN**: Your Docker Hub access token

### Creating Docker Hub Token

1. Go to https://hub.docker.com/settings/security
2. Click "New Access Token"
3. Set a descriptive name (e.g., "GitHub Actions")
4. Set permissions to "Read & Write"
5. Click "Generate"
6. Copy the token immediately (you won't see it again!)
7. Add it to your repository secrets as `DOCKERHUB_TOKEN`

## Workflow Operation

```
Daily Check (06:00 UTC)
        ↓
Base Image Updated?
        ↓
   docker-rebuild.yml
        ↓
Build & Push New Image
        ↓
Image Available on Docker Hub
```

## Troubleshooting

### Workflow fails with "login failed"
- Ensure `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` are set correctly
- Verify the token has Read & Write permissions
- Check if the token has expired

### No image pushed but workflow succeeds
- The base image digest may not have changed
- Check the workflow logs for "update_needed=false" message
