# Fedora Remix Builder

A containerized build environment for creating Fedora Remix ISO images. This project provides a Podman-based container that automates the Fedora Remix build process.

## Quick Start

### Prerequisites

- **Podman** installed and configured
- **GitHub Personal Access Token** (for pushing to GitHub Container Registry) with `write:packages` permission
- **SSH key** for GitHub access (used by the container for git operations)
- **Fedora Remix project** directory on your local system

### Initial Setup

1. **Clone or download this repository** to get the build scripts and configuration files.

2. **Configure `config.yml`** with your settings:
   ```yaml
   Container_Properties:
     Fedora_Version: "43"  # Update this to match your target Fedora version
     SSH_Key_Location: "~/.ssh/github_id"  # Path to your GitHub SSH key
     Fedora_Remix_Location: "/path/to/your/output/directory"  # Output directory for ISO builds
     GitHub_Registry_Owner: "your-github-username"  # Your GitHub username or organization
     # Image_Name is auto-generated from GitHub_Registry_Owner and Fedora_Version
     # Format: ghcr.io/{GitHub_Registry_Owner}/fedora-remix-builder:{Fedora_Version}
   ```

   **Important Notes:**
   - The `Fedora_Version` should match the version in your Fedora Remix project's `/Setup/config.yml` file
   - `Image_Name` is now **automatically generated** from `GitHub_Registry_Owner` and `Fedora_Version`
   - Just change `Fedora_Version` to switch container versions (e.g., `"43"` → `"44"`)

3. **Copy files to your Fedora Remix project** (recommended):
   - Copy `Build_Remix.sh` to the root of your Fedora Remix project directory
   - Copy `config.yml` to the root of your Fedora Remix project directory
   - This allows you to run the build script directly from your project directory

4. **Verify version consistency**:
   - Ensure the `Fedora_Version` in `config.yml` matches the Fedora version specified in your Fedora Remix project's `/Setup/config.yml`
   - This ensures you're building with the correct container image and Fedora version

### Building the Container

From the RemixBuilder directory (or wherever you have the build scripts):

```bash
./build.sh
```

This script will:
- Read `Fedora_Version` and `Image_Name` from `config.yml`
- Build a container image based on the specified Fedora version
- Tag the image with the name specified in `Image_Name` (including the tag)

**Example:** If `Image_Name` is `ghcr.io/tmichett/fedora-remix-builder:42`, the image will be built and tagged accordingly.

### Pushing the Container

After building, push the container to GitHub Container Registry:

```bash
./push.sh
```

This script will:
- Read `Image_Name` from `config.yml`
- Verify the image exists locally
- Prompt for GitHub Container Registry login (use your GitHub Personal Access Token)
- Push the image to the registry

**Note:** The `push.sh` script uses the full `Image_Name` from `config.yml`, including the tag. Make sure your GitHub token has `write:packages` permission.

### Running the Container and Building the Remix

To build your Fedora Remix, run:

```bash
./Build_Remix.sh
```

**If you've copied the files to your Fedora Remix project directory**, run it from there:

```bash
cd /path/to/your/fedora-remix-project
./Build_Remix.sh
```

#### Kickstart Selection

The build script now supports **multiple Remix variants** with an interactive menu:

```bash
# Interactive mode - shows menu of available kickstarts
./Build_Remix.sh

# Direct kickstart selection (skip menu)
./Build_Remix.sh -k FedoraRemixCosmic

# List available kickstart files
./Build_Remix.sh -l

# Show help
./Build_Remix.sh -h
```

**Interactive Menu Example:**
```
╔══════════════════════════════════════════════════════╗
║ 🚀  Fedora Remix Builder - Kickstart Selection       ║
╠══════════════════════════════════════════════════════╣
║  1) FedoraRemix                              [DEFAULT] ║
║  2) FedoraRemixCosmic                                  ║
╚══════════════════════════════════════════════════════╝

Select kickstart to build (1-2) [Enter=default]:
```

