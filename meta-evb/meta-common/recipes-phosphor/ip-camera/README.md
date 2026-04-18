EVB IP Camera Redfish 与电源控制设计
=====================================

概述
----

本文定义了 OpenBMC EVB 在以下两个方面的设计：

1. 通过 Redfish 对外暴露受管 IP 摄像头。
2. 通过独立的继电器服务控制摄像头电源。

本设计包含两个彼此独立的后端服务：

1. `dbus-ip-camera`
   - 自动扫描目标子网并发现摄像头，支持 ONVIF 探测、RTSP 探测、端口探测和 Ping 探测等组合策略。
   - 发现并管理 ONVIF 摄像头。
   - 从 `go2rtc` 导入流信息。
   - 实时更新摄像头在线状态，并在 D-Bus 上暴露摄像头清单、运行状态、资产信息、流清单以及凭据写入操作。
2. `ip-camera-power-control`
   - 通过可配置继电器 GPIO 控制摄像头电源。
   - 在 D-Bus 上暴露电源状态和电源动作。
   - 不负责摄像头发现、流清单和 ONVIF 交互。

`bmcweb` 消费上述两个服务，并为每个摄像头呈现一个统一的 OEM Redfish 视图。

目标
----

1. 在 Manager OEM 下为受管 IP 摄像头提供稳定的 Redfish 模型。
2. 将摄像头发现与继电器电源控制保持在不同服务中。
3. 支持可配置的继电器路数以及可配置的每摄像头路由映射。
4. 同时支持单继电器模式和上电/下电分离继电器模式。
5. 在不强行定义不存在的标准摄像头 schema 的前提下，尽量复用 Redfish 命名模式。
6. 通过多策略发现机制维持摄像头在线状态的低延迟更新，并避免发现风暴。
7. 支持市面上常见网络摄像头并保持跨厂商兼容性。

非目标
------

1. 不定义伪造的 DMTF 标准摄像头资源。
2. 不将继电器 GPIO 控制放入 `dbus-ip-camera`。
3. 不通过 Redfish 暴露密码或其他敏感信息。
4. 不要求基础摄像头发现和流枚举必须依赖电源控制服务。

架构
----

系统分为三层：

1. 摄像头管理层
   - 服务名：`xyz.openbmc_project.IpCamera`
   - 负责摄像头发现、刷新、凭据设置以及流导入/移除。
2. 摄像头电源层
   - 服务名：`xyz.openbmc_project.IpCamera.PowerControl`
   - 负责基于继电器的电源状态与电源动作。
3. Redfish 聚合层
   - 由 `bmcweb` 实现。
   - 将两个服务中的摄像头信息合并为单一 OEM 摄像头资源。

关键设计规则：从摄像头管理服务视角看，电源控制是可选能力。若某摄像头缺少对应的电源控制 D-Bus 对象，摄像头资源仍应有效，仅报告“不支持电源控制”。

发现策略与状态机
----------------

本章节定义 `dbus-ip-camera` 的自动发现与在线状态收敛机制，目标是“快速发现、稳定判定、可审计回溯”。

发现范围与触发
~~~~~~~~~~~~~~

1. 扫描范围
   - 支持配置一个或多个 IPv4 子网段。
   - 支持显式地址白名单与黑名单。
2. 触发方式
   - 周期性后台扫描（默认开启）。
   - 通过 Redfish Action 手动触发全量发现。
   - 对单摄像头执行定向刷新。
3. 并发与限速
   - 子网扫描采用固定并发上限，避免挤占 BMC 资源。
   - 对单目标地址采用最小重试间隔和指数退避。

多策略发现流水线
~~~~~~~~~~~~~~~~

每个候选地址按以下顺序执行探测，任一策略命中后进入规范化与去重阶段：

1. Ping 探测
   - 判断目标地址可达性并记录基础延迟。
2. 端口探测
   - 检查 ONVIF 常见端口和 RTSP 常见端口可达性。
3. ONVIF 探测
   - 优先执行 ONVIF 能力探测与设备信息读取。
4. RTSP 探测
   - 对未完成识别的地址尝试 RTSP 可用性探测。

