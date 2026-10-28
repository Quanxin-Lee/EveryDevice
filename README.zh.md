# EveryDevice

[English](README.md) | 简体中文

EveryDevice 是一款完全本地运行的 macOS 菜单栏系统监控工具。状态栏圆环显示你关心的指标，点击后打开详情面板，查看实时图表、温度、电池、磁盘与网络吞吐，以及占用最高的进程。

macOS 26+ | Swift 6.2 | SwiftUI + AppKit | 无第三方依赖 | [Apache-2.0](LICENSE)

## 功能

**菜单栏**

- 状态环支持 CPU、GPU、内存、磁盘、电池和温度，可选择显示数值
- 网络模式使用下载/上传双环，并在菜单栏分两行堆叠显示实时速率
- 按正常、警告、危险三级着色
- 在 macOS 27 上使用系统原生的状态栏展开界面

**面板**

- 顶部显示设备型号与芯片
- CPU：占用率、负载均值、核心柱状图和滚动趋势线
- GPU：占用率、显存占用、数据过期或不可用状态
- 内存：应用、联动、压缩与交换空间构成
- 网络：下载与上传趋势线
- 磁盘：读写吞吐与剩余空间
- 电池：电量、供电状态、剩余时间或充满时间
- 温度：CPU 与 GPU 传感器，以及热压力等级
- 按 CPU 或内存排序的前 8 个进程
- 可调面板宽度、密度、卡片顺序与显示项

**提醒**

- CPU、内存、温度与磁盘剩余空间四类提醒
- 每条规则可设置阈值、连续采样次数、回差与冷却时间
- 使用本地通知；只有启用提醒时才会请求通知权限

**历史与数据**

- 每个采样点写入 SQLite，保留 1 到 24 小时
- 一键将全部保留数据导出为 CSV
- 进程数据不会写入历史

**个性化与系统集成**

- 8 种强调色主题，支持浅色、深色和跟随系统
- 英文与简体中文界面
- 1、2、5 秒刷新间隔
- 登录时启动
- 可选的防止空闲睡眠
- 单实例运行，常驻菜单栏且不长期占用 Dock
- 感知睡眠、唤醒与低电量模式

## 系统要求

- macOS 26 或更高版本
- 构建需要 Xcode 26 或带 macOS 26 SDK 的 Command Line Tools
- 不需要 Apple Developer 账号

## 安装

EveryDevice 不提供经过公证的二进制包。请在本机构建，安装脚本会在本地完成 ad-hoc 签名，不需要开发者账号。

### 从代码检出构建并安装（推荐）

```bash
git clone https://github.com/Quanxin-Lee/EveryDevice.git
cd EveryDevice
./Scripts/user-install.sh --build
```

脚本会构建发布版二进制、进行 ad-hoc 签名，安装到 `/Applications`（不可写时安装到
`~/Applications`），然后打开应用。

### 仅构建，不安装

```bash
./Scripts/build-app.sh
open build/EveryDevice.app
```

请运行 `.app` 应用包，而不是 SwiftPM 直接产出的裸二进制：资源文件需要应用包才能加载。

### 不检出代码，直接从 Git 仓库安装

```bash
curl -fsSL https://raw.githubusercontent.com/Quanxin-Lee/EveryDevice/main/Scripts/user-install.sh \
  -o /tmp/everydevice-install.sh
sh /tmp/everydevice-install.sh --build \
  --repo https://github.com/Quanxin-Lee/EveryDevice.git \
  --ref main
```

### 交给 AI agent 安装

把下面这段粘贴给你的 agent：

```text
帮我装好 EveryDevice：https://github.com/Quanxin-Lee/EveryDevice
阅读仓库里的 `install.md`，按步骤安装 EveryDevice。
```

### 关于 Gatekeeper

本地构建的应用没有经过公证。它能运行是因为应用在本机构建，且不带 `com.apple.quarantine`
属性。不要关闭 Gatekeeper，也不要为下载的二进制移除隔离属性。本项目不发布预编译下载。

## 使用

- 应用以菜单栏项目运行，不长期占用 Dock。
- 左键点击圆环打开面板。右键打开菜单，可打开面板、设置或退出。
- 从菜单进入设置，或在应用激活时按 Cmd+,。
- 将鼠标悬停在状态项上，可查看 CPU、GPU、内存、温度和网络摘要。
- 在 macOS 27 上，状态项使用系统展开界面。

设置页：

- 通用：状态环指标、数值显示、刷新间隔、登录时启动、防止睡眠、语言和外观
- 面板：强调色、宽度、密度、温度条、进程排行，以及卡片顺序与显示项
- 提醒：通知权限与各指标规则
- 数据：历史保留时长与 CSV 导出
- 关于：版本与版权

## 数据与隐私

- 全部在本机运行。没有账号、分析、遥测、更新检查或网络请求。
- 采样写入 `~/Library/Application Support/EveryDevice/metrics.sqlite`，偏好设置保存在
  UserDefaults。
- 进程列表只在面板打开时采样，且不会写入历史。
- CSV 导出只写入你选择的文件。
- 硬件数据来自 Mach、IOKit 与 libproc。CPU 与 GPU 温度通过运行时解析的 IOHID 温度符号读取；
  传感器不可用时，面板改用热压力等级。GPU 占用率来自 IOAccelerator，在部分 Mac 上可能不可用
  或数据过期。
- 不需要 sudo 或 root 权限。

## 工作原理

- Swift Package 包含两个 target：
  - `EveryDeviceCore`：非 UI 的采样器、指标引擎、历史、SQLite 记录器、提醒判定、设置与本地化，
    不导入 AppKit 或 SwiftUI。
  - `EveryDevice`：状态项、SwiftUI 面板与设置、通知、登录项与电源断言。
- `MetricsEngine` 在串行 utility 队列上按设定间隔采样，并把快照投递到主队列。
- 低电量模式会把刷新间隔拉长到 3 倍；电池容量每 30 秒采样一次；进程枚举跟随面板可见性。
- 睡眠时停止采样，唤醒后重置基线并清空图表历史。
- 仅当状态项图像、标题或提示发生变化时才更新。

## 开发

```bash
swift build
./Scripts/build-app.sh
./Scripts/install.sh
```

仅 DEBUG 构建可用的调试参数：

- `--show-panel`
- `--capture-popover`
- `--capture-settings`

快照写入 `/tmp/everydevice-snapshot`。使用前请以 `CONFIG=debug ./Scripts/build-app.sh` 构建，
并带上参数启动应用包内的可执行文件。当前没有测试 target。

项目约定见 [AGENTS.md](AGENTS.md)。`Resources/Info.plist` 是版本的唯一来源。
`Resources/AppIcon.svg` 是可编辑的图标源文件，`AppIcon.icns` 是生成产物。

## 已知限制

- 需要 macOS 26 或更高版本。
- 不提供公证构建或预编译包，需要从源码构建。
- 传感器覆盖范围因 Mac 型号而异，部分机器无法读取温度。
- 仅在 Apple Silicon 上测试；Intel Mac 尚未验证。
- 目前为 0.1.0 版本，设置项与存储格式在 1.0 之前可能变化。
- 目前没有自动化测试。

## 参与贡献

欢迎提交 issue 和 pull request。请保持改动聚焦，并在参与前阅读 [AGENTS.md](AGENTS.md)。
反馈传感器问题时，请附上 macOS 版本与 Mac 型号。

## 许可证

Apache License 2.0，见 [LICENSE](LICENSE)。Copyright 2026 Quanxin Li.