- Press **Enter** to use the default (`FedoraRemix.ks`)
- The menu automatically filters out snippet files (`*Packages.ks`, `*Repos.ks`)
- The output ISO is named after the selected kickstart (e.g., `FedoraRemixCosmic.iso`)

This script will:
- Read configuration from `config.yml` (SSH key location, output location, Fedora version, etc.)
- Dynamically construct the container image name from `GitHub_Registry_Owner` and `Fedora_Version`
- Prompt for kickstart selection (or accept via `-k` flag)
- Mount your SSH key into the container at `~/github_id`
- Mount your output directory to `/livecd-creator` in the container
- Mount the current working directory (source) to `~/workspace` in the container
- Start the container and automatically run the build process

The container will:
1. Run the entrypoint script which executes the build process
2. Execute `Prepare_Web_Files.py` and `Prepare_Fedora_Remix_Build.py` from `~/workspace/Setup`
3. Run `Enhanced_Remix_Build_Script.sh` from `/livecd-creator/FedoraRemix`
4. Complete the build and remain running for inspection

**To exit the container:** Type `exit` in the container shell. This will cleanly shut down the container.

## Project Components

### Configuration Files

#### `config.yml`
Central configuration file used by all scripts. Contains:
- **Fedora_Version**: The Fedora version to use as the base container image
- **SSH_Key_Location**: Path to your GitHub SSH key (mounted into container)
- **Fedora_Remix_Location**: Path to the output directory for ISO builds
- **GitHub_Registry_Owner**: Your GitHub username or organization name

**Note:** `Image_Name` is now **auto-generated** from `GitHub_Registry_Owner` and `Fedora_Version`:
```
ghcr.io/{GitHub_Registry_Owner}/fedora-remix-builder:{Fedora_Version}
```

**All scripts (`build.sh`, `push.sh`, `Build_Remix.sh`) dynamically construct the container name from these values.**

### Build Scripts

#### `build.sh`
Builds the container image using Podman:
- Reads `Fedora_Version` and `Image_Name` from `config.yml`
- Passes `Fedora_Version` as a build argument to the Containerfile
- Tags the built image with the full `Image_Name` from `config.yml` (including tag)

#### `push.sh`
Pushes the container image to GitHub Container Registry:
- Reads `Image_Name` from `config.yml`
- Verifies the image exists locally
- Authenticates with GitHub Container Registry
- Pushes the image using the full `Image_Name` from `config.yml`

#### `Build_Remix.sh`
Runs the container and builds the Fedora Remix:
- **Interactive kickstart selection** with color-coded menu (or use `-k <name>` for automation)
- Reads `SSH_Key_Location`, `Fedora_Remix_Location`, `Fedora_Version`, and `GitHub_Registry_Owner` from `config.yml`
- **Dynamically constructs `Image_Name`** from `GitHub_Registry_Owner` and `Fedora_Version`
- Mounts volumes for SSH key, output directory, and source workspace
- Automatically detects if `sudo` is needed for loop device access on Linux
- Runs the container with systemd support and privileged mode (required for livecd-creator)
- The container automatically executes the build process via the entrypoint script
- **Output ISO named after selected kickstart** (e.g., `FedoraRemixCosmic.iso`)

### Container Components

#### `Containerfile`
Defines the container image:
- Based on Fedora (version specified via `FEDORA_VERSION` build arg)
- Installs required packages: `python3-pyyaml`, `httpd`, `sshfs`, `livecd-tools`, `vim`, `git`, `python3`, `systemd`
- Configures locale settings
- Sets up SSH configuration
- Creates systemd services for automatic build execution
- Uses systemd as the entrypoint (PID 1)

#### `entrypoint.sh`
Automated build script that runs inside the container:
1. **Configures DNF for optimal performance** (`max_parallel_downloads=10`, `fastestmirror=True`)
2. **Reads selected kickstart** from environment variable or fallback file
3. Waits for workspace directory to be available
4. Changes to `~/workspace/Setup` directory
5. Runs `Prepare_Web_Files.py`
6. Runs `Prepare_Fedora_Remix_Build.py`
7. Changes to `/livecd-creator/FedoraRemix` directory
8. Runs `Enhanced_Remix_Build_Script.sh` with the selected kickstart
9. Marks build as completed

