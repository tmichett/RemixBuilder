# SELinux Relabel Fix — `setfiles` EINVAL on Chroot Packages

> **Status:** Fixed in `Containerfile` and `entrypoint.sh`  
> **Symptom:** Build aborts with `Error creating Live CD : SELinux relabel failed.`

---

## Symptom

Near the end of the `livecd-creator` run, after all packages are installed and post-scripts have completed, the build aborts with:

```
setfiles: Could not set context for /usr/lib/osbuild/stages/...:  Invalid argument
setfiles: Could not set context for /usr/bin/osbuild:  Invalid argument
...
Error creating Live CD : SELinux relabel failed.
```

Hundreds of files under `/usr/lib/osbuild/` (stages, sources, assemblers) all fail with `Invalid argument`, and `livecd-creator` treats this as a fatal error.

---

## Root Cause

`livecd-creator` calls `setfiles` at the end of the build to relabel every file in the chroot with its correct SELinux context. The sequence of events that causes the failure:

1. The chroot package installation pulls in `osbuild` and `osbuild-selinux` as dependencies of base kickstart groups (e.g., `@workstation-product-group`). This happens even on minimal builds — you do not need to explicitly request `osbuild`.

2. `osbuild-selinux` installs file context rules that map `/usr/lib/osbuild/**` and `/usr/bin/osbuild` to the SELinux type `osbuild_exec_t`.

3. `setfiles` reads those rules from the **chroot's** compiled policy and calls `setxattr("security.selinux", "osbuild_exec_t:s0", ...)` on each osbuild file.

4. The **host kernel** validates every context passed to `setxattr`. Because the container image did not have `osbuild-selinux` installed, the kernel's running SELinux policy has no record of `osbuild_exec_t`. The kernel returns `EINVAL`.

5. `setfiles` exits non-zero, and `livecd-creator` aborts with `SELinux relabel failed`.

The key distinction: `setfiles` reads the **chroot's** policy to *look up* contexts, but the **host kernel's** running policy is what *validates* those contexts when the `setxattr` syscall is made. These two policies are out of sync whenever the chroot has SELinux policy modules that are not also loaded into the host/container kernel.

The `mount: .../sys/fs/selinux/load: mount point does not exist` warning seen at build start is a related but separate, non-fatal issue caused by the SELinux filesystem not being bind-mounted into the chroot during the early setup phase.

---

## Fix

The fix requires two coordinated changes:

### 1. `Containerfile` — install `osbuild-selinux` in the image

Adding `osbuild-selinux` to the `dnf install` layer ensures the compiled policy module file (`osbuild.pp`) is present inside the container image at build time.

```dockerfile
RUN dnf install -y \
    python3-pyyaml \
    httpd \
    sshfs \
    livecd-tools \
    vim \
    git \
    python3 \
    systemd \
    glibc-langpack-en \
    osbuild-selinux \
    && dnf clean all
```

> **Why not just install it in `entrypoint.sh`?**  
> Installing at image build time is faster (no runtime DNF hit) and ensures the `.pp` file is always present regardless of network availability at run time.

### 2. `entrypoint.sh` — load the policy modules into the kernel before the build

Installing the RPM places the `.pp` module file on disk but does **not** automatically load it into the running kernel's policy (the `%post` scriptlet that normally does this via `semodule -i` cannot run during `podman build` because the container has no access to the kernel's SELinux interface at image build time).

The following block, added before the Python prepare scripts run, loads all available `.pp` modules into the **running kernel** using the container's `--privileged` access:

```bash
echo "Loading SELinux policy modules for chroot relabeling..."
for pp_file in /usr/share/selinux/packages/*.pp; do
    [ -f "$pp_file" ] && semodule -i "$pp_file" 2>/dev/null && echo "  Loaded: $(basename "$pp_file")" || true
done
echo "SELinux policy modules loaded."
```

This runs early in the entrypoint — well before `livecd-creator` installs packages into the chroot or calls `setfiles` — so the kernel policy is up to date by the time relabeling occurs.

---

## Why the Loop Loads All `.pp` Files

The loop loads every `.pp` file in `/usr/share/selinux/packages/` rather than targeting `osbuild.pp` specifically because:

- Other packages installed in the chroot (e.g., `nbdkit`, `swtpm`, `container-selinux`) also ship `-selinux` companions that define additional types.
- As the kickstart package list evolves, new `-selinux` packages may appear in the chroot without a matching policy in the container.
- Loading all available modules at once is cheap (a few seconds) and future-proofs the fix.

---

## Rebuilding the Container

After applying these changes, rebuild and push the container image:

```bash
cd /path/to/RemixBuilder
./build.sh
./push.sh   # if pushing to the registry
```

The next build run will load all SELinux policy modules into the kernel before `livecd-creator` runs, and `setfiles` will succeed.

---

## Verification

A successful build will show the following in the build log before the Python prepare scripts run:

```
Loading SELinux policy modules for chroot relabeling...
  Loaded: osbuild.pp
  ...
SELinux policy modules loaded.
```

And the build will no longer abort with `SELinux relabel failed`.

---

## Related Issues

- `mount: .../sys/fs/selinux/load: mount point does not exist` — non-fatal warning at build start; livecd-creator continues past it.
- Linux `/sys` unmount errors — separate issue documented in `LINUX_BUILD_FIX.md` in the Fedora Remix project.
