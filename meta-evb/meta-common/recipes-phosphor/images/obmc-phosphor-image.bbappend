ROOTFS_POSTPROCESS_COMMAND:append:evb-rpi4-64 = " usbroot_runtime_fixups;"

usbroot_runtime_fixups() {
    if [ -f ${IMAGE_ROOTFS}/etc/fstab ]; then
        sed -i -e 's#^/var/persist/home[[:space:]]\+/home[[:space:]]\+none[[:space:]]\+bind[[:space:]]\+0[[:space:]]\+0#tmpfs                /home                tmpfs      mode=0755,nodev,nosuid       0  0#' ${IMAGE_ROOTFS}/etc/fstab
        sed -i -e '/^[[:space:]]*\/dev\/mmcblk0p1[[:space:]]\+\/boot[[:space:]]/d' ${IMAGE_ROOTFS}/etc/fstab
        grep -q '^tmpfs[[:space:]]\+/var/persist[[:space:]]\+tmpfs' ${IMAGE_ROOTFS}/etc/fstab || \
            echo 'tmpfs                /var/persist         tmpfs      mode=0755,nodev,nosuid       0  0' >> ${IMAGE_ROOTFS}/etc/fstab
    fi

    install -d ${IMAGE_ROOTFS}/etc/systemd/system
    ln -snf /dev/null ${IMAGE_ROOTFS}/etc/systemd/system/boot.mount

    install -d ${IMAGE_ROOTFS}/etc/tmpfiles.d
    cat > ${IMAGE_ROOTFS}/etc/tmpfiles.d/usbroot-volatile.conf <<'EOF'
d /var/volatile/tmp 1777 root root -
d /var/volatile/home 0755 root root -
d /var/persist 0755 root root -
d /var/persist/home 0755 root root -
d /home/root 0755 root root -
EOF

    install -d ${IMAGE_ROOTFS}/etc/modules-load.d
    cat > ${IMAGE_ROOTFS}/etc/modules-load.d/usb-gadget.conf <<'EOF'
dwc2
g_ether
EOF

    install -d ${IMAGE_ROOTFS}/etc/modprobe.d
    cat > ${IMAGE_ROOTFS}/etc/modprobe.d/g_ether.conf <<'EOF'
options g_ether dev_addr=02:1a:11:00:00:02 host_addr=02:1a:11:00:00:01
EOF

    install -d ${IMAGE_ROOTFS}/etc/systemd/network
    cat > ${IMAGE_ROOTFS}/etc/systemd/network/10-usb0.network <<'EOF'
[Match]
Name=usb0

[Network]
Address=192.168.7.2/24
LinkLocalAddressing=no
IPv6AcceptRA=no
DHCP=no
EOF

    install -d ${IMAGE_ROOTFS}/usr/sbin
    cat > ${IMAGE_ROOTFS}/usr/sbin/usb-gadget-init.sh <<'EOF'
#!/bin/sh
set -u

if [ -e /sys/class/net/usb0 ]; then
    ip link set usb0 up || true
    exit 0
fi

modprobe dwc2 || true

udc_ready=0
for _ in 1 2 3 4 5 6 7 8 9 10; do
    if [ -d /sys/class/udc ] && [ "$(ls -A /sys/class/udc 2>/dev/null)" != "" ]; then
        udc_ready=1
        break
    fi
    sleep 1
done

if [ "$udc_ready" -eq 1 ]; then
    for _ in 1 2 3 4 5; do
        modprobe g_ether && break
        sleep 1
    done
fi

if [ -e /sys/class/net/usb0 ]; then
    ip link set usb0 up || true
fi
EOF
    chmod 0755 ${IMAGE_ROOTFS}/usr/sbin/usb-gadget-init.sh

    install -d ${IMAGE_ROOTFS}/usr/lib/systemd/system
    cat > ${IMAGE_ROOTFS}/usr/lib/systemd/system/usb-gadget-init.service <<'EOF'
[Unit]
Description=Initialize USB gadget ethernet (usb0)
DefaultDependencies=no
After=systemd-modules-load.service
Wants=systemd-modules-load.service
Before=network-pre.target
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/usr/sbin/usb-gadget-init.sh
RemainAfterExit=yes
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=sysinit.target
EOF

install -d ${IMAGE_ROOTFS}/etc/systemd/system/sysinit.target.wants
ln -sf /usr/lib/systemd/system/usb-gadget-init.service \
    ${IMAGE_ROOTFS}/etc/systemd/system/sysinit.target.wants/usb-gadget-init.service

install -d ${IMAGE_ROOTFS}/etc/systemd/system/multi-user.target.wants
ln -sf /usr/lib/systemd/system/usb-gadget-init.service \
    ${IMAGE_ROOTFS}/etc/systemd/system/multi-user.target.wants/usb-gadget-init.service

    if [ -f ${IMAGE_ROOTFS}/usr/lib/systemd/system/phosphor-ipmi-net@.service ]; then
        sed -i -e 's/^DefaultInstance=.*/DefaultInstance=eth0/' \
            ${IMAGE_ROOTFS}/usr/lib/systemd/system/phosphor-ipmi-net@.service
    fi

    install -d ${IMAGE_ROOTFS}/etc/systemd/system/sockets.target.wants
    rm -f ${IMAGE_ROOTFS}/etc/systemd/system/sockets.target.wants/phosphor-ipmi-net@usb0.socket
    ln -sf /usr/lib/systemd/system/phosphor-ipmi-net@.socket \
        ${IMAGE_ROOTFS}/etc/systemd/system/sockets.target.wants/phosphor-ipmi-net@eth0.socket

    rm -f ${IMAGE_ROOTFS}/etc/systemd/system/multi-user.target.wants/phosphor-ipmi-net@usb0.service
    ln -sf /usr/lib/systemd/system/phosphor-ipmi-net@.service \
        ${IMAGE_ROOTFS}/etc/systemd/system/multi-user.target.wants/phosphor-ipmi-net@eth0.service
}
