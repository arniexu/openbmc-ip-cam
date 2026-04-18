# FET3568-C / FET3568J-C 系列产品规格（结构化整理）

> 来源：`FET3568-C_FET3568J-C_Product_spec.md`（OCR 文本整理版）  
> 适用对象：FET3568-C、FET3568J-C、FET3568J-C2

## 1. 产品概述

FET3568-C 与 FET3568J-C/FET3568J-C2 核心板基于 Rockchip RK3568B2 / RK3568J 处理器，面向 AIoT 与工业应用。

- CPU：4 x Cortex-A55，最高 2.0GHz（C）/ 1.8GHz（J）
- NPU：1 TOPS
- GPU：Mali-G52-2EE（最高 800MHz，38.4 GFLOPs）
- 制程：22nm
- 位宽：64-bit

## 2. 核心板基本参数

| 项目 | 规格 |
|---|---|
| SoC | RK3568B2（FET3568-C）/ RK3568J（FET3568J-C/J-C2） |
| CPU | 4 x Cortex-A55 @ 2.0GHz（C）/ 1.8GHz（J） |
| NPU | 1 TOPS，支持 INT8/INT16/FP16/BFP16 |
| GPU | Mali-G52-2EE，OpenGL ES 1.1/2.0/3.2，Vulkan 1.0/1.1，OpenCL 2.0 |
| VPU 硬解 | H.264/H.265/VP9 up to 4096x2304@60fps；其余见原始规格 |
| VPU 硬编 | H.264/H.265 up to 1920x1080@60fps |
| RAM | C/J：1GB/2GB/4GB DDR4；J-C2：4GB/8GB LPDDR4X |
| eMMC | C/J：8GB/16GB/32GB；J-C2：32GB/64GB |
| 核心板供电 | DC 5V |
| 工作温度 | C：0~+80℃；J/J-C2：-40~+85℃ |
| 接口连接方式 | 4 x 80Pin 板对板连接器，0.5mm 间距，2.0mm 合高 |

## 3. 核心板功能参数

| 功能 | 数量 | 关键参数 |
|---|---:|---|
| MIPI-DSI | 2 | 2 x 4-lane，单通道 1920x1080@60Hz，双通道 2560x1600@60Hz |
| HDMI | 1 | HDMI 2.0，最高 4096x2304@60Hz |
| LVDS | 1 | 单通道 4-lane，1280x800@60Hz |
| eDP | 1 | 4-lane，eDP 1.3，最高 2560x1600@60Hz |
| RGB | 1 | RGB888，最高 1280x800 |
| Camera | 2 | 1 x DVP + 1 x 4-lane MIPI-CSI |
| Audio | <=4 | 1 x 8ch I2S/TDM + 2 x 2ch I2S + 1 x 8ch PDM |
| SDIO | <=2 | SDIO 3.0，最高 104MB/s |
| Ethernet | <=2 | 2 x GMAC，支持 RGMII/RMII |
| USB2.0 | 2 | 2 x Host，独立端口 |
| USB3.0 | 2* | 1 x Host + 1 x OTG（受 SerDes 复用约束） |
| SATA | <=3* | SATA 3.0，6.0Gbps（受 SerDes 复用约束） |
| PCIe2.1 | <=1 | x1，5.0Gbps，RC |
| PCIe3.0 | <=2 | 1 x2 或 2 x1，8.0Gbps/lane；x2 支持 RC/EP |
| UART | <=10 | 最高 4Mbps |
| CAN | <=3 | CAN2.0B，最高 1Mbps |
| SPI | <=4 | 主从模式可配置 |
| I2C | <=5 | 7-bit/10-bit，最高 1Mbit/s |
| PWM | <=16 | 32-bit 定时器/计数器 |
| FSPI | <=1 | 支持串行 NOR/NAND，支持 Boot |

注：带 `*` 的功能受 SoC SerDes 资源复用限制。

## 4. 关键复用与电气关系（BSP 重点）

### 4.1 显示相关复用

- MIPI DSI TX0 与 LVDS TX PHY 复用。
- VOP 有 3 个输出 Port，最多支持 3 路显示输出（受复用关系约束）。

### 4.2 高速接口复用

- USB3.0、PCIe、SATA 共用 3 组 SerDes，不能按各接口理论最大值同时全开。
- PCIe 2.1 x1 在开发板上可复用为 SATA（软件配置）。
- PCIe 3.0 支持 x2 或 2 x1 配置。

## 5. 开发板功能参数

| 功能 | 数量 | 关键参数 |
|---|---:|---|
| HDMI 2.0 | 1 | 最高 4096x2304@60Hz |
| eDP | 1 | eDP 1.3，最高 2560x1600@60Hz |
| LVDS | 1 | 默认适配 10.1 吋 LVDS 屏，最高 1280x800 |
| LCD/RGB | 1 | RGB888，最高 1280x800；与 SPI0/SPI2/UART3/4/5/7 复用 |
| MIPI-DSI | 1 | 默认适配 7 吋屏（1024x600），能力最高 1920x1080@60Hz |
| Camera | 1 | MIPI-CSI，已适配 OV13850 |
| Audio | 1 | 双声道耳机 + 1.3W D 类功放 + MIC 输入 |
| TF Card | 1 | 扩展存储与系统烧写 |
| Ethernet | 2 | 2 x RJ45，10/100/1000Mbps |
| 4G/5G | 1 | M.2 Key-B，含 USB3.0/2.0；适配 EM05-CE / RM500U-CN |
| Wi-Fi | 1 | AW-CM358SM，2.4G/5G 双频 |
| Bluetooth | 1 | BT5.0（文档注明不支持蓝牙音频） |
| USB2.0 Host | 2 | Type-A |
| USB3.0 Host | 1 | Type-A；USB2.0 信号与 download 引脚复用（S2 拨码切换） |
| USB2.0 OTG | 1 | Type-C；与 USB3.0 Host 共用 USB2.0 引脚 |
| PCIe 2.1 | 1 | 标准 x1 插座，可复用 SATA |
| PCIe 3.0 | 1 | 标准 x4 插座，可配为 2 x x1 |
| UART | 3 | 3.3V TTL，2.54mm 排针 |
| CAN | 2 | CAN2.0，最高 1Mbps，带隔离和 ESD |
| SPI | 2 | 3.3V TTL，2.54mm 排针 |
| I2C | 1 | 3.3V TTL，2.54mm 排针 |
| RTC | 1 | CR2032 断电保持 |
| 按键 | 8 | 复位、开关机、OTG 烧写、Maskrom、VOL+、VOL-、HOME、ESC |
| Debug | 1 | 板载 USB 转串口，Type-C，引导调试默认 115200 |
| 电源输入 | 1 | DC 12V |
| LED | 2 | 用户自定义 LED |
| FSPI | 1 | 默认空焊，暂不支持 |

