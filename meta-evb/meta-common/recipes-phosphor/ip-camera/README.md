EVB IP Camera Redfish And Power Control Design
==============================================

Overview
--------

This document defines the OpenBMC EVB design for exposing managed IP cameras
through Redfish and for controlling camera power through a separate relay-based
service.

The design has two independent backends:

1. `dbus-ip-camera`
   - Discovers and manages ONVIF cameras.
   - Imports stream information from `go2rtc`.
   - Exposes camera inventory, operational status, asset information, stream
     inventory, and credential write operations on D-Bus.
2. `ip-camera-power-control`
   - Controls camera power by driving configurable relay GPIOs.
   - Exposes power state and power actions on D-Bus.
   - Does not own camera discovery, stream inventory, or ONVIF interactions.

`bmcweb` consumes both services and presents a single OEM Redfish view for each
camera.

Goals
-----

1. Provide a stable Redfish model for managed IP cameras under Manager OEM.
2. Keep camera discovery and relay power control in separate services.
3. Support configurable relay route count and configurable per-camera route
   mapping.
4. Allow both single-relay and separate on/off relay control modes.
5. Reuse Redfish naming patterns where possible without forcing a non-existent
   standard camera schema.

Non-goals
---------

1. Do not define a fake DMTF standard camera resource.
2. Do not put relay GPIO control into `dbus-ip-camera`.
3. Do not expose passwords or other secret material through Redfish.
4. Do not require the power-control service for basic camera discovery and
   stream enumeration.

Architecture
------------

The system is split into three layers.

1. Camera management layer
   - Service name: `xyz.openbmc_project.IpCamera`
   - Responsible for camera discovery, refresh, credential set, and stream
     import/remove.
2. Camera power layer
   - Service name: `xyz.openbmc_project.IpCamera.PowerControl`
   - Responsible for relay-backed power state and power actions.
3. Redfish aggregation layer
   - Implemented in `bmcweb`.
   - Merges camera information from both services into one OEM camera resource.

The important design rule is that power control is optional from the point of
view of the camera-management service. If the power-control D-Bus object for a
camera is absent, the camera resource remains valid and simply reports that
power control is unsupported.

Why OEM Redfish
---------------

There is no DMTF Redfish resource for IP camera inventory or ONVIF camera
management. Existing standard schemas such as Manager, Resource, Assembly,
ManagerNetworkProtocol, and ManagerAccount provide naming guidance, but not a
complete camera model.

For this reason, the design uses an OEM resource family under Manager OEM:

1. `OpenBMCIpCameraCollection.v1_0_0.IpCameraCollection`
2. `OpenBMCIpCamera.v1_0_0.IpCamera`
3. `OpenBMCIpCameraStream.v1_0_0.IpCameraStream`

Redfish Resource Layout
-----------------------

The camera resources are exposed under the BMC manager OEM subtree.

1. Collection
   - `/redfish/v1/Managers/bmc/Oem/OpenBmc/IpCameras`
2. Camera member
   - `/redfish/v1/Managers/bmc/Oem/OpenBmc/IpCameras/{CameraId}`
3. Stream collection
   - `/redfish/v1/Managers/bmc/Oem/OpenBmc/IpCameras/{CameraId}/Streams`
4. Stream member
   - `/redfish/v1/Managers/bmc/Oem/OpenBmc/IpCameras/{CameraId}/Streams/{StreamId}`

`CameraId` is the slug generated from the camera address using the same
normalization rule already used by `dbus-ip-camera`.

Schema Definition
-----------------

IpCameraCollection
~~~~~~~~~~~~~~~~~~

Properties:

1. `@odata.type`
   - `#OpenBMCIpCameraCollection.v1_0_0.IpCameraCollection`
2. `@odata.id`
3. `Name`
4. `Description`
5. `DiscoveryEnabled`
6. `PollIntervalSec`
7. `Members`
8. `Members@odata.count`
9. `Actions`

Actions:

1. `#OpenBMCIpCameraCollection.Discover`
2. `#OpenBMCIpCameraCollection.RefreshAll`

IpCamera
~~~~~~~~

Properties are grouped here by function. They are all returned on the single
camera resource.

Identity and addressing:

1. `@odata.type`
   - `#OpenBMCIpCamera.v1_0_0.IpCamera`
2. `@odata.id`
3. `Id`
4. `Name`
5. `Description`
6. `Address`
7. `Endpoint`
8. `Managed`
9. `HardwareId`
10. `FirmwareVersion`

Asset and device information:

1. `Manufacturer`
2. `Model`
3. `PartNumber`
4. `SerialNumber`
5. `BuildDate`

Discovery and health information:

1. `Present`
2. `Functional`
3. `LastSeenUsec`
4. `LastRefreshUsec`
5. `LastError`
6. `AuthStatus`
7. `SnapshotSupport`
8. `RawInfo`
9. `Status`

`Status` is the client-facing state summary and should be preferred by Redfish
consumers.

`Status.State` mapping:

1. `Enabled`
   - Camera is present, functional, and power is on or power control is not in
     use.
2. `StandbyOffline`
   - Camera is configured, power control exists, and power is off.
