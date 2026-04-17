IMAGE_INSTALL:append = " go2rtc dbus-ip-camera"

PREFERRED_VERSION_libgpiod = "2.2.2"

# Keep a minimal local syslog provider without rsyslog.
VIRTUAL-RUNTIME_syslog = "busybox-syslog"