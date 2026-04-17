# Avoid pulling rsyslog from phosphor-sel-logger runtime dependencies.
PACKAGECONFIG:append = " send-to-logger"
