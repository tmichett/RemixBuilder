# Changelog - RemixBuilder Container

All notable changes to the RemixBuilder container project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [Unreleased]

### Fixed
- **2026-02-22**: SELinux permission denied error in entrypoint.sh
  - Added error handling for `/tmp/remix_kickstart.txt` write operations
  - Gracefully falls back to environment variable if file write fails
  - Files changed: `entrypoint.sh` (line 46-48)
  - Issue: Container failed with "Permission denied" on SELinux enforcing systems
  - Result: Container starts successfully regardless of SELinux mode

### Changed
- **2026-02-22**: Improved entrypoint.sh robustness
  - File write now uses error suppression: `2>/dev/null || { ... }`
  - Added informative warning message if file write fails
  - Primary reliance on `REMIX_KICKSTART` environment variable
  - Better compatibility with different host configurations

---

## [2026-01-17] - Container Build Improvements

### Fixed
- **2026-01-17**: DNF cache clean to ensure fresh repository metadata
  - Added `dnf clean all` to entrypoint.sh startup
  - Prevents stale package metadata issues
  - Commit: `f28071c`

### Changed
- **2026-01-17**: Auto-generate Image_Name from config
  - build.sh and push.sh now dynamically construct image name
  - Format: `ghcr.io/{GitHub_Registry_Owner}/fedora-remix-builder:{Fedora_Version}`
  - Simplified version management
  - Commits: `c832577`, `a654a93`

---

## [2026-01-01] - Kickstart Selection

### Added
- **2026-01-01**: Support for multiple kickstart variants
  - Environment variable `REMIX_KICKSTART` support
  - Fallback file reading from `/tmp/remix_kickstart.txt`
  - Debug output for troubleshooting
  - Commit: `6e70cf8`

### Changed
- **2026-01-01**: Enhanced entrypoint.sh with kickstart selection
  - Dynamic kickstart file handling
  - Improved logging and status messages
  - Better integration with Build_Remix.sh

---

## [2025-11-22] - Initial Container Release

### Added
- **2025-11-22**: Base container implementation
  - Fedora-based container with systemd support
  - Automated build process via systemd services
  - Loop device creation for livecd-creator
  - Auto-login console with status display
  - SSH configuration for GitHub access
  - DNF optimization (max_parallel_downloads, fastestmirror)

### Container Components
- `Containerfile`: Multi-stage Fedora container build
- `entrypoint.sh`: Automated build orchestration script
- `build.sh`: Local container build script
- `push.sh`: GitHub Container Registry push script
- `config.yml`: Centralized configuration

### Features
- Systemd-based architecture (PID 1)
- Privileged mode for loop device access
- Volume mounts for workspace and output
- Locale configuration (en_US.UTF-8)
- Build status monitoring and logging

---

## Earlier Development

See git history for changes prior to November 2025.
