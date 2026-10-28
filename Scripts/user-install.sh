#!/bin/bash
set -euo pipefail

APP_NAME="EveryDevice"
DEFAULT_DEST="/Applications/${APP_NAME}.app"
USER_DEST="${HOME}/Applications/${APP_NAME}.app"

REPO_URL="${REPO_URL:-}"
REF="${REF:-}"
REPO_DIR_OPT=""
TMP_DIR=""
SRC_DIR=""

usage() {
    cat >&2 <<'EOF'
Usage: Scripts/user-install.sh [options]

Build EveryDevice from source on this Mac, ad-hoc sign it, install it, and open it.
No Apple Developer account is required.

Options:
  --build              Build from source (default).
  --repo <url>         Clone this repository URL before building.
  --ref <branch|tag>   Branch or tag to clone with --repo.
  --repo-dir <path>    Build an existing checkout instead of the current directory.
  -h, --help           Show this help.

Environment:
  REPO_URL             Same as --repo.
  REF                  Same as --ref.
EOF
}

log() {
    printf '%s\n' "$*" >&2
}

die() {
    log "error: $*"
    exit 1
}

cleanup() {
    if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ]; then
        rm -rf "$TMP_DIR"
    fi
}

trap cleanup EXIT HUP INT TERM

parse_args() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --build)
                ;;
            --repo)
                [ "$#" -ge 2 ] || die "--repo requires a URL"
                REPO_URL="$2"
                shift
                ;;
            --ref)
                [ "$#" -ge 2 ] || die "--ref requires a branch or tag"
                REF="$2"
                shift
                ;;
            --repo-dir)
                [ "$#" -ge 2 ] || die "--repo-dir requires a path"
                REPO_DIR_OPT="$2"
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                die "unknown argument: $1"
                ;;
        esac
        shift
    done
}

check_macos() {
    [ "$(uname -s)" = "Darwin" ] || die "this installer only supports macOS"

    local version major
    version="$(sw_vers -productVersion)"
    major="${version%%.*}"
    case "$major" in
        ''|*[!0-9]*) die "unexpected macOS version: $version" ;;
    esac
    [ "$major" -ge 26 ] || die "macOS 26 or later is required (found $version)"
}

check_toolchain() {
    command -v swift >/dev/null 2>&1 || die "swift not found; install Xcode or Command Line Tools"
    command -v xcrun >/dev/null 2>&1 || die "xcrun not found; install Xcode or Command Line Tools"

    local sdk sdk_major
    sdk="$(xcrun --sdk macosx --show-sdk-version 2>/dev/null || true)"
    [ -n "$sdk" ] || die "macOS SDK not found; install Xcode or Command Line Tools"
    sdk_major="${sdk%%.*}"
    case "$sdk_major" in
        ''|*[!0-9]*) die "unexpected macOS SDK version: $sdk" ;;
    esac
    [ "$sdk_major" -ge 26 ] || die "macOS 26 SDK or later is required (found $sdk)"
}

script_repo_root() {
    local source="${BASH_SOURCE[0]:-}"
    if [ -n "$source" ] && [ -f "$source" ]; then
        cd "$(dirname "$source")/.." && pwd
    fi
}

is_repo_root() {
    [ -f "$1/Package.swift" ] && [ -d "$1/Sources/EveryDevice" ]
}

resolve_source() {
    if [ -n "$REPO_DIR_OPT" ]; then
        [ -d "$REPO_DIR_OPT" ] || die "repository directory not found: $REPO_DIR_OPT"
        is_repo_root "$REPO_DIR_OPT" || die "not an EveryDevice checkout: $REPO_DIR_OPT"
        SRC_DIR="$REPO_DIR_OPT"
        return
    fi

    if [ -n "$REPO_URL" ]; then
        command -v git >/dev/null 2>&1 || die "git not found; install Command Line Tools"
        local temp_base="${TMPDIR:-/tmp}"
        temp_base="${temp_base%/}"
        TMP_DIR="$(mktemp -d "$temp_base/everydevice-install.XXXXXX")"
        local clone_dir="$TMP_DIR/$APP_NAME"
        log "Cloning $REPO_URL ..."
        if [ -n "$REF" ]; then
            git clone --depth 1 --branch "$REF" "$REPO_URL" "$clone_dir" >&2
        else
            git clone --depth 1 "$REPO_URL" "$clone_dir" >&2
        fi
        is_repo_root "$clone_dir" || die "cloned repository is not an EveryDevice checkout"
        SRC_DIR="$clone_dir"
        return
    fi

    if is_repo_root "$PWD"; then
        SRC_DIR="$PWD"
        return
    fi

    local root
    root="$(script_repo_root || true)"
    if [ -n "$root" ] && is_repo_root "$root"; then
        SRC_DIR="$root"
        return
    fi

    die "not inside the EveryDevice repository; pass --repo <url> or --repo-dir <path>"
}

build_app() {
    local src_dir="$1"
    log "Building $APP_NAME from $src_dir ..."
    (
        cd "$src_dir"
        CONFIG=release bash "$src_dir/Scripts/build-app.sh"
    )
}

install_app() {
    local src_dir="$1"
    local app="$src_dir/build/$APP_NAME.app"
    [ -d "$app" ] || die "built app not found: $app"

    log "Verifying ad-hoc signature ..."
    codesign --verify --deep --strict --verbose=2 "$app" >&2

    local bundle_id
    bundle_id="$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$app/Contents/Info.plist" 2>/dev/null || true)"
    [ -n "$bundle_id" ] || die "cannot read CFBundleIdentifier from the built app"

    local dest="$DEFAULT_DEST"
    if [ ! -d /Applications ] || [ ! -w /Applications ]; then
        dest="$USER_DEST"
        mkdir -p "$(dirname "$dest")"
    fi

    if [ -d "$dest" ]; then
        local existing_id
        existing_id="$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$dest/Contents/Info.plist" 2>/dev/null || true)"
        [ "$existing_id" = "$bundle_id" ] || die "$dest exists and is not $APP_NAME (id: ${existing_id:-unknown})"
    fi

    local pids
    pids="$(pgrep -f "$APP_NAME.app/Contents/MacOS/$APP_NAME" || true)"
    if [ -n "$pids" ]; then
        log "Stopping the running $APP_NAME ..."
        # shellcheck disable=SC2086
        kill $pids 2>/dev/null || true
        local i
        for i in $(seq 1 20); do
            pgrep -f "$APP_NAME.app/Contents/MacOS/$APP_NAME" >/dev/null 2>&1 || break
            sleep 0.1
        done
    fi

    log "Installing to $dest ..."
    rm -rf "$dest"
    ditto "$app" "$dest"
    codesign --verify --deep --strict --verbose=2 "$dest" >&2

    log "installed: $dest"
    log "note: this is a local ad-hoc build, not a notarized release; it runs because it was built on this Mac and has no quarantine attribute."
    open "$dest" || die "failed to open $dest"
}

main() {
    parse_args "$@"
    check_macos
    check_toolchain

    resolve_source
    build_app "$SRC_DIR"
    install_app "$SRC_DIR"
}

main "$@"
