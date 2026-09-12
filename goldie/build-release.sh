#!/bin/bash
set -euo pipefail
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
xcodebuild -project "$repo_root/Koat.xcodeproj" -scheme Koat \
  -configuration Release -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/koat-goldie-build \
  'OTHER_SWIFT_FLAGS=$(inherited) -D GOLDIE_CAPTURE' \
  CODE_SIGNING_ALLOWED=NO build
