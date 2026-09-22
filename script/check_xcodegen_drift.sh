#!/usr/bin/env bash
set -euo pipefail

# Non-mutating check: regenerates the Xcode project into a scratch directory
# and diffs it against the checked-in NanaFlow.xcodeproj. Never touches the
# working tree. Exit 1 means project.yml and NanaFlow.xcodeproj have drifted
# apart -- run `xcodegen generate` in place and commit the result.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECKED_IN_PBXPROJ="$ROOT_DIR/NanaFlow.xcodeproj/project.pbxproj"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# project.yml's `sources:` are relative to the spec's directory (the repo
# root). xcodegen embeds file-reference paths relative to wherever it writes
# the .xcodeproj, so --project and --project-root must sit at the same
# directory depth as the real repo root or every path comes out "../../..."
# deeper than the checked-in project purely from the temp dir's location,
# not from real drift. Symlinking the source roots into the temp dir at the
# same relative layout keeps the comparison apples-to-apples without ever
# touching the real tree.
for entry in Sources Tests; do
  ln -s "$ROOT_DIR/$entry" "$TMP_DIR/$entry"
done

xcodegen generate \
  --spec "$ROOT_DIR/project.yml" \
  --project "$TMP_DIR" \
  --project-root "$TMP_DIR" \
  --quiet

GENERATED_PBXPROJ="$TMP_DIR/NanaFlow.xcodeproj/project.pbxproj"

if [[ ! -f "$GENERATED_PBXPROJ" ]]; then
  echo "xcodegen did not produce a project.pbxproj in the scratch directory." >&2
  exit 1
fi

if ! diff -q "$CHECKED_IN_PBXPROJ" "$GENERATED_PBXPROJ" >/dev/null; then
  echo "Drift detected: NanaFlow.xcodeproj is out of date with project.yml." >&2
  echo "Run 'xcodegen generate' at the repo root and commit the result." >&2
  diff "$CHECKED_IN_PBXPROJ" "$GENERATED_PBXPROJ" || true
  exit 1
fi

echo "NanaFlow.xcodeproj matches project.yml (no drift)."
