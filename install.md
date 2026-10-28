# Install EveryDevice

Use this file when EveryDevice is not installed or when the user asks to install it.
The installer builds the app from source on the user's Mac and signs it locally.
No Apple Developer account is required.

## Requirements

- macOS 26 or later
- Xcode or Command Line Tools with the macOS 26 SDK
- Git, included with Command Line Tools

## Install from source

Ask the user for permission before installing, then run one of these:

```bash
# From an existing checkout
./Scripts/user-install.sh --build

# From a Git URL
./Scripts/user-install.sh --build --repo <repo-url> --ref <branch-or-tag>
```

To fetch the installer first instead of piping it into a shell:

```bash
curl -fsSL <install-script-url> -o /tmp/everydevice-install.sh
sh /tmp/everydevice-install.sh --build --repo <repo-url> --ref <branch-or-tag>
```

The script:

1. Checks the macOS version and Swift SDK.
2. Clones the repository when `--repo` is used.
3. Builds the release binary.
4. Signs it ad-hoc with `codesign`.
5. Installs it to `/Applications` when writable, otherwise to `~/Applications`.
6. Opens the app.

EveryDevice is a menu bar app. After it opens, tell the user to look for the
EveryDevice icon in the menu bar.

## Agent prompt

```text
Install EveryDevice from <repo-url>. Read install.md and follow it.
```

## Verification

```bash
APP="/Applications/EveryDevice.app"
[ -d "$APP" ] || APP="$HOME/Applications/EveryDevice.app"
codesign --verify --deep --strict "$APP"
codesign -dv --verbose=4 "$APP" 2>&1 | grep Signature
pgrep -fl 'EveryDevice.app/Contents/MacOS/EveryDevice'
```

`Signature=adhoc` is expected. `spctl` rejects a local ad-hoc build because it is
not notarized. That is expected: the app runs because it was built locally and
has no `com.apple.quarantine` attribute.

## Rules

- Do not run `xattr -dr com.apple.quarantine`.
- Do not run `spctl --master-disable`.
- Do not use `sudo` unless the user explicitly approves it.
- Do not download a prebuilt binary when the user asked to build from source.
- Ask before replacing an existing installation.
- Do not guess the repository URL; ask the user if it is not provided.

## Troubleshooting

- `macOS 26 or later is required`: update macOS.
- `macOS 26 SDK or later is required`: install Xcode 26 or newer, or updated
  Command Line Tools, and select it in Xcode Settings > Locations.
- `swift not found`: install Xcode or Command Line Tools.
- Build fails: run `swift build -c release` in the checkout and report the first
  error.
- The app does not appear: check it with `pgrep`, then run
  `open /Applications/EveryDevice.app` or the `~/Applications` path.
