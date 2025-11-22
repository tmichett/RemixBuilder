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

echo "Running: Enhanced_Remix_Build_Script.sh"
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
echo -e "\033[1;36m║\033[0m  \033[0;32m   Location: /livecd-creator/FedoraRemix/FedoraRemix.iso\033[0m                   \033[1;36m║\033[0m"
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

