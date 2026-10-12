#!/bin/bash
# Rebuild the bundled Dock application after editing Resources/launcher.m.
# Requires the macOS Command Line Tools (xcode-select --install).
set -euo pipefail
source_directory=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
bundle="$source_directory/Emacs Client.app"
xcrun clang -fobjc-arc -Wall -Wextra -Wno-unused-parameter -O2 \
  -arch arm64 -arch x86_64 -mmacosx-version-min=12.0 \
  -framework Cocoa "$bundle/Contents/Resources/launcher.m" \
  -o "$bundle/Contents/MacOS/emacs-client-launcher"
codesign --force --sign - "$bundle"
