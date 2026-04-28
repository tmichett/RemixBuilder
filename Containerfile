# Containerfile for Fedora Remix Builder
# Accepts FEDORA_VERSION as build argument

ARG FEDORA_VERSION=39
FROM fedora:${FEDORA_VERSION}

# Install required RPMs including systemd and locale support
# osbuild-selinux is required so its .pp module file is present in the image;
# entrypoint.sh loads it into the running kernel before livecd-creator runs setfiles,
# preventing EINVAL "SELinux relabel failed" when the chroot contains osbuild packages.
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

# Configure locale
RUN localedef -i en_US -f UTF-8 en_US.UTF-8 || true

# Set default locale environment variables
RUN echo 'export LC_ALL=en_US.UTF-8' >> /etc/profile.d/locale.sh && \
    echo 'export LANG=en_US.UTF-8' >> /etc/profile.d/locale.sh && \
    echo 'export LANGUAGE=en_US.UTF-8' >> /etc/profile.d/locale.sh

# Add function to root's .bashrc to make exit work properly in container
# Also show entrypoint status and logs when logging in
RUN echo 'exit_container() { systemctl poweroff; }' >> /root/.bashrc && \
    echo 'alias exit="exit_container"' >> /root/.bashrc && \
    echo 'if [ ! -f /tmp/entrypoint-completed ]; then' >> /root/.bashrc && \
    echo '  echo ""' >> /root/.bashrc && \
    echo '  echo "=========================================="' >> /root/.bashrc && \
    echo '  echo "Entrypoint script status:"' >> /root/.bashrc && \
    echo '  systemctl is-active remix-builder.service >/dev/null 2>&1 && echo "  Status: Running or completed"' >> /root/.bashrc && \
    echo '  systemctl is-failed remix-builder.service >/dev/null 2>&1 && echo "  Status: Failed - check logs"' >> /root/.bashrc && \
    echo '  echo ""' >> /root/.bashrc && \
    echo '  if [ -f /tmp/entrypoint.log ]; then' >> /root/.bashrc && \
    echo '    echo "Recent entrypoint output:"' >> /root/.bashrc && \
    echo '    tail -20 /tmp/entrypoint.log' >> /root/.bashrc && \
    echo '  fi' >> /root/.bashrc && \
    echo '  echo ""' >> /root/.bashrc && \
    echo '  echo "View full logs: journalctl -u remix-builder.service -n 100"' >> /root/.bashrc && \
    echo '  echo "Or view log file: tail -f /tmp/entrypoint.log"' >> /root/.bashrc && \
    echo '  echo "Or run manually: /entrypoint.sh"' >> /root/.bashrc && \
    echo '  echo "=========================================="' >> /root/.bashrc && \
    echo '  echo ""' >> /root/.bashrc && \
    echo 'else' >> /root/.bashrc && \
    echo '  echo "Entrypoint script has completed successfully."' >> /root/.bashrc && \
    echo 'fi' >> /root/.bashrc && \
    echo 'echo "Type \"exit\" to shutdown the container"' >> /root/.bashrc

# Copy ssh_config to root's home directory
COPY ssh_config /root/.ssh/config

# Create entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Set default target to multi-user (not graphical) by creating symlink manually
RUN rm -f /etc/systemd/system/default.target && \
    ln -s /usr/lib/systemd/system/multi-user.target /etc/systemd/system/default.target

# Do not run agetty on /dev/console. With `podman run --privileged` the container can
# share the host's real console; console-getty then exits and systemd respawns it every
# few seconds (audit SERVICE_STOP/SERVICE_START), which flashes GNOME/Wayland on the host.
# Build output still goes to the same terminal via remix-builder.service (journal+console).
RUN ln -sf /dev/null /etc/systemd/system/console-getty.service

