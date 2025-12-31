#!/bin/bash
set -e

# Script to run the Fedora Remix Builder container using Podman
# Reads SSH_Key_Location and Fedora_Remix_Location from config.yml
# Supports building different Remix variants (FedoraRemix, FedoraRemixCosmic, etc.)

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -k, --kickstart <name>   Specify kickstart to build (without .ks extension)"
    echo "                           Examples: FedoraRemix, FedoraRemixCosmic"
    echo "  -l, --list               List available kickstart files"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "If no kickstart is specified, you will be prompted to choose."
}

# Function to list available kickstarts
list_kickstarts() {
    local remix_location="$1"
    echo "Available Kickstart files:"
    echo ""
    for ks in "$remix_location"/Setup/Kickstarts/FedoraRemix*.ks; do
        if [ -f "$ks" ]; then
            basename "$ks" .ks
        fi
    done
}

# Function to show interactive menu
show_menu() {
    local remix_location="$1"
    local kickstarts=()
    local default_index=0
    local i=1
    
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║         🚀 Fedora Remix Builder - Kickstart Selection         ║"
    echo "╠═══════════════════════════════════════════════════════════════╣"
    
    for ks in "$remix_location"/Setup/Kickstarts/FedoraRemix*.ks; do
        if [ -f "$ks" ]; then
            local name=$(basename "$ks" .ks)
            kickstarts+=("$name")
            # Mark the default (FedoraRemix) with an asterisk
            if [ "$name" = "FedoraRemix" ]; then
                default_index=$((i-1))
                printf "║  %d) %-51s [DEFAULT] ║\n" "$i" "$name"
            else
                printf "║  %d) %-55s ║\n" "$i" "$name"
            fi
            ((i++))
        fi
    done
    
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""
    
    while true; do
        read -p "Select kickstart to build (1-${#kickstarts[@]}) [Enter=default]: " choice
        # If user just presses Enter, use default (FedoraRemix)
        if [ -z "$choice" ]; then
            SELECTED_KICKSTART="FedoraRemix"
            echo "Using default: FedoraRemix"
            break
        elif [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#kickstarts[@]}" ]; then
            SELECTED_KICKSTART="${kickstarts[$((choice-1))]}"
            break
        else
            echo "Invalid selection. Please enter a number between 1 and ${#kickstarts[@]}, or press Enter for default"
        fi
    done
}

# Parse command line arguments
SELECTED_KICKSTART=""
while [[ $# -gt 0 ]]; do
    case $1 in
        -k|--kickstart)
            SELECTED_KICKSTART="$2"
            shift 2
            ;;
        -l|--list)
            # We need to parse config first to get the remix location
            if [ ! -f "config.yml" ]; then
                echo "Error: config.yml not found in current directory"
                exit 1
            fi
            FEDORA_REMIX_LOCATION=$(grep -A 10 "Container_Properties:" config.yml | grep "Fedora_Remix_Location:" | awk '{print $2}' | tr -d '"')
            FEDORA_REMIX_LOCATION="${FEDORA_REMIX_LOCATION/#\~/$HOME}"
            list_kickstarts "$FEDORA_REMIX_LOCATION"
            exit 0
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Check if config.yml exists
if [ ! -f "config.yml" ]; then
    echo "Error: config.yml not found in current directory"
    exit 1
fi

# Extract values from config.yml
SSH_KEY_LOCATION=$(grep -A 10 "Container_Properties:" config.yml | grep "SSH_Key_Location:" | awk '{print $2}' | tr -d '"')
FEDORA_REMIX_LOCATION=$(grep -A 10 "Container_Properties:" config.yml | grep "Fedora_Remix_Location:" | awk '{print $2}' | tr -d '"')
IMAGE_NAME=$(grep -A 10 "Container_Properties:" config.yml | grep "Image_Name:" | awk '{print $2}' | tr -d '"')

if [ -z "$SSH_KEY_LOCATION" ] || [ -z "$FEDORA_REMIX_LOCATION" ] || [ -z "$IMAGE_NAME" ]; then
    echo "Error: Could not extract SSH_Key_Location, Fedora_Remix_Location, or Image_Name from config.yml"
    exit 1
fi

# Expand ~ in paths
SSH_KEY_LOCATION="${SSH_KEY_LOCATION/#\~/$HOME}"
FEDORA_REMIX_LOCATION="${FEDORA_REMIX_LOCATION/#\~/$HOME}"

# Get current working directory
CURRENT_DIR=$(pwd)

# Check if SSH key exists
if [ ! -f "$SSH_KEY_LOCATION" ]; then
    echo "Warning: SSH key not found at $SSH_KEY_LOCATION"
    echo "Container will still run, but SSH operations may fail"
fi

# Check if Fedora Remix location exists
if [ ! -d "$FEDORA_REMIX_LOCATION" ]; then
    echo "Error: Fedora Remix location does not exist: $FEDORA_REMIX_LOCATION"
    exit 1
fi

# If no kickstart specified, show interactive menu
if [ -z "$SELECTED_KICKSTART" ]; then
    show_menu "$FEDORA_REMIX_LOCATION"
fi

# Validate that the selected kickstart exists
if [ ! -f "$FEDORA_REMIX_LOCATION/Setup/Kickstarts/${SELECTED_KICKSTART}.ks" ]; then
    echo "Error: Kickstart file not found: ${SELECTED_KICKSTART}.ks"
    echo "Available kickstarts:"
    list_kickstarts "$FEDORA_REMIX_LOCATION"
    exit 1
fi

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║              🚀 Fedora Remix Builder Configuration            ║"
echo "╠═══════════════════════════════════════════════════════════════╣"
printf "║  %-60s ║\n" "Image: $IMAGE_NAME"
printf "║  %-60s ║\n" "Kickstart: ${SELECTED_KICKSTART}.ks"
printf "║  %-60s ║\n" "Output ISO: ${SELECTED_KICKSTART}.iso"
printf "║  %-60s ║\n" "SSH Key: $SSH_KEY_LOCATION"
printf "║  %-60s ║\n" "Fedora Remix: $FEDORA_REMIX_LOCATION"
printf "║  %-60s ║\n" "Workspace: $CURRENT_DIR"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Container name
CONTAINER_NAME="remix-builder"

# Remove existing container with the same name if it exists
if podman ps -a --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
    echo "Removing existing container: $CONTAINER_NAME"
    podman rm -f "$CONTAINER_NAME" 2>/dev/null || true
fi

# Run the container with systemd support and loop device access
# Pass the selected kickstart as an environment variable
podman run --rm -it \
    --name "$CONTAINER_NAME" \
    --systemd=always \
    --privileged \
    --device-cgroup-rule='b 7:* rmw' \
    -e "REMIX_KICKSTART=$SELECTED_KICKSTART" \
    -v "$SSH_KEY_LOCATION:/root/github_id:ro" \
    -v "$FEDORA_REMIX_LOCATION:/livecd-creator:rw" \
    -v "$CURRENT_DIR:/root/workspace:rw" \
    "$IMAGE_NAME"

