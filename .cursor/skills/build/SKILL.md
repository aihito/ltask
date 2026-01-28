---
name: build
description: Build the ltask project. Supports clean, debug, and release build modes. Use when compiling the ltask C extension library.
---

# Build ltask Project

## When to Use

- Use this skill when you need to compile the ltask project
- Use `/build clean` to clean build artifacts
- Use `/build debug` for debug builds with debug symbols
- Use `/build release` for optimized release builds
- Use `/build` or `/build default` for standard builds

## Instructions

### 1. Check Prerequisites

First, verify that required dependencies are installed:

- **Lua development libraries**: Check using `pkgconf lua --cflags`
- **Make**: Ensure `make` command is available
- **C compiler**: Ensure `gcc` or `clang` is available

If Lua is not found, prompt the user to install it:
- Linux: `sudo apt-get install lua5.4-dev` (or appropriate version)
- macOS: `brew install lua`
- Windows: Install Lua development libraries manually

### 2. Determine Build Mode

Parse the user's request to determine the build mode:
- **default**: Standard build with default CFLAGS
- **clean**: Remove all build artifacts (`.so`, `.dll` files)
- **debug**: Build with debug symbols (`-g` flag, no optimization)
- **release**: Build with optimizations (`-O2 -DNDEBUG`)

### 3. Execute Build Command

Based on the build mode, execute the appropriate command:

**Default Build:**
```bash
make
```

**Clean:**
```bash
make clean
```

**Debug Build:**
```bash
CFLAGS="-g -Wall" make
```

**Release Build:**
```bash
CFLAGS="-O2 -DNDEBUG -Wall" make
```

### 4. Verify Build Success

After execution:
- Check if the build command exited successfully (exit code 0)
- Verify the output file exists:
  - Linux/Mac: `ltask.so`
  - Windows: `ltask.dll`
- Report the build result to the user

### 5. Handle Errors

If the build fails:
- Capture and display the error output
- Check common issues:
  - Missing Lua headers
  - Missing system libraries (pthread on Linux/Mac)
  - Compilation errors in source files
- Provide helpful suggestions based on the error message

## Build System Details

The project uses a traditional Makefile:
- **Source files**: Located in `src/` directory
- **Output**: `ltask.so` (Linux/Mac) or `ltask.dll` (Windows)
- **Dependencies**: Lua development libraries, pthread (Linux/Mac)
- **Platform detection**: Makefile automatically detects OS (Linux/Mac/Windows)

## Example Usage

- User: "Build the project" → Execute `make`
- User: "Clean build artifacts" → Execute `make clean`
- User: "Build in debug mode" → Execute `CFLAGS="-g -Wall" make`
- User: "Build for release" → Execute `CFLAGS="-O2 -DNDEBUG -Wall" make`

## Notes

- The Makefile automatically handles platform differences
- CFLAGS can be overridden via environment variables
- The build produces a shared library that Lua can load via `require`
