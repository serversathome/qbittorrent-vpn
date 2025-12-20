# GitHub Workflows

This directory contains automated workflows for maintaining the qBittorrent-WireGuard container.

## Workflows

### 1. docker-rebuild.yml
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

### 2. update-truenas-catalog.yml
**Purpose:** Automatically update the TrueNAS app catalog when the Docker image is updated.

**Triggers:**
- After successful completion of `docker-rebuild.yml`
- Manual trigger via workflow_dispatch

**Process:**
1. Extracts the qBittorrent version from `linuxserver/qbittorrent:latest` image labels
2. Clones the forked TrueNAS apps repository (`serversathome/apps`)
3. Updates the `version` field in `ix-dev/community/qbittorrent-wireguard/app.yaml`
4. Creates a Pull Request to the upstream TrueNAS apps repository
5. PR includes version change details and is automatically labeled

**Requirements:**
- Repository secret `APPS_REPO_TOKEN` must be configured with a GitHub Personal Access Token that has repo access

## Setup Instructions

### Required Secrets

Add these secrets to your repository at https://github.com/serversathome/qbittorrent-wireguard/settings/secrets/actions:

1. **DOCKERHUB_USERNAME**: Your Docker Hub username
2. **DOCKERHUB_TOKEN**: Your Docker Hub access token
3. **APPS_REPO_TOKEN**: GitHub Personal Access Token with `repo` scope for updating the TrueNAS apps fork

### Creating APPS_REPO_TOKEN

1. Go to https://github.com/settings/tokens/new
2. Set a descriptive name (e.g., "TrueNAS Catalog Updater")
3. Select scopes:
   - `repo` (Full control of private repositories)
4. Click "Generate token"
5. Copy the token immediately (you won't see it again!)
6. Add it to your repository secrets as `APPS_REPO_TOKEN`

## Workflow Chain

```
Daily Check (06:00 UTC)
        ↓
Base Image Updated?
        ↓
   docker-rebuild.yml
        ↓
Build & Push New Image
        ↓
update-truenas-catalog.yml
        ↓
Extract Version from Base Image
        ↓
Update TrueNAS App Version
        ↓
Create PR to TrueNAS Apps
        ↓
Users Get Update Notification
```

## Version Matching

The TrueNAS app version automatically matches the qBittorrent version from the linuxserver.io base image:
- Base image: `linuxserver/qbittorrent:latest` (e.g., version 5.0.2)
- TrueNAS app version: `5.0.2`

This ensures users always know which version of qBittorrent they're running.

## Troubleshooting

### Workflow fails with "Could not extract version"
- The linuxserver.io image may have changed their label format
- Check the image labels manually: `docker inspect linuxserver/qbittorrent:latest`

### PR creation fails
- Ensure `APPS_REPO_TOKEN` is set correctly
- Verify the token has `repo` scope
- Check that the apps repository exists at `serversathome/apps`

### No PR created but workflow succeeds
- The version may already be up to date
- Check the workflow logs for "Version already up to date" message