建议策略：ONVIF 为主、RTSP 为辅、Ping 与端口探测用于加速候选筛选和在线性判断。

身份规范化与去重
~~~~~~~~~~~~~~~~

1. 统一标识
   - 使用与现有实现一致的 slug 规则将地址规范化为 `CameraId`。
2. 去重优先级
   - 若 ONVIF `HardwareId` 可用，优先以 `HardwareId` 去重。
   - 否则以规范化地址作为去重键。
3. 冲突处理
   - 同一 `HardwareId` 出现多地址时，仅保留最近可用且认证通过的目标。
   - 冲突事件写入 `LastError`，并保留可审计日志。

在线状态机
~~~~~~~~~~

状态机基于 `Present`、`Functional`、`LastSeenUsec` 与最近错误进行收敛。

1. `Unknown`
   - 初始状态，尚无有效探测结果。
2. `Online`
   - 最近探测成功，且流或控制接口可访问。
3. `Degraded`
   - 地址可达，但 ONVIF/RTSP 部分能力失败或认证异常。
4. `Offline`
   - 连续探测失败达到阈值。
5. `Stale`
   - 超过新鲜度窗口未刷新，状态需要复核。

状态迁移建议：

1. `Unknown -> Online`
   - 任一主策略（ONVIF/RTSP）成功。
2. `Online -> Degraded`
   - 连续出现协议级失败，但目标仍可达。
3. `Degraded -> Online`
   - 关键能力恢复且连续成功达到恢复阈值。
4. `Online/Degraded -> Offline`
   - 探测失败计数超过下线阈值。
5. `Offline -> Online`
   - 任一主策略重新成功。
6. `Any -> Stale`
   - 超过 `stale_timeout_sec` 未收到成功刷新。

阈值与时间窗口（建议默认值）
~~~~~~~~~~~~~~~~~~~~~~~~~~~

1. `scan_interval_sec = 30`
2. `online_confirm_count = 1`
3. `offline_confirm_count = 3`
4. `recover_confirm_count = 2`
5. `stale_timeout_sec = 120`
6. `probe_timeout_ms = 1500`
7. `max_parallel_probes = 32`

实现要求：

1. 所有阈值与时间窗口必须可配置。
2. 配置变更后无需重启即可生效。
3. 配置必须持久化到 NV 存储，掉电或重启后不丢失。
4. 推荐采用“配置文件 + 运行时写回”模型：
   - 默认配置文件：`/etc/dbus-ip-camera/config.json`
   - 持久化状态文件：`/var/lib/dbus-ip-camera/config-state.json`
   - 运行时更新（例如通过 D-Bus Manager 接口）后，服务必须原子写回持久化文件。
5. 启动加载顺序：
   - 先加载持久化状态文件（若存在且合法）。
   - 若持久化文件不存在或损坏，则回退到默认配置文件并重新生成持久化文件。

反风暴与资源保护
~~~~~~~~~~~~~~~~

1. 分层限流
   - 子网级并发限流 + 目标级退避限流。
2. 抖动调度
   - 周期任务引入随机抖动，避免固定相位造成突发峰值。
3. 熔断保护
   - 当连续失败率超过阈值时，临时降低扫描频率。
4. 快速恢复
   - 网络恢复后先执行小批量预热探测，再恢复全量周期扫描。

D-Bus 与 Redfish 映射规则
~~~~~~~~~~~~~~~~~~~~~~~~~~

1. D-Bus 最小更新集
   - `Present`、`Functional`、`LastSeenUsec`、`LastRefreshUsec`、`LastError`、`AuthStatus`。
2. Redfish 状态映射
   - `Status.State` 与 `Status.Health` 使用本文既有映射规则。
3. 新鲜度语义
   - 当进入 `Stale` 时，`Status.Health` 至少降为 `Warning`。
4. 非阻塞聚合
   - 电源控制对象缺失不影响摄像头资源返回。

可观测性与审计
~~~~~~~~~~~~~~

1. 必须记录
   - 探测开始/结束、策略命中、状态迁移、认证失败、冲突合并。
