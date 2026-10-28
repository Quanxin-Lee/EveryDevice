# EveryDevice

English | [Simplified Chinese](README.zh.md)

EveryDevice is a local-only system monitor for the macOS menu bar. A compact status ring shows
the metric you care about; a click opens a detailed panel with live charts, temperatures, battery
state, disk and network throughput, and the busiest processes.

macOS 26+ | Swift 6.2 | SwiftUI + AppKit | No third-party dependencies | [Apache-2.0](LICENSE)

## Features

**Menu bar**

- Status ring for CPU, GPU, memory, disk, battery, or temperature, with an optional numeric value
- Network mode uses a split download/upload ring with stacked rates
- Color-coded normal, warning, and critical levels
- Native macOS 27 status item expanded interface when available

**Panel**

- Device model and chip header
- CPU: usage, load average, core bars, and a rolling sparkline
- GPU: utilization, memory in use, and stale or unavailable states
- Memory: app, wired, compressed, and swap breakdown
- Network: download and upload sparklines
- Disk: read and write throughput plus free space
- Battery: charge, power source, time remaining, or time to full
- Temperature: CPU and GPU sensors plus thermal pressure
- Top 8 processes, sortable by CPU or memory
- Adjustable panel width, density, card order, and visibility

**Alerts**

- CPU, memory, temperature, and low disk space rules
- Per-rule threshold, consecutive samples, hysteresis, and cooldown
- Local notifications; notification permission is requested only when an alert is enabled

**History and data**

- Every sampling tick recorded in SQLite with 1 to 24 hours of retention
- One-click CSV export of all retained samples
- Process data is never recorded

**Personalization and system integration**

- 8 accent themes, plus light, dark, and system appearance
- English and Simplified Chinese interface
- 1, 2, or 5 second refresh interval
- Launch at login
- Optional keep-awake assertion
- Single instance, menu bar only, without a permanent Dock icon
- Sleep, wake, and Low Power Mode aware

## Requirements

- macOS 26 or later
- Xcode 26 or Command Line Tools with the macOS 26 SDK to build
- No Apple Developer account required

## Install

EveryDevice does not publish notarized binaries. Build it on your Mac; the installer signs the
app ad-hoc locally and needs no developer account.

### Build and install from a checkout (recommended)

```bash
git clone https://github.com/Quanxin-Lee/EveryDevice.git
cd EveryDevice
./Scripts/user-install.sh --build
```

The script builds a release binary, signs it ad-hoc, installs it to `/Applications` (or
`~/Applications` when `/Applications` is not writable), and opens the app.

### Build without installing

```bash
./Scripts/build-app.sh
open build/EveryDevice.app
```

Run the `.app` bundle, not the raw SwiftPM binary: the bundle carries the resources.

### Install from the Git URL without a checkout

```bash
curl -fsSL https://raw.githubusercontent.com/Quanxin-Lee/EveryDevice/main/Scripts/user-install.sh \
  -o /tmp/everydevice-install.sh
sh /tmp/everydevice-install.sh --build \
  --repo https://github.com/Quanxin-Lee/EveryDevice.git \
  --ref main
```

### Let an AI agent install it

Paste this into your agent:

```text
Install EveryDevice from https://github.com/Quanxin-Lee/EveryDevice.
Read `install.md` in the repository and follow it.
```

### About Gatekeeper

A locally built app is not notarized. It runs because it was built on your Mac and carries no
`com.apple.quarantine` attribute. Do not disable Gatekeeper or remove quarantine attributes from
downloaded binaries. This project does not publish prebuilt downloads.

## Usage

- The app runs as a menu bar item without a permanent Dock icon.
- Left-click the ring to open the panel. Right-click for Open Panel, Settings, and Quit.
- Open Settings from the menu, or press Cmd+, while the app is active.
- Hover the status item for CPU, GPU, memory, temperature, and network summaries.
- On macOS 27 the status item uses the system expanded interface.

Settings pages:

- General: ring metric, value text, refresh interval, launch at login, keep awake, language, and
  appearance
- Panel: accent theme, width, density, temperature strip, process ranking, and card order and
  visibility
- Alerts: notification permission and per-metric rules
- Data: history retention and CSV export
- About: version and copyright

## Data and privacy

- Everything runs locally. There are no accounts, analytics, telemetry, update checks, or network
  requests.
- Samples are written to `~/Library/Application Support/EveryDevice/metrics.sqlite`. Preferences
  live in UserDefaults.
- Process data is sampled only while the panel is open and is never recorded.
- CSV export writes only the file you choose.
- Hardware data comes from Mach, IOKit, and libproc. CPU and GPU temperatures are read through
  IOHID temperature symbols resolved at runtime; when sensors are unavailable the panel falls back
  to thermal pressure. GPU utilization comes from IOAccelerator and may be unavailable or stale on
  some Macs.
- No sudo or root access is required.

## How it works

- The Swift package has two targets:
  - `EveryDeviceCore`: non-UI samplers, the metrics engine, history, the SQLite recorder, alert
    evaluation, settings, and localization. It does not import AppKit or SwiftUI.
  - `EveryDevice`: the status item, SwiftUI panel and settings, notifications, login item, and
    power assertions.
- `MetricsEngine` samples on a serial utility queue at the configured interval and delivers
  snapshots to the main queue.
- Low Power Mode triples the refresh interval; battery capacity is sampled every 30 seconds; and
  process enumeration follows panel visibility.
- Sleep stops sampling. Wake resets baselines and clears chart history.
- The status item updates only when its image, title, or tooltip changes.

## Development

```bash
swift build
./Scripts/build-app.sh
./Scripts/install.sh
```

Debug-only flags:

- `--show-panel`
- `--capture-popover`
- `--capture-settings`

Snapshots go to `/tmp/everydevice-snapshot`. Build with `CONFIG=debug ./Scripts/build-app.sh`
and launch the executable inside the app bundle with the flag. There is no test target.

Project conventions are documented in [AGENTS.md](AGENTS.md). `Resources/Info.plist` is the
single version source. `Resources/AppIcon.svg` is the editable icon source, and `AppIcon.icns` is
a generated artifact.

## Limitations

- Requires macOS 26 or later.
- No notarized builds or prebuilt binaries; build from source.
- Sensor coverage varies by Mac model, and temperature is unavailable on some machines.
- Tested on Apple Silicon; Intel Macs are untested.
- Version 0.1.0; settings and storage may change before 1.0.
- There is no automated test suite yet.

## Contributing

Issues and pull requests are welcome. Keep changes focused, and read [AGENTS.md](AGENTS.md) before
contributing. When reporting sensor problems, include the macOS version and Mac model.

## License

Apache License 2.0. See [LICENSE](LICENSE). Copyright 2026 Quanxin Li.
