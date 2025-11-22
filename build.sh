#!/bin/bash
set -e

# Script to build the Fedora Remix Builder container using Podman
# Reads Fedora_Version and GitHub registry info from config.yml

# Check if config.yml exists
if [ ! -f "config.yml" ]; then
    echo "Error: config.yml not found in current directory"
    exit 1
fi

# Extract values from config.yml
FEDORA_VERSION=$(grep -A 5 "Container_Properties:" config.yml | grep "Fedora_Version:" | awk '{print $2}' | tr -d '"')
GITHUB_OWNER=$(grep -A 5 "Container_Properties:" config.yml | grep "GitHub_Registry_Owner:" | awk '{print $2}' | tr -d '"')
IMAGE_NAME=$(grep -A 5 "Container_Properties:" config.yml | grep "Image_Name:" | awk '{print $2}' | tr -d '"')

if [ -z "$FEDORA_VERSION" ]; then
    echo "Error: Could not extract Fedora_Version from config.yml"
    exit 1
fi

# Set defaults if not specified
IMAGE_NAME="${IMAGE_NAME:-fedora-remix-builder}"

# Build local image name
LOCAL_IMAGE="${IMAGE_NAME}:latest"

# Build GitHub registry image name if owner is specified
if [ -n "$GITHUB_OWNER" ] && [ "$GITHUB_OWNER" != "YOUR_GITHUB_USERNAME" ]; then
    GHCR_IMAGE="ghcr.io/${GITHUB_OWNER}/${IMAGE_NAME}:latest"
    echo "Building container with Fedora version: $FEDORA_VERSION"
    echo "Will tag as: $LOCAL_IMAGE and $GHCR_IMAGE"
else
    GHCR_IMAGE=""
    echo "Building container with Fedora version: $FEDORA_VERSION"
    echo "Will tag as: $LOCAL_IMAGE"
    echo "Note: Set GitHub_Registry_Owner in config.yml to enable GitHub Container Registry tagging"
fi

# Build the container image
podman build \
    --build-arg FEDORA_VERSION="$FEDORA_VERSION" \
    -t "$LOCAL_IMAGE" \
    -f Containerfile .

# Tag for GitHub Container Registry if owner is specified
if [ -n "$GHCR_IMAGE" ]; then
    podman tag "$LOCAL_IMAGE" "$GHCR_IMAGE"
    echo "Tagged image as: $GHCR_IMAGE"
fi

echo ""
echo "Container build completed successfully!"
echo "Local image: $LOCAL_IMAGE"
if [ -n "$GHCR_IMAGE" ]; then
    echo "GitHub registry image: $GHCR_IMAGE"
    echo "Push with: ./push.sh"
fi