2. 统计项
   - 在线率、发现耗时分位、失败率、重试次数、每策略命中率。
3. 故障定位
   - 每个摄像头保留最近一次失败原因和时间戳。

安全与隐私约束
~~~~~~~~~~~~~~

1. 不在日志或 Redfish 返回中输出密码。
2. 认证失败仅返回可操作错误码与摘要，不泄露敏感细节。
3. 扫描策略应允许禁用高噪声探测方式（例如仅启用 ONVIF）。

常见网络摄像头兼容性要求
------------------------

本方案需面向市面常见网络摄像头型号，优先保证 ONVIF 生态兼容。

兼容性基线：

1. 发现兼容
   - 支持通过 ONVIF 设备发现识别主流厂商摄像头。
   - 支持对仅暴露 RTSP 的设备进行补充识别与纳管。
2. 认证兼容
   - 支持常见用户名/密码认证流程。
   - 认证失败必须返回可操作错误状态，不得静默失败。
3. 流能力兼容
   - 至少支持主码流 RTSP URL 导入。
   - 若设备支持快照或多 Profile，允许按 OEM 扩展字段表达。
4. 在线状态兼容
   - 对不同厂商设备统一输出 `Present`、`Functional`、`Status` 语义。
   - 不因厂商私有字段缺失而导致资源不可用。
5. 降级策略
   - ONVIF 部分能力缺失时，允许以 RTSP-only 模式纳管。
   - 仅当核心能力（可达性与基础流）均不可用时标记为 Offline。

验收建议（兼容性最小集合）：

1. 至少选取 3 家以上主流厂商、每家 1 到 2 个型号进行实机验证。
2. 覆盖 ONVIF 完整设备、RTSP-only 设备、弱网场景设备三类样本。
3. 验证项包括：发现、凭据更新、流导入、在线状态收敛、Redfish 读取一致性。

为什么使用 OEM Redfish
-----------------------

目前 DMTF Redfish 并无针对 IP 摄像头清单或 ONVIF 摄像头管理的标准资源。现有标准 schema（如 Manager、Resource、Assembly、ManagerNetworkProtocol、ManagerAccount）仅提供命名指导，无法组成完整摄像头模型。

因此本设计在 Manager OEM 下定义以下 OEM 资源族：

1. `OpenBMCIpCameraCollection.v1_0_0.IpCameraCollection`
2. `OpenBMCIpCamera.v1_0_0.IpCamera`
3. `OpenBMCIpCameraStream.v1_0_0.IpCameraStream`

Redfish 资源布局
----------------

摄像头资源位于 BMC manager 的 OEM 子树下：

1. 集合资源
   - `/redfish/v1/Managers/bmc/Oem/OpenBmc/IpCameras`
2. 摄像头成员资源
   - `/redfish/v1/Managers/bmc/Oem/OpenBmc/IpCameras/{CameraId}`
3. 流集合资源
   - `/redfish/v1/Managers/bmc/Oem/OpenBmc/IpCameras/{CameraId}/Streams`
4. 流成员资源
   - `/redfish/v1/Managers/bmc/Oem/OpenBmc/IpCameras/{CameraId}/Streams/{StreamId}`

`CameraId` 使用与 `dbus-ip-camera` 一致的地址规范化规则生成 slug。

Schema 定义
-----------

IpCameraCollection
~~~~~~~~~~~~~~~~~~

属性：

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

动作：

1. `#OpenBMCIpCameraCollection.Discover`
2. `#OpenBMCIpCameraCollection.RefreshAll`

IpCamera
~~~~~~~~

以下属性按功能分组，均在单个摄像头资源上返回。

身份与寻址信息：

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

资产与设备信息：

1. `Manufacturer`
2. `Model`
3. `PartNumber`
4. `SerialNumber`
5. `BuildDate`

发现与健康信息：

1. `Present`
2. `Functional`
3. `LastSeenUsec`
4. `LastRefreshUsec`
5. `LastError`
6. `AuthStatus`
7. `SnapshotSupport`
8. `RawInfo`
9. `Status`

