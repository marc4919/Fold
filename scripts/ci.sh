#!/bin/bash
# CI de Fold: build Debug + Release, tests y comprobación de árbol limpio.
# Reproducible desde un clone limpio: ./scripts/ci.sh
set -euo pipefail
cd "$(dirname "$0")/.."

DERIVED=".build"

echo "══ 1/4 · Build Debug"
xcodebuild -project Fold.xcodeproj -scheme Fold -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath "$DERIVED" build -quiet

echo "══ 2/4 · Build Release"
xcodebuild -project Fold.xcodeproj -scheme Fold -configuration Release \
  -destination 'platform=macOS' -derivedDataPath "$DERIVED" build -quiet

echo "══ 3/4 · Tests"
xcodebuild test -project Fold.xcodeproj -scheme Fold \
  -destination 'platform=macOS' -derivedDataPath "$DERIVED" -quiet

echo "══ 4/4 · El build no ensucia git"
if [ -n "$(git status --porcelain)" ]; then
  echo "✗ El working tree quedó sucio tras compilar/testear:"
  git status --porcelain
  exit 1
fi

echo "✓ CI verde: Debug + Release + tests + árbol limpio"
