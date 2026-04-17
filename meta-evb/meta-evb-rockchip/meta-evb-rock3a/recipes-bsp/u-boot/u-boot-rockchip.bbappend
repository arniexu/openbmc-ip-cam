# Allow image dependencies on "u-boot" to be satisfied by u-boot-rockchip.
PROVIDES:append = " u-boot"
RPROVIDES:${PN}:append = " u-boot"
