# Disable OEM IPMI command providers unconditionally.
PACKAGECONFIG:remove = " \
	oem-providers \
	transport-oem \
"

# Keep OEM provider list empty defensively.
OBMC_ORG_IPMI_OEM_PROVIDERS = ""