`Status` 是面向客户端的状态汇总，Redfish 消费方应优先使用该字段。

`Status.State` 映射：

1. `Enabled`
   - 摄像头存在、功能正常，且电源为 On，或未使用电源控制。
2. `StandbyOffline`
   - 摄像头已配置，存在电源控制对象，且电源为 Off。
3. `UnavailableOffline`
   - 摄像头已配置但功能异常，或通信失败。
4. `Absent`
   - 摄像头对象存在于配置中，但当前未在线。

`Status.Health` 映射：

1. `OK`
   - 摄像头功能正常，且无电源控制错误。
2. `Warning`
   - 摄像头存在但未完全正常，或最近一次操作产生了非致命错误。
3. `Critical`
   - 电源控制操作失败，导致当前电源状态不可被信任。

协议与流信息：

1. `StreamNames`
2. `Streams`
3. `Streams@odata.count`
4. `Protocols`

`Protocols` 是 OEM 对象，用于按协议分组访问信息。

建议结构：

1. `Protocols.Onvif`
   - `ProtocolEnabled`
   - `Url`
2. `Protocols.Rtsp`
   - `ProtocolEnabled`
   - `Url`
3. `Protocols.Snapshot`
   - `ProtocolEnabled`
   - `Url`

若某协议存在多个 URL 或 profile 级别数据，可在对应协议对象内部扩展 OEM 字段。

认证信息：

1. `Authentication`

建议字段：

1. `Authentication.UserName`
   - 可选。仅当后端明确暴露时返回。
2. `Authentication.PasswordConfigured`
   - 布尔值。
3. `Authentication.AuthStatus`
   - 与后端认证状态保持一致。

安全规则：

1. Redfish 必须绝不返回密码明文。

电源控制信息：

1. `PowerState`
2. `PowerControlSupported`
3. `PowerControlMode`
4. `Relay`
5. `PowerOnRelay`
6. `PowerOffRelay`
7. `PowerControlLastError`

字段语义：

1. `PowerState`
   - `On` 或 `Off`
2. `PowerControlSupported`
   - 若存在该摄像头对应的电源控制 D-Bus 对象则为 `true`
3. `PowerControlMode`
   - `level`：单继电器控制电平式电源状态
   - `separate`：上电/下电脉冲继电器分离
4. `Relay`
   - `level` 模式下使用的单继电器路号
5. `PowerOnRelay`
   - `separate` 模式下用于上电脉冲的路号
6. `PowerOffRelay`
   - `separate` 模式下用于下电脉冲的路号
7. `PowerControlLastError`
   - 最近一次电源操作失败的错误描述字符串（若存在）

动作：

1. `#OpenBMCIpCamera.Refresh`
2. `#OpenBMCIpCamera.ImportStreams`
3. `#OpenBMCIpCamera.DeleteStreams`
4. `#OpenBMCIpCamera.SetCredentials`
5. `#OpenBMCIpCamera.PowerOn`
6. `#OpenBMCIpCamera.PowerOff`

`PowerOn` 与 `PowerOff` 仍为 OEM 动作，不复用 Redfish `Reset`，因为其语义是对摄像头继电器进行直接电源控制，而非系统复位。

IpCameraStream
~~~~~~~~~~~~~~

属性：

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

动作：

1. `#OpenBMCIpCameraStream.Import`
2. `#OpenBMCIpCameraStream.Remove`

D-Bus 契约
----------

摄像头管理服务
~~~~~~~~~~~~~~

现有服务：

1. 服务：`xyz.openbmc_project.IpCamera`
2. 管理路径：`/xyz/openbmc_project/ip_camera`

Redfish 设计已使用的现有接口：

1. `xyz.openbmc_project.IpCamera.Manager`
2. `xyz.openbmc_project.IpCamera.Device`
3. `xyz.openbmc_project.IpCamera.Stream`
4. `xyz.openbmc_project.Inventory.Item`
5. `xyz.openbmc_project.State.Decorator.OperationalStatus`
6. `xyz.openbmc_project.Inventory.Decorator.Asset`

电源控制服务
~~~~~~~~~~~~

