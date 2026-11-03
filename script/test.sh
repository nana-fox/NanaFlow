#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 script/check_localization.py
# Run the existing XCTest suite in a separate host/suite, never the Store app.
python3 script/run_isolated_tests.py "$@"
