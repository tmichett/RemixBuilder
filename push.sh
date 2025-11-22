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
IMAGE_NAME=$(grep -A 10 "Container_Properties:" config.yml | grep "Image_Name:" | awk '{print $2}' | tr -d '"')

if [ -z "$IMAGE_NAME" ]; then
    echo "Error: Could not extract Image_Name from config.yml"
    exit 1
fi

# Check if the image name contains ghcr.io (GitHub Container Registry)
if [[ "$IMAGE_NAME" != ghcr.io/* ]]; then
    echo "Error: Image_Name in config.yml does not appear to be a GitHub Container Registry image"
    echo "Expected format: ghcr.io/owner/image-name:tag"
    echo "Found: $IMAGE_NAME"
    exit 1
fi

# Check if local image exists
if ! podman images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${IMAGE_NAME}$"; then
    echo "Error: Local image $IMAGE_NAME not found"
    echo "Available images:"
    podman images | head -10
    echo ""
    echo "Please build the image first with: ./build.sh"
    exit 1
fi

echo "Found local image: $IMAGE_NAME"

# Login to GitHub Container Registry
echo "Logging in to GitHub Container Registry..."
echo "You will need a GitHub Personal Access Token (PAT) with 'write:packages' permission"
echo "Create one at: https://github.com/settings/tokens"
echo ""
podman login ghcr.io

# Push the image
echo ""
echo "Pushing image to GitHub Container Registry: $IMAGE_NAME"
podman push "$IMAGE_NAME"

echo ""
echo "Image pushed successfully!"
echo "Image available at: $IMAGE_NAME"
echo ""
echo "To pull this image on another machine:"
echo "  podman pull $IMAGE_NAME"