规划中的服务：

1. 服务：`xyz.openbmc_project.IpCamera.PowerControl`
2. 管理路径：`/xyz/openbmc_project/ip_camera_power_control`
3. 每摄像头路径：
   - `/xyz/openbmc_project/ip_camera_power_control/{CameraId}`

管理接口：

1. `xyz.openbmc_project.IpCamera.PowerControl.Manager`

建议属性：

1. `RelayCount`
   - 可用继电器路数
2. `Cameras`
   - 已配置摄像头对象路径数组

每摄像头接口：

1. `xyz.openbmc_project.IpCamera.PowerControl.Device`

建议属性：

1. `CameraId`
2. `Mode`
   - `level` 或 `separate`
3. `Relay`
4. `PowerOnRelay`
5. `PowerOffRelay`
6. `PowerState`
   - `On` 或 `Off`
7. `PowerControlSupported`
8. `LastError`

建议方法：

1. `PowerOn()`
2. `PowerOff()`

电源控制配置
------------

继电器服务采用配置驱动，以便在不修改服务代码的情况下调整板级路数和路由分配。

建议配置文件：

1. `/etc/ip-camera-power-control/config.json`

建议顶层字段：

1. `relay_count`
   - 可配置继电器总路数
2. `defaults`
   - 默认继电器行为与 GPIO 后端选项
3. `relays`
   - 每一路的 GPIO 映射
4. `cameras`
   - 每个摄像头的路由分配与控制模式
5. `state_path`
   - 脉冲模式电源状态跟踪的持久化状态文件

建议配置结构：

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

配置规则：

1. 所有被引用路号必须在 `1..relay_count` 范围内。
2. `level` 模式摄像头必须定义 `relay`。
3. `separate` 模式摄像头必须定义 `power_on_relay` 和 `power_off_relay`。
4. 摄像头键值应按 `dbus-ip-camera` 使用的同一 slug 规则规范化，或服务在创建 D-Bus 对象前自行完成规范化。

FRU 驱动的板型配置与 Entity Manager 主板描述
------------------------------------------

本设计要求将板载硬件能力与 GPIO 资源映射写入 Entity Manager 的主板描述 JSON，并通过 FRU 信息自动选择对应板型配置。

设计目标
~~~~~~~~

1. 通过 FRU 区分不同板型，自动加载对应主板描述。
2. 在主板描述中统一声明以下能力与资源映射：
    - 板载传感器
    - GPS/北斗定位
    - 摄像头电源继电器 GPIO 配置
    - 风扇
    - 湿度传感器
    - 温度传感器
    - 继电器开关状态采集
3. 避免在应用服务中硬编码板级差异。

FRU 匹配与加载规则
~~~~~~~~~~~~~~~~~~

1. 板型识别字段
    - 使用 FRU 的 `Board Manufacturer`、`Board Product Name`、`Board Part Number`、`Board Serial Number` 作为匹配输入。
2. 匹配优先级
    - `Board Product Name + Board Part Number` 精确匹配优先。
    - 若缺失 `Part Number`，回退到 `Board Product Name`。
    - 仍不匹配时加载默认板型描述。
3. 加载行为
    - 仅加载一个最终板型描述，避免多板型配置叠加产生冲突。
    - 加载结果需可观测并记录到日志，便于现场排障。

主板描述 JSON 必含内容
~~~~~~~~~~~~~~~~~~~~~~

以下信息必须写入 Entity Manager 主板描述 JSON：

1. 板载传感器定义
    - 温度、湿度、风扇转速等传感器对象。
    - 采样周期、单位、告警阈值与告警方向。
2. GNSS 定位能力
    - GPS 与北斗启用状态、设备路径、波特率、数据源类型。
    - 有效性判定阈值（如定位年龄、精度阈值）。
3. 继电器 GPIO 映射
    - 每路继电器对应 `gpiochip` 与 `line`。
    - `active_low`、脉冲宽度、上/下电稳定等待时间。
4. 继电器开关状态采集
    - 每路继电器的状态读回输入映射（若硬件支持）。
    - 读回状态与命令状态不一致时的告警策略。
