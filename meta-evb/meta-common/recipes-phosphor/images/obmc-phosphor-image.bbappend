WIC_CREATE_EXTRA_ARGS:append = " ${@'--no-fstab-update' if (d.getVar('CMDLINE_ROOT_PARTITION') or '').startswith('/dev/sd') else ''}"

# Camera operations platform trim for Raspberry Pi targets.
IMAGE_FEATURES:remove = " \
	obmc-bmc-state-mgmt \
	obmc-bmcweb \
	obmc-chassis-state-mgmt \
	obmc-console \
	obmc-debug-collector \
	obmc-devtools \
	obmc-dmtf-pmci \
	obmc-fan-control \
	obmc-health-monitor \
	obmc-host-ctl \
	obmc-host-ipmi \
	obmc-host-state-mgmt \
	obmc-ikvm \
	obmc-inventory \
	obmc-leds \
	obmc-logging-mgmt \
	obmc-net-ipmi \
	obmc-network-mgmt \
	obmc-remote-logging-mgmt \
	obmc-sensors \
	obmc-settings-mgmt \
	obmc-software \
	obmc-telemetry \
	obmc-tpm \
	obmc-user-mgmt \
	obmc-user-mgmt-ldap \
	obmc-webui \
"

