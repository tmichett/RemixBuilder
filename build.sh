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
IMAGE_NAME=$(grep -A 10 "Container_Properties:" config.yml | grep "Image_Name:" | awk '{print $2}' | tr -d '"')

if [ -z "$FEDORA_VERSION" ]; then
    echo "Error: Could not extract Fedora_Version from config.yml"
    exit 1
fi

if [ -z "$IMAGE_NAME" ]; then
    echo "Error: Could not extract Image_Name from config.yml"
    exit 1
fi

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

