#!/bin/bash
# Build script for lrust with ltask support

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "========== Building lrust for ltask =========="
echo ""

# Check if Rust is installed
if ! command -v cargo &> /dev/null; then
    echo "ERROR: Rust/Cargo is not installed!"
    echo "Please install Rust from https://rustup.rs/"
    exit 1
fi

echo "✓ Rust/Cargo found: $(cargo --version)"
echo ""

# Check if ltask is built
if [ ! -f "target/release/libltask.a" ] && [ ! -f "target/release/libltask.so" ]; then
    echo "WARNING: ltask library not found in target/release/"
    echo "Building ltask first..."
    make clean
    make
    echo ""
fi

# Build lrust
echo "Building lrust..."
cd 3rd/lrust

# Set library path for linking
export LTASK_LIB_PATH="../../target/release"

# Build
echo "Running: cargo build --release"
cargo build --release

echo ""
echo "========== Build Complete =========="
echo ""

# Find the built library
LIB_PATH=""
if [ -f "target/release/librust.so" ]; then
    LIB_PATH="target/release/librust.so"
elif [ -f "target/release/librust.dylib" ]; then
    LIB_PATH="target/release/librust.dylib"
elif [ -f "target/release/rust.dll" ]; then
    LIB_PATH="target/release/rust.dll"
fi

if [ -n "$LIB_PATH" ]; then
    echo "✓ Library built: $LIB_PATH"
    echo ""
    echo "To use the library, set LUA_CPATH:"
    echo "  export LUA_CPATH=\"./3rd/lrust/$LIB_PATH;;\""
    echo ""
    echo "Or add to your Lua code:"
    echo "  package.cpath = package.cpath .. \";./3rd/lrust/$LIB_PATH\""
else
    echo "WARNING: Could not find built library"
    echo "Check target/release/ directory"
fi

echo ""
echo "Next steps:"
echo "1. Run simple test: lua test_lrust_simple.lua"
echo "2. Run full test: lua test_lrust.lua"
