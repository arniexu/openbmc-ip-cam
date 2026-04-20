# Trim server-platform FRU sensor paths for camera-only O&M image.
PACKAGECONFIG:remove = " \
	intelcpusensor \
	psusensor \
	ipmbsensor \
	nvmesensor \
	smbpbi \
	nvidia-gpu \
	mctpreactor \
"
