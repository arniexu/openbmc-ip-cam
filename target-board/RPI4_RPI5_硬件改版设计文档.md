# 树莓派4/树莓派5 硬件改版设计文档（可开工版）

## 1. 目标与约束

### 1.1 目标
- 基于树莓派4与树莓派5实现现有报警器主功能：
  - 8路继电器控制
  - 多路开关量输入（INPUT_1/2/3、OPEN_DOOR、WATER）
  - RS485 通讯
  - 风扇控制（2路）
  - 温湿度采集
  - 加速度采集
  - 基础状态指示

### 1.2 已确认约束
- 4G 使用 USB 4G 网卡
- 网络使用树莓派自带网口
- 不需要 SPI Flash 启动，使用 SD 卡启动
- GPIO 扩展使用树莓派兼容常用器件

---

## 2. 推荐总体架构

### 2.1 主控与总线
- 主控：Raspberry Pi 4B / Raspberry Pi 5（40Pin 头）
- 主总线：
  - I2C-1：用于 GPIO 扩展、PWM 扩展、传感器
  - SPI0：预留给计量/ADC（可选）
  - USB：4G 网卡、USB-RS485（推荐）

### 2.2 外设分层
- 数字输出（继电器）：MCP23017 -> ULN2803A -> 继电器阵列
- 数字输入（门磁/输入/漏水）：MCP23017 输入 + 光耦/比较器前端
- PWM/风扇：PCA9685 -> MOSFET 驱动
- 环境传感：AHT20（I2C）
- 运动传感：LIS3DH（I2C）
- RS485：USB-RS485 模块（优先）
- 4G：USB 4G 网卡（ECM/RNDIS/QMI）

---

## 3. 40Pin 引脚分配（Pi4/Pi5 通用）

> 说明：尽量减少树莓派直连 IO 数量，保证可维护性与抗干扰能力。

| PhysicalPin | BCM | Signal | Direction | Required | Notes |
|---|---|---|---|---|---|
| 1 | 3V3 | 3V3 | Power | Yes | Logic power |
| 2 | 5V | 5V | Power | Yes | Peripheral/driver power |
| 3 | GPIO2 | I2C1_SDA | Bidirectional | Yes | Main I2C bus |
| 4 | 5V | 5V | Power | Yes | Peripheral/driver power |
| 5 | GPIO3 | I2C1_SCL | Output | Yes | Main I2C bus |
| 6 | GND | GND | Power | Yes | Ground |
| 9 | GND | GND | Power | Yes | Ground |
| 11 | GPIO17 | IOEXP_INT | Input | Yes | MCP23017 interrupt input |
| 13 | GPIO27 | ALARM_INT | Input | No | Optional alarm summary |
| 14 | GND | GND | Power | Yes | Ground |
| 15 | GPIO22 | SYS_LED | Output | Yes | System status LED |
| 16 | GPIO23 | BUZZER_EN | Output | No | Optional buzzer control |
| 18 | GPIO24 | PWR_4G_EN | Output | No | Optional USB 4G power switch |
| 19 | GPIO10 | SPI0_MOSI | Output | No | Optional metering/ADC SPI |
| 20 | GND | GND | Power | Yes | Ground |
| 21 | GPIO9 | SPI0_MISO | Input | No | Optional metering/ADC SPI |
| 22 | GPIO25 | FAN_FAULT | Input | No | Optional fan fault input |
| 23 | GPIO11 | SPI0_SCLK | Output | No | Optional metering/ADC SPI |
| 24 | GPIO8 | SPI0_CE0 | Output | No | Optional metering/ADC chip select |
| 25 | GND | GND | Power | Yes | Ground |
| 30 | GND | GND | Power | Yes | Ground |
| 34 | GND | GND | Power | Yes | Ground |
| 39 | GND | GND | Power | Yes | Ground |

### 3.1 可回收引脚策略
- 若不使用 SPI 计量芯片，可释放 GPIO8/9/10/11
- 若告警由 MCP23017 统一中断，可释放 GPIO27
- 若不做 4G 上电控制，可释放 GPIO24

---

## 4. I2C 地址规划（防冲突）

