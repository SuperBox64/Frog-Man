#!/usr/bin/env bash
# FrogMan, SpriteKit edition, build helper. Wraps `swift build` with the
# swift.org toolchain + wasm SDK env so wasm32-wasip1 actually finds the
# C target (KitABI shim.c + Box2DBridge cbox2d.cpp) — Xcode's bundled clang
# has no wasm backend, so we run through xcrun --toolchain swift to pick the
# swift.org clang the wasm SDK was built against.
#
# Usage:
#   ./build.sh                  # debug
#   ./build.sh release          # release
#   ./build.sh --target FrogMan # forwarded to swift build

set -eo pipefail

# The runtime lives in its OWN repo, a sibling of the FrogMan repo (never a
# nested clone inside it). Dev: ../../WasmKit is the working
# checkout and is used as-is. CI: cloned to that same spot, outside the repo.
# Resolved from the script's location so the clone target never depends on
# the caller's working directory.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WASMKIT="$SCRIPT_DIR/../../WasmKit"
if [ ! -d "$WASMKIT" ]; then
  echo "→ Cloning WasmKit..."
  git clone https://github.com/SuperBox64/WasmKit "$WASMKIT"
fi

WASM_SDK="${WASM_SDK:-swift-6.3.2-RELEASE_wasm}"

# `TOOLCHAINS=org.swift.6.3.2-release xcrun --toolchain swift` mis-resolves to
# whatever dev-snapshot toolchain is newest once one is installed (its real
# CFBundleIdentifier isn't "org.swift.6.3.2-release"), which then tries to
# import wasm SDK modules built with 6.3.2 using a 6.5 frontend and fails with
# "module compiled with Swift 6.3.2 cannot be imported by the Swift 6.5
# compiler". Resolve the pinned toolchain's `swift` binary directly instead,
# same fix build-native-game.sh already applies to `swiftc`.
SWIFT_BIN="${SWIFT_BIN:-$HOME/Library/Developer/Toolchains/swift-6.3.2-RELEASE.xctoolchain/usr/bin/swift}"
[ -x "$SWIFT_BIN" ] || SWIFT_BIN="$(xcrun --toolchain swift -f swift)"

CONFIG_ARGS=()
PASSTHROUGH=()
for arg in "$@"; do
  case "$arg" in
    release) CONFIG_ARGS=(-c release -Xswiftc -Osize -Xlinker -s -Xswiftc -Xfrontend -Xswiftc -disable-reflection-metadata) ;;
    debug)   CONFIG_ARGS=(-c debug)   ;;
    *)       PASSTHROUGH+=("$arg")    ;;
  esac
done

echo "→ swift build  (swift=$SWIFT_BIN  sdk=$WASM_SDK)"
"$SWIFT_BIN" build \
  --swift-sdk "$WASM_SDK" \
  "${CONFIG_ARGS[@]}" \
  "${PASSTHROUGH[@]}"

# Auto-publish into web/ when building release so the page is one curl away.
if [ "${CONFIG_ARGS[1]:-}" = "release" ]; then
  REL=.build/wasm32-unknown-wasip1/release/FrogMan.wasm
  if command -v wasm-opt >/dev/null 2>&1; then
    wasm-opt -Oz \
      --enable-bulk-memory --enable-nontrapping-float-to-int \
      --enable-sign-ext --enable-mutable-globals --enable-multivalue \
      "$REL" -o web/frogman.wasm
    echo
    echo "✓ Release artifact published (wasm-opt -Oz): web/frogman.wasm"
  else
    cp "$REL" web/frogman.wasm
    echo
    echo "✓ Release artifact published (install binaryen for a smaller wasm): web/frogman.wasm"
  fi
else
  cp .build/wasm32-unknown-wasip1/debug/FrogMan.wasm web/frogman.wasm
  echo
  echo "✓ Debug artifact published: web/frogman.wasm"
fi

source "$WASMKIT/build.sh"
wasmweb_manifest web/assets web/manifest.json
rm -f web/runtime.js
cp "$WASMKIT/runtime.js" web/runtime.js
