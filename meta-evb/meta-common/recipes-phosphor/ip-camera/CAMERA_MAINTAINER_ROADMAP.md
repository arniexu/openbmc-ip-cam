OpenBMC Camera Maintainer Roadmap
=================================

Purpose
-------

This roadmap defines how to keep the OpenBMC EVB image trimmed into a dedicated
camera maintainer platform while preserving core manageability and security.

Target Features
---------------

1. NV settings persistence
2. Centralized camera status via Redfish (control center and mobile)
3. Remote camera power control
4. RTSP pull stream support
5. ONVIF camera configuration
6. Camera auto discovery
7. Camera online/offline status detection
8. Multi-bearer networking (Ethernet, 4G, 5G)
9. GNSS location (GPS/BeiDou)
10. Multi-channel RS485/RS232 communication support
11. Modern camera operations web page

Current Coverage In Repository
------------------------------

1. NV settings persistence
   - Implemented in `dbus-ip-camera` state file:
     - `/var/lib/dbus-ip-camera/state.json`
   - Config defaults in:
     - `meta-evb/meta-common/recipes-phosphor/ip-camera/files/config.json`

2. RTSP pull stream support
   - Implemented through go2rtc stream import/reconcile in:
     - `meta-evb/meta-common/recipes-phosphor/ip-camera/files/dbus-ip-camera`
   - go2rtc recipe and service in:
     - `meta-evb/meta-common/recipes-multimedia/go2rtc/`

3. ONVIF camera configuration
   - Add/refresh/set credentials methods in camera D-Bus service.
   - ONVIF discovery/profile fetch via go2rtc API.

4. Auto discovery
   - Discovery loop in `dbus-ip-camera`.
   - Optional periodic discovery helper in go2rtc layer.

5. Online/offline status detection
   - Present/Functional/LastSeenUsec/LastError already surfaced on D-Bus.

6. Centralized status and remote power
    - Redfish aggregation model for cameras and power already defined in:
       - `meta-evb/meta-common/recipes-phosphor/ip-camera/README.md`
    - Power-control D-Bus/Redfish integration pattern is documented and ready
       for service implementation wiring.

7. Image trim for camera platform
   - Camera-focused image feature removals:
     - `meta-evb/meta-common/recipes-phosphor/images/obmc-phosphor-image.bbappend`
   - Camera package inclusion for Raspberry Pi targets:
     - `meta-evb/meta-common/conf/machine/include/evb-rpi-camera-common.inc`

8. Linux netdev abstraction and bonding baseline
    - Added phosphor-network overlay for EVB RPi camera targets:
       - `meta-evb/meta-common/recipes-phosphor/network/phosphor-network_%.bbappend`
    - Added bond topology config files:
       - `10-bond0.netdev`, `20-bond0.network`
       - `30-bond-en-slave.network`, `31-bond-eth-slave.network`
       - `32-bond-wwan0-slave.network`, `33-bond-wwan1-slave.network`
    - Disabled generic catch-all network policy for this profile via:
       - `60-phosphor-networkd-default.network` override in `/etc/systemd/network`

Gap To Complete
---------------

1. Web UX
   - Add camera-focused pages/cards for discovery, status, credentials, and
     stream controls.
   - Suggested path: bmcweb/webui-vue OEM page backed by existing Redfish OEM
     camera resources.

2. Status quality
   - Add explicit stale-timeout policy so camera status transitions to offline
     when no successful refresh occurs within policy window.

3. Multi-bearer networking
   - Use standard Linux netdev abstraction for Ethernet/4G/5G interfaces.
   - Build a bonding topology (bond0 + slave interfaces) for unified uplink,
      preferred path policy, and failover status in Redfish OEM.

4. GNSS location support
    - Add GPS/BeiDou ingestion path with validity, timestamp, and confidence
       fields; expose in Redfish OEM camera platform status.

5. Multi-channel RS485/RS232 support
    - Add per-port configuration model (baud/parity/stopbits/protocol) and
       telemetry (link state/rx tx counters/errors), exposed via D-Bus + Redfish.

6. Optional settings integration
   - If required by product policy, mirror key camera-manager knobs into a
     phosphor-settings backed schema for consistent NV behavior across services.

Recommended Work Plan
---------------------

1. Backend hardening
   - Add stale timeout config and offline transition behavior.
   - Add small status counters/metrics for discovery and auth failures.

2. Redfish alignment
   - Ensure OEM camera Redfish payload includes status summary and protocol
     readiness fields consumed by UI.

3. Web UI implementation
   - Create a dedicated camera maintainer dashboard with:
     - Health tiles (online/offline/auth failed)
     - Camera table with quick actions
     - Discovery controls and last scan details
     - Stream readiness panel and RTSP links

4. Connectivity and location integration
    - Introduce a connectivity panel for Ethernet/4G/5G with active uplink,
       signal quality, and failover event timeline.
    - Add GNSS panel showing GPS/BeiDou fix status, coordinates, timestamp,
       and data freshness.

5. Serial integration
    - Introduce RS485/RS232 multi-port panel with per-port configuration,
       online state, and protocol bridge status.

6. Trim verification
   - Build image and verify required services only.
   - Confirm no removed feature is still pulled as dependency.

Validation Checklist
--------------------

1. Build succeeds for target machine.
2. `go2rtc` and `dbus-ip-camera` are active after boot.
3. Discovery finds ONVIF cameras without duplicates.
4. Credential update path refreshes status and stream inventory.
5. Offline camera transitions are visible in D-Bus and Redfish.
6. Remote power actions are available from Redfish and reflected in camera
   status transitions.
7. Ethernet/4G/5G link state and uplink selection are visible via Redfish.
8. GPS/BeiDou location status includes validity and timestamp.
9. RS485/RS232 channels can be independently configured and monitored.
10. Web page renders correctly on desktop and mobile.

Suggested OEM Redfish Extension Blocks
--------------------------------------

1. `Connectivity`
   - `Links`: Ethernet/Cellular(4G/5G) state list
   - `ActiveUplink`: active route name
   - `FailoverState`: normal/switching/degraded

2. `Location`
   - `Gnss.Enabled`
   - `Gnss.Constellations`: `GPS`, `BeiDou`
   - `Gnss.FixValid`, `Latitude`, `Longitude`, `Altitude`, `Timestamp`

3. `SerialInterfaces`
   - list of RS485/RS232 ports with static config and runtime telemetry