| Device | AddressHex | Function | Required | Notes |
|---|---|---|---|---|
| MCP23017_1 | 0x20 | Relay outputs | Yes | 16-bit GPIO expander |
| MCP23017_2 | 0x21 | Digital inputs (INPUT/OPEN_DOOR/WATER) | Yes | INT pin connected to GPIO17 |
| PCA9685 | 0x40 | Fan PWM expansion | Yes | 2 channels used initially |
| AHT20 | 0x38 | Temperature/Humidity | Yes | I2C sensor |
| LIS3DH | 0x18 | Accelerometer | Yes | Alt address can be 0x19 |
| ADS1115 | 0x48 | Analog acquisition | No | Optional analog channels |

---

## 5. 功能到器件映射

### 5.1 继电器（8 路）
- 控制链路：树莓派 I2C -> MCP23017#1 -> ULN2803A -> Relay1~8
- 建议：继电器线圈电源独立（12V），与 3.3V 逻辑分区

### 5.2 开关量输入（INPUT_1/2/3、OPEN_DOOR、WATER）
- 输入前端：TVS + 限流 + 光耦（或比较器）
- 采集链路：前端 -> MCP23017#2 输入脚
- 中断：MCP23017#2 INT 输出到 GPIO17

### 5.3 RS485
- 推荐实现：USB-RS485（无需占用 UART 引脚）
- 备选实现：GPIO UART + 自动方向 485 芯片（如 MAX13487 类）

### 5.4 风扇（2 路）
- PWM：PCA9685 CH0/CH1
- 驱动：N-MOS + 续流保护 + TVS
- 可选：风扇测速反馈接 MCP23017#2

### 5.5 4G（USB）
- 采用 USB 4G 网卡，系统识别为 `wwan0` 或 `usb0`
- 建议增加：可控电源开关（GPIO24 -> 高边开关）

### 5.6 传感器
- AHT20、LIS3DH 全部挂 I2C，避免额外 GPIO 占用

---

## 6. 电源与保护建议

### 6.1 电源树
- 12V 输入 -> DCDC 5V（>=5A）-> 树莓派
- 12V -> 继电器/风扇电源
- 5V -> 3.3V LDO/DCDC（外设逻辑）

### 6.2 保护
- 外部接口：TVS（RS485、输入端子、风扇接口）
- 电源入口：保险丝 + 反接保护 + 浪涌抑制
- IO 防护：串阻 + 钳位，所有外部输入确保不超过 3.3V

### 6.3 接地
- 建议：数字地、功率地单点汇接
- 继电器/风扇大电流回路远离树莓派高速线

---

## 7. 软件落地要点（简）

### 7.1 Linux 设备
- I2C 设备通过 `i2c-tools` 验证
- MCP23017/PCA9685 可使用现成 Python/C 库
- 4G 建议 `ModemManager + NetworkManager` 或 `qmicli/uqmi`
- USB-RS485 使用 `/dev/ttyUSB*`

### 7.2 服务拆分建议
- `gpio-service`：继电器与输入管理
- `sensor-service`：AHT20/LIS3DH 采集
- `fan-service`：PWM 控制与故障检测
- `net-4g-service`：4G 拨号/健康检查

---

## 8. 开工 BOM（最小集）

- Raspberry Pi 4B / 5 主板
- MCP23017 ×2
- PCA9685 ×1
- ULN2803A ×1
- 继电器 ×8（按负载选型）
- AO3400/AO3401 等 MOS 若干（风扇/电源开关）
- AHT20 ×1
- LIS3DH ×1
- USB-RS485 模块 ×1
- USB 4G 网卡 ×1
- TVS、光耦、端子、保险丝、电源芯片等常规器件

---

## 9. 施工清单（可执行）

1. 原理图阶段
   - 完成 I2C/SPI/USB 外设连接
   - 完成继电器驱动、输入隔离、电源树
2. PCB 阶段
   - 功率回路与逻辑区分区
   - 预留测试点（I2C/SPI/电源/关键IO）
3. 点亮阶段
   - 先测电源纹波与温升
   - 再测 I2C 枚举、继电器动作、输入采样
   - 最后测 4G、RS485、风扇联动

---

## 10. 与原板功能对照结论

- 可完整覆盖：继电器、开关量输入、RS485、风扇、温湿度、加速度、网络与4G联网
- 可简化移除：MCU+外置 PHY+SIM 切换复杂逻辑
- 主要收益：引脚压力显著下降、软件维护成本下降、开发周期更短
