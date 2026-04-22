FILESEXTRAPATHS:prepend := "${THISDIR}/${BPN}_${LINUX_VERSION}:"

SRC_URI:append = " \
    file://0001-arm64-dts-rockchip-add-rk3568-ok3568-c.patch \
"