3. `UnavailableOffline`
   - Camera is configured but not functional or communication failed.
4. `Absent`
   - Camera object exists in configuration but is not currently present.

`Status.Health` mapping:

1. `OK`
   - Camera is functional and no power-control error is active.
2. `Warning`
   - Camera is present but not fully functional, or the latest operation
     produced a non-fatal error.
3. `Critical`
   - Power-control operation failed and the resulting power state cannot be
     trusted.

Protocol and stream information:

1. `StreamNames`
2. `Streams`
3. `Streams@odata.count`
4. `Protocols`

`Protocols` is an OEM object used to group access information by protocol.

Recommended structure:

1. `Protocols.Onvif`
   - `ProtocolEnabled`
   - `Url`
2. `Protocols.Rtsp`
   - `ProtocolEnabled`
   - `Url`
3. `Protocols.Snapshot`
   - `ProtocolEnabled`
   - `Url`

If a protocol has multiple URLs or profile-specific data, those can be added as
OEM extension fields inside the relevant protocol object.

Authentication information:

1. `Authentication`

Recommended fields:

1. `Authentication.UserName`
   - Optional. Present only if the backend explicitly exposes it.
2. `Authentication.PasswordConfigured`
   - Boolean.
3. `Authentication.AuthStatus`
   - Mirrors backend authentication state.

Security rule:

1. Passwords must never be returned by Redfish.

Power-control information:

1. `PowerState`
2. `PowerControlSupported`
3. `PowerControlMode`
4. `Relay`
5. `PowerOnRelay`
6. `PowerOffRelay`
7. `PowerControlLastError`

Field semantics:

1. `PowerState`
   - `On` or `Off`
2. `PowerControlSupported`
   - `true` if a matching power-control D-Bus object exists for the camera
3. `PowerControlMode`
   - `level` for one relay controlling asserted power state
   - `separate` for independent power-on and power-off pulse relays
4. `Relay`
   - Single-relay route number used by `level` mode
5. `PowerOnRelay`
   - Route number used for on pulse in `separate` mode
6. `PowerOffRelay`
   - Route number used for off pulse in `separate` mode
7. `PowerControlLastError`
   - String description of the last power operation failure, if any

Actions:

1. `#OpenBMCIpCamera.Refresh`
2. `#OpenBMCIpCamera.ImportStreams`
3. `#OpenBMCIpCamera.DeleteStreams`
4. `#OpenBMCIpCamera.SetCredentials`
5. `#OpenBMCIpCamera.PowerOn`
6. `#OpenBMCIpCamera.PowerOff`

`PowerOn` and `PowerOff` remain OEM actions and do not reuse the Redfish
`Reset` action because their semantics are direct camera relay control rather
than system reset semantics.

IpCameraStream
~~~~~~~~~~~~~~

Properties:

1. `@odata.type`
   - `#OpenBMCIpCameraStream.v1_0_0.IpCameraStream`
2. `@odata.id`
3. `Id`
4. `Name`
5. `ProfileToken`
6. `ProfileName`
7. `StreamName`
8. `StreamUrl`
9. `Snapshot`
10. `Actions`

Actions:

1. `#OpenBMCIpCameraStream.Import`
2. `#OpenBMCIpCameraStream.Remove`

D-Bus Contract
--------------

Camera management service
~~~~~~~~~~~~~~~~~~~~~~~~~

Existing service:

1. Service: `xyz.openbmc_project.IpCamera`
2. Manager path: `/xyz/openbmc_project/ip_camera`

Existing interfaces already used by the Redfish design:

1. `xyz.openbmc_project.IpCamera.Manager`
2. `xyz.openbmc_project.IpCamera.Device`
3. `xyz.openbmc_project.IpCamera.Stream`
4. `xyz.openbmc_project.Inventory.Item`
5. `xyz.openbmc_project.State.Decorator.OperationalStatus`
6. `xyz.openbmc_project.Inventory.Decorator.Asset`

Power-control service
~~~~~~~~~~~~~~~~~~~~~

Planned service:

1. Service: `xyz.openbmc_project.IpCamera.PowerControl`
2. Manager path: `/xyz/openbmc_project/ip_camera_power_control`
3. Per-camera path:
   - `/xyz/openbmc_project/ip_camera_power_control/{CameraId}`

Manager interface:

1. `xyz.openbmc_project.IpCamera.PowerControl.Manager`

Recommended properties:

1. `RelayCount`
   - Number of available relay routes
2. `Cameras`
   - Array of configured camera object paths

Per-camera interface:

1. `xyz.openbmc_project.IpCamera.PowerControl.Device`

Recommended properties:

1. `CameraId`
2. `Mode`
   - `level` or `separate`
3. `Relay`
4. `PowerOnRelay`
5. `PowerOffRelay`
6. `PowerState`
   - `On` or `Off`
7. `PowerControlSupported`
8. `LastError`

Recommended methods:

1. `PowerOn()`
2. `PowerOff()`

Power Control Configuration
---------------------------

The relay service is configuration driven so that board-specific route count and
route assignments can be changed without altering the service code.

Recommended configuration file:

1. `/etc/ip-camera-power-control/config.json`

Recommended top-level fields:

1. `relay_count`
   - Total number of configurable relay routes
2. `defaults`
   - Default relay behavior and GPIO backend options
3. `relays`
   - Per-route GPIO mapping
4. `cameras`
   - Per-camera route assignment and control mode
5. `state_path`
   - Persistent state file for pulse-mode power state tracking

Recommended configuration structure:

```json
{
  "relay_count": 4,
  "defaults": {
    "chip": "gpiochip0",
    "active_low": false,
    "pulse_ms": 250,
    "settle_delay_ms": 500
  },
  "relays": {
    "1": { "line": 17 },
    "2": { "line": 18 },
    "3": { "line": 27 },
    "4": { "line": 22 }
  },
  "cameras": {
    "192.168.1.101": {
      "mode": "level",
      "relay": 1
    },
    "192.168.1.102": {
      "mode": "separate",
      "power_on_relay": 2,
      "power_off_relay": 3
    }
  },
  "state_path": "/var/lib/ip-camera-power-control/state.json"
}
```

Configuration rules:

1. Every referenced route must be within `1..relay_count`.
2. A camera in `level` mode must define `relay`.
3. A camera in `separate` mode must define `power_on_relay` and
   `power_off_relay`.
4. Camera keys should be normalized by the same slug rule used by
   `dbus-ip-camera`, or the service should normalize them internally before
   creating D-Bus objects.

Redfish Aggregation Rules In bmcweb
-----------------------------------

`bmcweb` should assemble each camera response as follows.

1. Read camera core properties from `xyz.openbmc_project.IpCamera.Device`.
2. Read present state from `xyz.openbmc_project.Inventory.Item`.
3. Read operational state from
   `xyz.openbmc_project.State.Decorator.OperationalStatus`.
4. Read asset data from `xyz.openbmc_project.Inventory.Decorator.Asset`.
5. Attempt to read power properties from
   `xyz.openbmc_project.IpCamera.PowerControl.Device`.
6. If the power object does not exist:
   - Return the camera resource without failing the request.
   - Set `PowerControlSupported` to `false`.
   - Omit power actions.
7. If the power object exists:
   - Populate the power fields.
   - Expose `PowerOn` and `PowerOff` actions.
   - Derive `Status.State` using both camera health and power state.

Example Camera Resource
-----------------------

```json
{
  "@odata.type": "#OpenBMCIpCamera.v1_0_0.IpCamera",
  "@odata.id": "/redfish/v1/Managers/bmc/Oem/OpenBmc/IpCameras/192_168_1_101",
  "Id": "192_168_1_101",
  "Name": "Front Camera",
  "Address": "192.168.1.101",
  "Endpoint": "onvif://192.168.1.101/onvif/device_service",
  "Managed": true,
  "Manufacturer": "VendorA",
  "Model": "ModelX",
  "PartNumber": "PN-001",
  "SerialNumber": "SN-001",
  "FirmwareVersion": "1.2.3",
  "Present": true,
  "Functional": true,
  "AuthStatus": "Configured",
  "PowerState": "On",
  "PowerControlSupported": true,
  "PowerControlMode": "level",
  "Relay": 1,
  "Status": {
    "State": "Enabled",
    "Health": "OK"
  },
  "Protocols": {
    "Onvif": {
      "ProtocolEnabled": true,
      "Url": "onvif://192.168.1.101/onvif/device_service"
    },
    "Rtsp": {
      "ProtocolEnabled": true,
      "Url": "rtsp://192.168.1.101/stream"
    },
    "Snapshot": {
      "ProtocolEnabled": true,
      "Url": "http://192.168.1.101/snapshot.jpg"
    }
  },
  "Actions": {
    "#OpenBMCIpCamera.Refresh": {
      "target": "/redfish/v1/Managers/bmc/Oem/OpenBmc/IpCameras/192_168_1_101/Actions/IpCamera.Refresh"
    },
    "#OpenBMCIpCamera.PowerOn": {
      "target": "/redfish/v1/Managers/bmc/Oem/OpenBmc/IpCameras/192_168_1_101/Actions/IpCamera.PowerOn"
    },
    "#OpenBMCIpCamera.PowerOff": {
      "target": "/redfish/v1/Managers/bmc/Oem/OpenBmc/IpCameras/192_168_1_101/Actions/IpCamera.PowerOff"
    }
  }
}
```

Open Questions
--------------

1. Whether `Authentication.UserName` should be returned at all.
2. Whether `Protocols` should be materialized from current stream data only, or
   from both stream data and raw ONVIF information.
3. Whether pulse-mode cameras need an explicit state reconciliation mechanism on
   reboot beyond persisted `state_path` data.
4. Whether route numbers should be exposed exactly as configured or translated
   into board-local labels later.

Implementation Guidance
-----------------------

1. Keep this schema stable and evolve by adding optional fields only.
2. Avoid moving power control back into `dbus-ip-camera`.
3. Treat absent power-control D-Bus objects as a supported deployment mode.
4. Prefer exposing a single coherent Redfish camera resource over creating many
   thin OEM subresources.