## 6. 开发板资源占用与互斥（BSP 规划）

| 资源 | 默认占用 | BSP 注意事项 |
|---|---|---|
| SDIO | 板载 Wi-Fi 使用 | 若改作其他 SDIO 外设，需禁用/替换板载 Wi-Fi |
| UART | 板载 BT 使用 1 路 | 若改作外设通信，需处理 BT 冲突 |
| USB2.0 PHY 路由 | USB3 Host / OTG download 相关路径复用 | 通过拨码和软件配置确保单一工作路径 |
| SerDes | USB3/PCIe/SATA 共享 | 功能裁剪前先做 lane 预算 |
| RGB 复用引脚 | 与 SPI0/2、UART3/4/5/7 复用 | RGB 打开时相关低速外设可能不可用 |

## 7. 软件支持（原文整理）

### 7.1 操作系统

- Linux 5.10.160 + Qt 5.15.8
- Android 11
- Forlinx Desktop 20.04（基于 Ubuntu 20.04 文件系统）
- Debian 11
- AMP（基于 Linux 4.19.232 + Qt 5.15.8）
- OpenHarmony 4.1（基于 Linux 5.10.184）

### 7.2 烧写方式

- SD 卡
- USB OTG

### 7.3 典型外设适配（跨系统出现频次高）

- 电容触摸：FT5x06、GT928
- RTC：PCF8563T
- Wi-Fi/BT：AW-CM358SM
- 摄像头：OV13850、UVC（罗技 C270）
- 4G/5G：EM05-CE（兼容 EC20）、RM500U
- 千兆 PHY：RTL8211FSI-CG
- PCIe 网卡：RTL8111F（模块）

## 8. 订货型号（整理）

| 型号（节选） | CPU | RAM | eMMC | 温度等级 |
|---|---:|---:|---:|---|
| FET3568-C+201GSE8GCExx:xx | 2.0GHz | 1GB | 8GB | 0~+80℃ |
| FET3568-C+202GSE16GCAxx:xx | 2.0GHz | 2GB | 16GB | 0~+80℃ |
| FET3568-C+202GSE32GCFxx:xx | 2.0GHz | 2GB | 32GB | 0~+80℃ |
| FET3568-C+204GSE32GCDxx:xx | 2.0GHz | 4GB | 32GB | 0~+80℃ |
| FET3568J-C+181GSE8GIDxx:xx | 1.8GHz | 1GB | 8GB | -40~+85℃ |
| FET3568J-C+182GSE16GIBxx:xx | 1.8GHz | 2GB | 16GB | -40~+85℃ |
| FET3568J-C+184GSE32GICxx:xx | 1.8GHz | 4GB | 32GB | -40~+85℃ |
| FET3568J-C2+184GSE32GIBxx:xx | 1.8GHz | 4GB | 32GB | -40~+85℃ |
| FET3568J-C2+188GSE64GIAxx:xx | 1.8GHz | 8GB | 64GB | -40~+85℃ |

注：带 `*` 的“全国产”条目在 OCR 文本中有重复/标记混杂，实际以厂商最新订货清单为准。

## 9. 命名规则（整理）

命名结构：`A-B-C+DEFGHIJ:KL`

| 字段 | 含义 | 示例 |
|---|---|---|
| A | 产品线 | FET / FL |
| B | CPU 名称 | 3568 / 3568J |
| C | 连接方式 | C / C2 |
| D | 主频 | 18=1.8GHz，20=2.0GHz |
| E | RAM | 2G/4G/8G |
| F | ROM 类型 | SE=eMMC |
| G | ROM 容量 | 16G/32G/64G |
| H | 温度等级 | C=0~80℃，I=-40~85℃ |
| I | 配置代号 | A~Z |
| J | PCB 版本 | 10/11/xx |
| K/L | 厂内标识 | xx |

## 10. BSP 开发建议（基于当前规格文本）

- 先确认目标功能是否与现有复用冲突（SerDes、SDIO/UART、显示复用）。
- 在 DTS 中明确互斥策略，不保留多路径同时使能。
- 若涉及高速链路（USB3/PCIe/SATA），建议结合原理图和 lane 走线做二次核对。
- 若涉及电气接口外接，注意开发板引出的 UART/SPI/I2C 多为 3.3V TTL。

## 11. 资料完整性提示

当前文本为 OCR 规格整理版，可支持前期功能规划，但不等同于完整硬件设计输入。正式 BSP 定版前建议补齐：

- 引脚复用表（pinmux）
- 底板原理图（AD/PDF）
- 电源时序/复位时序
- 关键器件料号（PHY、PMIC、时钟、开关）
