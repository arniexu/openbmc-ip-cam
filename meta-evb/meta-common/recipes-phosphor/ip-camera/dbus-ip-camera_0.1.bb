SUMMARY = "D-Bus IP camera manager backed by go2rtc"
DESCRIPTION = "Discovers ONVIF cameras through go2rtc, persists configuration, and exposes inventory-style D-Bus objects."
HOMEPAGE = "https://github.com/openbmc/openbmc"
SECTION = "base"

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

LICENSE = "Apache-2.0"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/Apache-2.0;md5=89aea4e17d99a7cacdbeed46a0096b10"

SRC_URI = " \
	file://dbus-ip-camera \
	file://dbus-ip-camera.service \
	file://config.json \
	"

S = "${UNPACKDIR}"

inherit allarch systemd

RDEPENDS:${PN} += " \
	go2rtc \
	python3-asyncio \
	python3-core \
	python3-dbus-next \
	python3-json \
	python3-logging \
	python3-netclient \
	"

SYSTEMD_SERVICE:${PN} = "dbus-ip-camera.service"

CONFFILES:${PN} += "${sysconfdir}/dbus-ip-camera/config.json"

do_install() {
	install -d ${D}${bindir}
	install -d ${D}${sysconfdir}/dbus-ip-camera
	install -d ${D}${systemd_system_unitdir}

	install -m 0755 ${UNPACKDIR}/dbus-ip-camera ${D}${bindir}/dbus-ip-camera
	install -m 0644 ${UNPACKDIR}/config.json ${D}${sysconfdir}/dbus-ip-camera/config.json
	install -m 0644 ${UNPACKDIR}/dbus-ip-camera.service ${D}${systemd_system_unitdir}/dbus-ip-camera.service
}