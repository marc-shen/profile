#!/bin/bash
# Rebuild the Dock application, input-source helper and NS policy module.
# Requires the macOS Command Line Tools (xcode-select --install).
set -euo pipefail
source_directory=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
bundle="$source_directory/Emacs Client.app"
module_build_directory=$(mktemp -d "${TMPDIR:-/tmp}/emacs-dock-module.XXXXXX")
trap 'rm -rf "$module_build_directory"' EXIT
xcrun clang -fobjc-arc -Wall -Wextra -Wno-unused-parameter -O2 \
  -arch arm64 -arch x86_64 -mmacosx-version-min=12.0 \
  -framework Cocoa "$bundle/Contents/Resources/launcher.m" \
  -o "$bundle/Contents/MacOS/emacs-client-launcher"
xcrun clang -fobjc-arc -Wall -Wextra -O2 \
  -arch arm64 -arch x86_64 -mmacosx-version-min=12.0 \
  -framework Cocoa -framework Carbon "$bundle/Contents/Resources/input-source.m" \
  -o "$bundle/Contents/Resources/input-source"
xcrun clang -fobjc-arc -Wall -Wextra -Wno-unused-parameter -O2 -dynamiclib \
  -arch arm64 -arch x86_64 -mmacosx-version-min=12.0 \
  -I /Applications/Emacs.app/Contents/Resources/include \
  -framework Cocoa "$bundle/Contents/Resources/dock-policy.m" \
  -o "$module_build_directory/dock-policy.dylib"
codesign --force --sign - "$module_build_directory/dock-policy.dylib"
# A running daemon may have the old module mapped. Replace its inode rather
# than overwriting mapped code; the new module is used on the next daemon start.
mv -f "$module_build_directory/dock-policy.dylib" "$bundle/Contents/Resources/dock-policy.dylib"
codesign --force --sign - "$bundle"
