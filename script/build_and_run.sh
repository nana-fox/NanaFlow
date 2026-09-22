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
WIDGET_BUNDLE="$APP_BUNDLE/Contents/PlugIns/NanaFlowWidget.appex"
LOCKED_LOCALES=("en" "zh-Hans")
REMOVED_FEATURE_RESOURCES=("Blocked.html" "NanaFlowBlockedIcon.png" "NanaFlowCalendarAccess.png")

usage() {
  echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
}

stop_running_app() {
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
}

clean_derived_data() {
  # DERIVED_DATA_PATH is a build directory scoped entirely to this repo (not
  # the global ~/Library/Developer/Xcode/DerivedData used by other tooling).
  # Incremental builds can leave stale copied resources behind -- e.g. an
  # .lproj directory removed from the source tree keeps shipping in the
  # built bundle until something forces a full rebuild. Removing only this
  # repo-scoped path (never a broader location) guarantees the next build
  # reflects exactly what's on disk. The guard keeps this from ever running
  # against an unexpected path.
  if [[ "$DERIVED_DATA_PATH" == "$ROOT_DIR/build/DerivedData" && -n "$DERIVED_DATA_PATH" ]]; then
    rm -rf "$DERIVED_DATA_PATH"
  fi
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

bundle_locales() {
  # $1: path to a .app or .appex bundle's Contents/Resources
  find "$1" -maxdepth 1 -type d -name '*.lproj' -exec basename {} .lproj \; | sort
}

verify_bundle_resources() {
  local failed=0
  local expected
  expected="$(printf '%s\n' "${LOCKED_LOCALES[@]}" | sort)"

  for bundle_resources in \
    "$APP_BUNDLE/Contents/Resources" \
    "$WIDGET_BUNDLE/Contents/Resources"; do
    if [[ ! -d "$bundle_resources" ]]; then
      echo "Expected resources directory missing: $bundle_resources" >&2
      failed=1
      continue
    fi
    local found
    found="$(bundle_locales "$bundle_resources")"
    if [[ "$found" != "$expected" ]]; then
      echo "Localization mismatch in $bundle_resources" >&2
      echo "  expected: $(echo "$expected" | tr '\n' ' ')" >&2
      echo "  found:    $(echo "$found" | tr '\n' ' ')" >&2
      failed=1
    fi
  done

  for resource in "${REMOVED_FEATURE_RESOURCES[@]}"; do
    local hits
    hits="$(find "$APP_BUNDLE" -name "$resource" 2>/dev/null)"
    if [[ -n "$hits" ]]; then
      echo "Removed feature resource '$resource' still ships in the built bundle:" >&2
      echo "$hits" >&2
      failed=1
    fi
  done

  if [[ "$failed" -ne 0 ]]; then
    echo "Bundle resource verification failed." >&2
    exit 1
  fi
  echo "Bundle resource verification passed: only ${LOCKED_LOCALES[*]} ship, no removed-feature resources present."
}

stop_running_app
clean_derived_data
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
    verify_bundle_resources
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
