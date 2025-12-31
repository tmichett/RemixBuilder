#!/bin/bash
set -e

# Ensure unbuffered output so it appears immediately
export PYTHONUNBUFFERED=1

# Set locale environment variables
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export LANGUAGE=en_US.UTF-8

# Log all output to a file for later viewing
exec > >(tee -a /tmp/entrypoint.log) 2>&1

# Configure DNF for faster downloads
echo "Configuring DNF for optimal download performance..."
if ! grep -q "max_parallel_downloads" /etc/dnf/dnf.conf 2>/dev/null; then
    echo "max_parallel_downloads=10" >> /etc/dnf/dnf.conf
fi
if ! grep -q "fastestmirror" /etc/dnf/dnf.conf 2>/dev/null; then
    echo "fastestmirror=True" >> /etc/dnf/dnf.conf
fi
echo "DNF configured: max_parallel_downloads=10, fastestmirror=True"

# Get the kickstart selection from environment variable (default to FedoraRemix)
# Debug: Show all REMIX-related environment variables
echo "DEBUG: Checking for REMIX_KICKSTART..."
echo "DEBUG: REMIX_KICKSTART from env = '${REMIX_KICKSTART}'"
env | grep -i remix || echo "DEBUG: No REMIX variables in environment"

# Also check if it was passed via a file (fallback for systemd mode)
if [ -z "$REMIX_KICKSTART" ] && [ -f /tmp/remix_kickstart.txt ]; then
    REMIX_KICKSTART=$(cat /tmp/remix_kickstart.txt)
    echo "DEBUG: Read REMIX_KICKSTART from file: ${REMIX_KICKSTART}"
fi

REMIX_KICKSTART="${REMIX_KICKSTART:-FedoraRemix}"
echo "Selected Kickstart: ${REMIX_KICKSTART}"
echo "Output ISO will be: ${REMIX_KICKSTART}.iso"

# Write to file for the build script to read (backup method)
echo "$REMIX_KICKSTART" > /tmp/remix_kickstart.txt

# Wait for workspace directory to be available (mounts may not be ready immediately)
echo "Waiting for workspace directory to be available..."
for i in {1..30}; do
    if [ -d "/root/workspace" ] && [ "$(ls -A /root/workspace 2>/dev/null)" ]; then
        break
    fi
    sleep 1
done

if [ ! -d "/root/workspace" ]; then
    echo "Error: /root/workspace directory not found"
    exit 1
fi

# Change to workspace/Setup directory
echo "Changing to workspace/Setup directory: ~/workspace/Setup"
cd ~/workspace/Setup

# Verify files exist before running
if [ ! -f "Prepare_Web_Files.py" ]; then
    echo "Error: Prepare_Web_Files.py not found in /root/workspace/Setup"
    echo "Contents of /root/workspace/Setup:"
    ls -la /root/workspace/Setup
    exit 1
fi

if [ ! -f "Prepare_Fedora_Remix_Build.py" ]; then
    echo "Error: Prepare_Fedora_Remix_Build.py not found in /root/workspace/Setup"
    echo "Contents of /root/workspace/Setup:"
    ls -la /root/workspace/Setup
    exit 1
fi

# Run commands with echo output
echo "Running: python3 Prepare_Web_Files.py"
python3 Prepare_Web_Files.py

echo "Running: python3 Prepare_Fedora_Remix_Build.py"
python3 Prepare_Fedora_Remix_Build.py

# Change to FedoraRemix directory
echo "Changing to FedoraRemix directory: /livecd-creator/FedoraRemix"
cd /livecd-creator/FedoraRemix

if [ ! -f "Enhanced_Remix_Build_Script.sh" ]; then
    echo "Error: Enhanced_Remix_Build_Script.sh not found in /livecd-creator/FedoraRemix"
    exit 1
fi

echo "Running: Enhanced_Remix_Build_Script.sh with kickstart: ${REMIX_KICKSTART}"
# Export the kickstart selection for the build script
export REMIX_KICKSTART
./Enhanced_Remix_Build_Script.sh

# Build completed - Show prominent success message
echo ""
echo -e "\033[1;32m╔══════════════════════════════════════════════════════════════════════════════╗\033[0m"
echo -e "\033[1;32m║\033[0m \033[1;37m🎉 BUILD PROCESS COMPLETED SUCCESSFULLY! 🎉\033[0m                              \033[1;32m║\033[0m"
echo -e "\033[1;32m╚══════════════════════════════════════════════════════════════════════════════╝\033[0m"
echo ""
echo -e "\033[1;36m╔══════════════════════════════════════════════════════════════════════════════╗\033[0m"
echo -e "\033[1;36m║\033[0m \033[1;33mIMPORTANT: Container Control Instructions\033[0m                                   \033[1;36m║\033[0m"
echo -e "\033[1;36m╠══════════════════════════════════════════════════════════════════════════════╣\033[0m"
echo -e "\033[1;36m║\033[0m                                                                              \033[1;36m║\033[0m"
echo -e "\033[1;36m║\033[0m  \033[1;37m📋 Your Fedora Remix ISO is ready!\033[0m                                          \033[1;36m║\033[0m"
echo -e "\033[1;36m║\033[0m  \033[0;32m   Location: /livecd-creator/FedoraRemix/${REMIX_KICKSTART}.iso\033[0m             \033[1;36m║\033[0m"
echo -e "\033[1;36m║\033[0m                                                                              \033[1;36m║\033[0m"
echo -e "\033[1;36m║\033[0m  \033[1;33m⚠️  To exit this container:\033[0m                                                \033[1;36m║\033[0m"
echo -e "\033[1;36m║\033[0m     \033[1;37m➜ Type:\033[0m \033[1;32mexit\033[0m or \033[1;32mpoweroff\033[0m                                               \033[1;36m║\033[0m"
echo -e "\033[1;36m║\033[0m                                                                              \033[1;36m║\033[0m"
echo -e "\033[1;36m║\033[0m  \033[0;36mℹ️  The container will remain running for inspection.\033[0m                     \033[1;36m║\033[0m"
echo -e "\033[1;36m║\033[0m  \033[0;36m   You can explore the build environment before exiting.\033[0m                   \033[1;36m║\033[0m"
echo -e "\033[1;36m║\033[0m                                                                              \033[1;36m║\033[0m"
echo -e "\033[1;36m╚══════════════════════════════════════════════════════════════════════════════╝\033[0m"
echo ""

# Mark as completed
touch /tmp/entrypoint-completed

