#!/bin/bash
set -e

# Script to push the Fedora Remix Builder container to GitHub Container Registry
# Reads GitHub registry info from config.yml

# Check if config.yml exists
if [ ! -f "config.yml" ]; then
    echo "Error: config.yml not found in current directory"
    exit 1
fi

# Extract values from config.yml
GITHUB_OWNER=$(grep -A 5 "Container_Properties:" config.yml | grep "GitHub_Registry_Owner:" | awk '{print $2}' | tr -d '"')
IMAGE_NAME=$(grep -A 5 "Container_Properties:" config.yml | grep "Image_Name:" | awk '{print $2}' | tr -d '"')

# Set defaults if not specified
IMAGE_NAME="${IMAGE_NAME:-fedora-remix-builder}"

# Check if GitHub owner is configured
if [ -z "$GITHUB_OWNER" ] || [ "$GITHUB_OWNER" = "YOUR_GITHUB_USERNAME" ]; then
    echo "Error: GitHub_Registry_Owner not configured in config.yml"
    echo "Please set GitHub_Registry_Owner to your GitHub username or organization"
    exit 1
fi

# Build GitHub registry image name
GHCR_IMAGE="ghcr.io/${GITHUB_OWNER}/${IMAGE_NAME}:latest"
LOCAL_IMAGE="${IMAGE_NAME}:latest"
LOCALHOST_IMAGE="localhost/${IMAGE_NAME}:latest"

# Check if local image exists (try both with and without localhost prefix)
LOCAL_IMAGE_FOUND=""
if podman images --format "{{.Repository}}:{{.Tag}}" | grep -qE "^(localhost/)?${IMAGE_NAME}:latest$"; then
    # Find the actual image name
    ACTUAL_IMAGE=$(podman images --format "{{.Repository}}:{{.Tag}}" | grep -E "^(localhost/)?${IMAGE_NAME}:latest$" | head -1)
    LOCAL_IMAGE_FOUND="$ACTUAL_IMAGE"
    echo "Found local image: $ACTUAL_IMAGE"
elif podman images | grep -q "${IMAGE_NAME}.*latest"; then
    # Fallback: find by name pattern
    ACTUAL_IMAGE=$(podman images --format "{{.Repository}}:{{.Tag}}" | grep "${IMAGE_NAME}" | grep "latest" | head -1)
    LOCAL_IMAGE_FOUND="$ACTUAL_IMAGE"
    echo "Found local image: $ACTUAL_IMAGE"
fi

if [ -z "$LOCAL_IMAGE_FOUND" ]; then
    echo "Error: Local image $IMAGE_NAME:latest not found"
    echo "Available images:"
    podman images | grep -E "REPOSITORY|${IMAGE_NAME}" || podman images | head -5
    echo ""
    echo "Please build the image first with: ./build.sh"
    exit 1
fi

# Tag the image if not already tagged
if ! podman images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${GHCR_IMAGE}$"; then
    echo "Tagging image $LOCAL_IMAGE_FOUND as: $GHCR_IMAGE"
    podman tag "$LOCAL_IMAGE_FOUND" "$GHCR_IMAGE"
else
    echo "Image already tagged as: $GHCR_IMAGE"
fi

# Login to GitHub Container Registry
echo "Logging in to GitHub Container Registry..."
echo "You will need a GitHub Personal Access Token (PAT) with 'write:packages' permission"
echo "Create one at: https://github.com/settings/tokens"
echo ""
podman login ghcr.io

# Push the image
echo ""
echo "Pushing image to GitHub Container Registry: $GHCR_IMAGE"
podman push "$GHCR_IMAGE"

echo ""
echo "Image pushed successfully!"
echo "Image available at: $GHCR_IMAGE"
echo ""
echo "To pull this image on another machine:"
echo "  podman pull $GHCR_IMAGE"

