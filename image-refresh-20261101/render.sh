#!/bin/bash
set -euo pipefail
n=$1
w=/tmp/cb-reviewfix/$n
kit=/tmp/pr-image-refresh/kit/$n
out=/tmp/pr-image-refresh/out/$n
cd "$w"
test -z "$(git status --porcelain --untracked-files=no)"
mkdir -p "$out"
export PR_IMAGE_HEAD=$(git rev-parse HEAD)
cp Package.swift /tmp/pr-image-refresh/Package.$n.original
trap 'cp /tmp/pr-image-refresh/Package.$n.original "$w/Package.swift"; rm -rf "$w/LocalProofTests"' EXIT
mkdir LocalProofTests
cp "$kit/"*.swift LocalProofTests/
python3 - <<'PY'
p='Package.swift';s=open(p).read();a=s.index('        targets.append(.testTarget(\n            name: "CodexBarTests"');b=s.index('\n        #endif',a)
s=s[:a]+'''        targets.append(.testTarget(
            name: "LocalProofTests", dependencies: ["CodexBar", "CodexBarCore", "CodexBarWidget"], path: "LocalProofTests",
            swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]))'''+s[b:];open(p,'w').write(s)
PY
source Scripts/test_environment.sh
unset GIT_CONFIG_COUNT
export CODEXBAR_DISABLE_CLAUDE_WATCHDOG=1
export TOOLCHAIN_DIR=/Library/Developer/CommandLineTools
export CODEXBAR_REDESIGN_PROOF_DIR="$out"
F=/Library/Developer/CommandLineTools/Library/Developer/Frameworks
R=/tmp/swiftui-macro-shim/.build/release
case $n in
4887) filter=V2WidgetProofTests;;
4888) filter='V2ProofTests|V2ShareExportProofTests';;
4889) filter=V2ModelsProofTests;;
esac
swift test --disable-xctest --build-system native --jobs 4 \
 --sdk /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk \
 -Xswiftc -load-plugin-executable -Xswiftc "$R/SwiftUIMacros#SwiftUIMacros" \
 -Xswiftc -load-plugin-executable -Xswiftc "$R/PreviewsMacros#PreviewsMacros" \
 -Xswiftc -F -Xswiftc "$F" -Xlinker -F -Xlinker "$F" -Xlinker -rpath -Xlinker "$F" \
 --filter "$filter" > /tmp/pr-image-refresh/render-$n.log 2>&1
