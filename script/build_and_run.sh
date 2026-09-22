#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="NanaFlow"
BUNDLE_ID="com.nanafox.NanaFlow"
HOST_ARCH="$(uname -m)"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/NanaFlow.xcodeproj"
DERIVED_DATA_PATH="$ROOT_DIR/build/DerivedData"
APP_BUNDLE="$DERIVED_DATA_PATH/Build/Products/Debug/$APP_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"

usage() {
  echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
}

stop_running_app() {
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
}

build_app() {
  xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$APP_NAME" \
    -configuration Debug \
    -destination "platform=macOS,arch=$HOST_ARCH" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    CODE_SIGNING_ALLOWED=NO \
    build

  if [[ ! -x "$APP_BINARY" ]]; then
    echo "Built app executable was not found at $APP_BINARY" >&2
    exit 1
  fi
}

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

stop_running_app
build_app

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    exec lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    exec /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    exec /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    for _ in {1..20}; do
      if pgrep -x "$APP_NAME" >/dev/null; then
        echo "$APP_NAME launched successfully."
        exit 0
      fi
      sleep 0.25
    done
    echo "$APP_NAME did not stay running after launch." >&2
    exit 1
    ;;
  *)
    usage
    exit 2
    ;;
esac
