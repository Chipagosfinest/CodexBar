#!/bin/bash
# CLT-only CodexBar build: macOS 26.5 SDK + local SwiftUI macro shims.
R=/tmp/swiftui-macro-shim/.build/release
F=/Library/Developer/CommandLineTools/Library/Developer/Frameworks
CMD=${CB_CMD:-build}
exec env SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift $CMD --build-system native --scratch-path .build-sdk26 \
  -Xswiftc -load-plugin-executable -Xswiftc "$R/SwiftUIMacros#SwiftUIMacros" \
  -Xswiftc -load-plugin-executable -Xswiftc "$R/PreviewsMacros#PreviewsMacros" -Xswiftc -F -Xswiftc "$F" -Xlinker -F -Xlinker "$F" -Xlinker -rpath -Xlinker "$F" \
  -Xlinker -rpath -Xlinker /Library/Developer/CommandLineTools/Library/Developer/usr/lib "$@"