5. 摄像头电源路由能力
    - 支持的控制模式（`level` 或 `separate`）。
    - 可用继电器路数与可分配策略。

建议字段模型（示例）
~~~~~~~~~~~~~~~~~~~~

```json
{
   "BoardProfile": {
      "Match": {
         "BoardProductName": "EVB-RPI5-CAMERA",
         "BoardPartNumber": "EVB-IPC-001"
      },
      "Sensors": {
         "Temperature": [
            {
               "Name": "BoardTemp0",
               "Bus": 1,
               "Address": "0x48",
               "WarnHigh": 85,
               "CritHigh": 95
            }
         ],
         "Humidity": [
            {
               "Name": "BoardHumidity0",
               "Bus": 1,
               "Address": "0x40",
               "WarnHigh": 85
            }
         ],
         "Fan": [
            {
               "Name": "Fan0",
               "Pwm": 0,
               "RpmLow": 1200
            }
         ]
      },
      "Gnss": {
         "GpsEnabled": true,
         "BeiDouEnabled": true,
         "Device": "/dev/ttyS1",
         "Baudrate": 115200,
         "MaxFixAgeSec": 10,
         "MaxHdop": 3.0
      },
      "Relay": {
         "RelayCount": 4,
         "Defaults": {
            "Chip": "gpiochip0",
            "ActiveLow": false,
            "PulseMs": 250,
            "SettleDelayMs": 500
         },
         "Routes": {
            "1": { "Line": 17, "StateLine": 5 },
            "2": { "Line": 18, "StateLine": 6 },
            "3": { "Line": 27, "StateLine": 13 },
            "4": { "Line": 22, "StateLine": 19 }
         },
         "Modes": ["level", "separate"]
      }
   }
}
```

实现约束
~~~~~~~~

1. FRU 仅用于板型识别与配置选择，不承载运行态状态数据。
2. 运行态数据（如继电器当前开关状态、GNSS 最近定位）必须由运行时服务维护并通过 D-Bus 暴露。
3. 主板描述 JSON 中的资源映射变更必须可审计，且更新后需有明确重载流程。
4. 不同板型之间不得复用冲突 GPIO 映射，冲突应在加载阶段报错并拒绝启用。

bmcweb 中的 Redfish 聚合规则
-----------------------------

`bmcweb` 组装每个摄像头响应时应遵循以下规则：

1. 从 `xyz.openbmc_project.IpCamera.Device` 读取摄像头核心属性。
2. 从 `xyz.openbmc_project.Inventory.Item` 读取存在状态。
3. 从 `xyz.openbmc_project.State.Decorator.OperationalStatus` 读取运行状态。
4. 从 `xyz.openbmc_project.Inventory.Decorator.Asset` 读取资产数据。
5. 尝试从 `xyz.openbmc_project.IpCamera.PowerControl.Device` 读取电源属性。
6. 若电源对象不存在：
   - 返回摄像头资源，且请求不失败。
   - 将 `PowerControlSupported` 置为 `false`。
   - 不暴露电源动作。
7. 若电源对象存在：
   - 填充电源相关字段。
   - 暴露 `PowerOn` 与 `PowerOff` 动作。
   - 结合摄像头健康状态和电源状态推导 `Status.State`。

摄像头资源示例
--------------

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

待确认问题
----------

1. 是否需要返回 `Authentication.UserName`。
2. `Protocols` 应仅由当前流数据生成，还是应结合流数据与原始 ONVIF 信息共同生成。
3. 对于脉冲模式摄像头，除持久化 `state_path` 外，重启后是否还需要显式状态对账机制。
4. 路号是否应按配置原样暴露，或后续转换为板级本地标签。

实现指导
--------

1. 保持该 schema 稳定，后续仅通过新增可选字段演进。
2. 避免将电源控制重新并回 `dbus-ip-camera`。
3. 将“缺少电源控制 D-Bus 对象”视为受支持部署模式。
4. 优先提供单一且一致的 Redfish 摄像头资源，而不是拆成多个零散 OEM 子资源。
