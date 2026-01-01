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
FEDORA_VERSION=$(grep -A 10 "Container_Properties:" config.yml | grep "Fedora_Version:" | awk '{print $2}' | tr -d '"')
GITHUB_REGISTRY_OWNER=$(grep -A 10 "Container_Properties:" config.yml | grep "GitHub_Registry_Owner:" | awk '{print $2}' | tr -d '"')

if [ -z "$FEDORA_VERSION" ]; then
    echo "Error: Could not extract Fedora_Version from config.yml"
    exit 1
fi

if [ -z "$GITHUB_REGISTRY_OWNER" ]; then
    echo "Error: Could not extract GitHub_Registry_Owner from config.yml"
    exit 1
fi

# Construct Image_Name dynamically from GitHub_Registry_Owner and Fedora_Version
IMAGE_NAME="ghcr.io/${GITHUB_REGISTRY_OWNER}/fedora-remix-builder:${FEDORA_VERSION}"

echo "Building container with Fedora version: $FEDORA_VERSION"
echo "Image name: $IMAGE_NAME"

# Build the container image with the full name from config.yml
podman build \
    --build-arg FEDORA_VERSION="$FEDORA_VERSION" \
    -t "$IMAGE_NAME" \
    -f Containerfile .

echo ""
echo "Container build completed successfully!"
echo "Image: $IMAGE_NAME"
echo "Push with: ./push.sh"