# Create minimal systemd service to run entrypoint.sh automatically
# This is necessary for the entrypoint to run with systemd as PID 1
RUN echo '[Unit]' > /etc/systemd/system/remix-builder.service && \
    echo 'Description=Run Remix Builder Entrypoint' >> /etc/systemd/system/remix-builder.service && \
    echo 'After=local-fs.target loop-devices.service systemd-journald.socket' >> /etc/systemd/system/remix-builder.service && \
    echo 'Requires=local-fs.target loop-devices.service' >> /etc/systemd/system/remix-builder.service && \
    echo '' >> /etc/systemd/system/remix-builder.service && \
    echo '[Service]' >> /etc/systemd/system/remix-builder.service && \
    echo 'Type=oneshot' >> /etc/systemd/system/remix-builder.service && \
    echo 'ExecStart=/entrypoint.sh' >> /etc/systemd/system/remix-builder.service && \
    echo 'RemainAfterExit=yes' >> /etc/systemd/system/remix-builder.service && \
    echo '# Pass REMIX_KICKSTART from podman run -e into the service environment.' >> /etc/systemd/system/remix-builder.service && \
    echo '# systemd services do not inherit parent environment by default; without' >> /etc/systemd/system/remix-builder.service && \
    echo '# PassEnvironment the kickstart selection is lost and build defaults to FedoraRemix.' >> /etc/systemd/system/remix-builder.service && \
    echo 'PassEnvironment=REMIX_KICKSTART' >> /etc/systemd/system/remix-builder.service && \
    echo '# journal+console: show build in the same window as podman run -it' >> /etc/systemd/system/remix-builder.service && \
    echo '# Do not set TTYPath=; that can fight console-getty for the same VT' >> /etc/systemd/system/remix-builder.service && \
    echo 'StandardOutput=journal+console' >> /etc/systemd/system/remix-builder.service && \
    echo 'StandardError=journal+console' >> /etc/systemd/system/remix-builder.service && \
    echo 'StandardInput=null' >> /etc/systemd/system/remix-builder.service && \
    echo '' >> /etc/systemd/system/remix-builder.service && \
    echo '[Install]' >> /etc/systemd/system/remix-builder.service && \
    echo 'WantedBy=multi-user.target' >> /etc/systemd/system/remix-builder.service

# Enable the service by creating the symlink manually (systemctl doesn't work during build)
RUN mkdir -p /etc/systemd/system/multi-user.target.wants && \
    ln -s /etc/systemd/system/remix-builder.service /etc/systemd/system/multi-user.target.wants/remix-builder.service

# Create systemd service to ensure loop devices are available for livecd-creator
RUN echo '[Unit]' > /etc/systemd/system/loop-devices.service && \
    echo 'Description=Create loop devices for livecd-creator' >> /etc/systemd/system/loop-devices.service && \
    echo 'Before=remix-builder.service' >> /etc/systemd/system/loop-devices.service && \
    echo '' >> /etc/systemd/system/loop-devices.service && \
    echo '[Service]' >> /etc/systemd/system/loop-devices.service && \
    echo 'Type=oneshot' >> /etc/systemd/system/loop-devices.service && \
    echo 'ExecStart=/bin/bash -c "for i in {0..7}; do mknod -m 0660 /dev/loop$i b 7 $i 2>/dev/null || true; done"' >> /etc/systemd/system/loop-devices.service && \
    echo 'RemainAfterExit=yes' >> /etc/systemd/system/loop-devices.service && \
    echo '' >> /etc/systemd/system/loop-devices.service && \
    echo '[Install]' >> /etc/systemd/system/loop-devices.service && \
    echo 'WantedBy=multi-user.target' >> /etc/systemd/system/loop-devices.service && \
    mkdir -p /etc/systemd/system/multi-user.target.wants && \
    ln -s /etc/systemd/system/loop-devices.service /etc/systemd/system/multi-user.target.wants/loop-devices.service

# Set working directory
WORKDIR /root/workspace

# Set systemd as the entrypoint
ENTRYPOINT ["/usr/sbin/init"]

