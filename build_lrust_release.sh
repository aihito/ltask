#!/bin/bash
# Build lrust (release) for this ltask repo.
#
# This script focuses on "compiles cleanly" + "easy to test locally".
# Runtime integration (ltask callbacks, protocol routing) depends on further Rust-side adaptation.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

echo "==> Building ltask (release)"
make clean
make

echo "==> Building lrust (release)"
pushd 3rd/lrust >/dev/null
cargo build --release
popd >/dev/null

echo "==> Copying cdylib to repo root for Lua cpath"
if [ -f "3rd/lrust/target/release/librust.so" ]; then
  cp -f "3rd/lrust/target/release/librust.so" "./rust.so"
elif [ -f "3rd/lrust/target/release/librust.dylib" ]; then
  cp -f "3rd/lrust/target/release/librust.dylib" "./rust.dylib"
elif [ -f "3rd/lrust/target/release/rust.dll" ]; then
  cp -f "3rd/lrust/target/release/rust.dll" "./rust.dll"
else
  echo "ERROR: can't find built rust cdylib under 3rd/lrust/target/release/"
  exit 1
fi

echo
echo "==> Done."
echo "Next:"
echo "  lua test_lrust_simple.lua"
echo "  lua test_lrust.lua"

