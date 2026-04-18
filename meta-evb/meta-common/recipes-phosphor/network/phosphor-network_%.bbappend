FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI:append:evb-rpi4-64 = " \
    file://10-bond0.netdev \
    file://20-bond0.network \
    file://30-bond-en-slave.network \
    file://31-bond-eth-slave.network \
    file://32-bond-wwan0-slave.network \
    file://33-bond-wwan1-slave.network \
    file://60-phosphor-networkd-default.network \
"

SRC_URI:append:evb-rpi5-64 = " \
    file://10-bond0.netdev \
    file://20-bond0.network \
    file://30-bond-en-slave.network \
    file://31-bond-eth-slave.network \
    file://32-bond-wwan0-slave.network \
    file://33-bond-wwan1-slave.network \
    file://60-phosphor-networkd-default.network \
"

do_install:append:evb-rpi4-64() {
    install -d ${D}${systemd_unitdir}/network
    install -d ${D}${sysconfdir}/systemd/network

    install -m 0644 ${UNPACKDIR}/10-bond0.netdev ${D}${systemd_unitdir}/network/10-bond0.netdev
    install -m 0644 ${UNPACKDIR}/20-bond0.network ${D}${systemd_unitdir}/network/20-bond0.network
    install -m 0644 ${UNPACKDIR}/30-bond-en-slave.network ${D}${systemd_unitdir}/network/30-bond-en-slave.network
    install -m 0644 ${UNPACKDIR}/31-bond-eth-slave.network ${D}${systemd_unitdir}/network/31-bond-eth-slave.network
    install -m 0644 ${UNPACKDIR}/32-bond-wwan0-slave.network ${D}${systemd_unitdir}/network/32-bond-wwan0-slave.network
    install -m 0644 ${UNPACKDIR}/33-bond-wwan1-slave.network ${D}${systemd_unitdir}/network/33-bond-wwan1-slave.network

    # Override phosphor-networkd's generic catch-all file with a no-op match
    # so the bond/slave topology is the only active policy for this profile.
    install -m 0644 ${UNPACKDIR}/60-phosphor-networkd-default.network \
        ${D}${sysconfdir}/systemd/network/60-phosphor-networkd-default.network
}

do_install:append:evb-rpi5-64() {
    install -d ${D}${systemd_unitdir}/network
    install -d ${D}${sysconfdir}/systemd/network

    install -m 0644 ${UNPACKDIR}/10-bond0.netdev ${D}${systemd_unitdir}/network/10-bond0.netdev
    install -m 0644 ${UNPACKDIR}/20-bond0.network ${D}${systemd_unitdir}/network/20-bond0.network
    install -m 0644 ${UNPACKDIR}/30-bond-en-slave.network ${D}${systemd_unitdir}/network/30-bond-en-slave.network
    install -m 0644 ${UNPACKDIR}/31-bond-eth-slave.network ${D}${systemd_unitdir}/network/31-bond-eth-slave.network
    install -m 0644 ${UNPACKDIR}/32-bond-wwan0-slave.network ${D}${systemd_unitdir}/network/32-bond-wwan0-slave.network
    install -m 0644 ${UNPACKDIR}/33-bond-wwan1-slave.network ${D}${systemd_unitdir}/network/33-bond-wwan1-slave.network

    install -m 0644 ${UNPACKDIR}/60-phosphor-networkd-default.network \
        ${D}${sysconfdir}/systemd/network/60-phosphor-networkd-default.network
}

FILES:${PN}:append:evb-rpi4-64 = " \
    ${systemd_unitdir}/network/10-bond0.netdev \
    ${systemd_unitdir}/network/20-bond0.network \
    ${systemd_unitdir}/network/30-bond-en-slave.network \
    ${systemd_unitdir}/network/31-bond-eth-slave.network \
    ${systemd_unitdir}/network/32-bond-wwan0-slave.network \
    ${systemd_unitdir}/network/33-bond-wwan1-slave.network \
    ${sysconfdir}/systemd/network/60-phosphor-networkd-default.network \
"

FILES:${PN}:append:evb-rpi5-64 = " \
    ${systemd_unitdir}/network/10-bond0.netdev \
    ${systemd_unitdir}/network/20-bond0.network \
    ${systemd_unitdir}/network/30-bond-en-slave.network \
    ${systemd_unitdir}/network/31-bond-eth-slave.network \
    ${systemd_unitdir}/network/32-bond-wwan0-slave.network \
    ${systemd_unitdir}/network/33-bond-wwan1-slave.network \
    ${sysconfdir}/systemd/network/60-phosphor-networkd-default.network \
"