The entrypoint runs automatically when the container starts via a systemd service.

#### `ssh_config`
SSH configuration file copied into the container:
- Configures GitHub SSH access
- Uses the mounted SSH key at `~/github_id`
- Disables strict host key checking for GitHub

### Volume Mounts

When running `Build_Remix.sh`, the following volumes are mounted:

- **SSH Key**: `SSH_Key_Location` → `/root/github_id` (read-only)
- **Fedora Remix Project**: `Fedora_Remix_Location` → `/livecd-creator` (read-write)
- **Workspace**: Current directory → `/root/workspace` (read-write)

The workspace mount allows the container to access your `Build_Remix.sh` and `config.yml` files, as well as the Fedora Remix project's Setup directory.

## Version Management

### Updating Fedora Version

When building for a new Fedora version:

1. **Update `config.yml`**:
   - Change `Fedora_Version` to the new version (e.g., `"43"` → `"44"`)
   - The `Image_Name` is **automatically updated** based on this value

2. **Update your Fedora Remix project's `/Setup/config.yml`**:
   - Ensure the Fedora version matches the version in the RemixBuilder `config.yml`
   - This ensures consistency between the container base image and the Remix build

3. **Rebuild the container**:
   ```bash
   ./build.sh
   ```

4. **Push the new container** (if needed):
   ```bash
   ./push.sh
   ```

### Container Image Tagging Strategy

The container image name is **automatically generated** from `config.yml`:

```
ghcr.io/{GitHub_Registry_Owner}/fedora-remix-builder:{Fedora_Version}
```

**Example:** With `GitHub_Registry_Owner: "tmichett"` and `Fedora_Version: "43"`:
```
ghcr.io/tmichett/fedora-remix-builder:43
```

Simply update `Fedora_Version` in `config.yml` to switch container versions. All scripts automatically use the correct container image.

## Troubleshooting

### Container won't start
- Verify Podman is installed and running
- Check that the `Image_Name` in `config.yml` matches a built image
- Ensure the Fedora Remix location exists and is accessible

### Build fails in container

**Linux-specific `/sys` unmount errors**: If you see errors like:
```
Error creating Live CD : Unable to unmount filesystem at /var/tmp/imgcreate-*/install_root/sys
```

This has been **FIXED** in the latest version! See the [Fedora_Remix LINUX_BUILD_FIX.md](../Fedora_Remix/LINUX_BUILD_FIX.md) document for complete details.

**Quick fix summary:**
- Updated scripts with dynamic Python version detection
- Added imgcreate patches for systemd compatibility
- Automatic verification of patches before build

**Other build failures:**
- Check container logs: `journalctl -u remix-builder.service -n 100` (inside container)
- Verify the Fedora version in `config.yml` matches the version in your Fedora Remix project's `/Setup/config.yml`
- Ensure all required files exist in the Fedora Remix project directory

### SSH operations fail
- Verify the SSH key path in `config.yml` is correct
- Check that the SSH key has proper permissions (typically `600`)
- Ensure the SSH key is authorized for your GitHub account

### Image push fails
- Verify your GitHub Personal Access Token has `write:packages` permission
- Check that the `Image_Name` in `config.yml` uses the correct GitHub username/organization
- Ensure you're logged into GitHub Container Registry: `podman login ghcr.io`

## Best Practices

1. **Version Consistency**: Always ensure `Fedora_Version` in RemixBuilder's `config.yml` matches the version in your Fedora Remix project's `/Setup/config.yml`

2. **File Organization**: Place `Build_Remix.sh` and `config.yml` in the root of your Fedora Remix project for easier access

3. **Image Tagging**: Use version-specific tags (e.g., `:42`, `:43`) when building for specific Fedora versions to maintain a clear history

4. **Regular Updates**: Rebuild the container when switching Fedora versions or when dependencies change

5. **Backup**: Keep backups of your `config.yml` file, especially if you have custom configurations

## License

[Add your license information here]
