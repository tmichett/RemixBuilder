# RemixBuilder Container - Fix History

Quick reference for fixes applied to the RemixBuilder container.

---

## February 22, 2026 - SELinux Permission Fix

**Problem:** Container fails with permission denied on `/tmp/remix_kickstart.txt`

**Solution:** Updated entrypoint.sh with graceful error handling

**Files Changed:**
- `entrypoint.sh` (line 46-48): Added error suppression and fallback

**Container Version:** `ghcr.io/tmichett/fedora-remix-builder:43` (rebuilt 2026-02-22)

**Status:** ✅ Fixed - Container starts successfully on SELinux enforcing systems

**Details:** See [CHANGELOG.md](CHANGELOG.md#unreleased)

---

## January 17, 2026 - DNF Cache & Image Name

**Problem:** Stale DNF cache causing package metadata issues

**Solution:** Added `dnf clean all` to entrypoint startup

**Files Changed:**
- `entrypoint.sh`: Added DNF cache cleaning
- `build.sh`, `push.sh`: Auto-generate Image_Name from config

**Status:** ✅ Fixed - Fresh repo metadata on every build

**Details:** See [CHANGELOG.md](CHANGELOG.md#2026-01-17---container-build-improvements)

---

## January 1, 2026 - Kickstart Selection

**Feature:** Support for multiple kickstart variants

**Files Changed:**
- `entrypoint.sh`: Added REMIX_KICKSTART environment variable support
- Added fallback file reading mechanism

**Status:** ✅ Implemented - Multiple kickstart variants supported

**Details:** See [CHANGELOG.md](CHANGELOG.md#2026-01-01---kickstart-selection)

---

## November 22, 2025 - Initial Release

**Feature:** Base RemixBuilder container implementation

**Components:**
- Containerfile with systemd support
- Automated build via systemd services
- Loop device creation
- Auto-login console
- DNF optimization

**Status:** ✅ Released - Initial working version

**Details:** See [CHANGELOG.md](CHANGELOG.md#2025-11-22---initial-container-release)

---

## Related Documentation

- [CHANGELOG.md](CHANGELOG.md) - Detailed change history
- [README.md](README.md) - Full documentation and usage
- [Fedora_Remix/LINUX_BUILD_FIX.md](../Fedora_Remix/LINUX_BUILD_FIX.md) - Linux compatibility fixes

## Quick Commands

```bash
# Rebuild container with latest fixes
./build.sh

# Push to registry
./push.sh

# Check container image
podman images | grep fedora-remix-builder

# View container logs
podman logs remix-builder
```
