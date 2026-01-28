# lrust 编译指南

## 前置要求

1. **Rust 工具链**: 需要安装 Rust (https://rustup.rs/)
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   ```

2. **ltask 已编译**: 确保 ltask 已经编译完成
   ```bash
   cd /home/game/open-source/game-server/ltask
   make
   ```

## 编译步骤

### 步骤 1: 修改 build.rs（如果需要链接 ltask）

**文件**: `3rd/lrust/crates/libs/lib-lualib/build.rs`

当前 build.rs 链接的是 `moon` 库，需要修改为链接 `ltask`：

```rust
fn main() {
    println!("cargo:rerun-if-changed=lualib-src");

    // Link to ltask library instead of moon
    let ltask_lib_path = env::var("LTASK_LIB_PATH")
        .unwrap_or_else(|_| "../target/release".to_string());
    
    println!("cargo:rustc-link-search=native={}", ltask_lib_path);
    println!("cargo:rustc-link-lib=ltask");

    if cfg!(target_os = "macos") {
        println!("cargo:rustc-cdylib-link-arg=-undefined");
        println!("cargo:rustc-cdylib-link-arg=dynamic_lookup");
    }
}
```

### 步骤 2: 修改 Rust 代码

参考 `docs/lrust-implementation-guide.md` 修改 Rust 代码：

1. 修改 `lib.rs` 添加 `lib_ltask` 模块
2. 修改各个模块使用 `ltask_send_bytes` 替代 `moon_send`

### 步骤 3: 编译 lrust

```bash
cd 3rd/lrust

# Debug 版本（开发用）
cargo build

# Release 版本（生产用）
cargo build --release
```

编译产物位置：
- Linux: `target/release/librust.so` 或 `target/debug/librust.so`
- macOS: `target/release/librust.dylib` 或 `target/debug/librust.dylib`
- Windows: `target/release/rust.dll` 或 `target/debug/rust.dll`

### 步骤 4: 配置 Lua 加载路径

确保 Lua 能够找到编译好的库：

**方法 1: 设置环境变量**

```bash
# Linux/macOS
export LUA_CPATH="./3rd/lrust/target/release/?.so;./3rd/lrust/target/release/?.dylib;;"

# 或者在 lua 代码中
package.cpath = package.cpath .. ";./3rd/lrust/target/release/?.so"
```

**方法 2: 复制到系统库目录**

```bash
# Linux
cp 3rd/lrust/target/release/librust.so /usr/local/lib/

# macOS
cp 3rd/lrust/target/release/librust.dylib /usr/local/lib/
```

## 编译选项

### 选择功能模块

在 `Cargo.toml` 中可以启用/禁用特定功能：

```bash
# 只编译 HTTP 和 SQLx
cargo build --release --no-default-features --features "http,sqlx,json"

# 编译所有功能（默认）
cargo build --release

# 排除某些功能
cargo build --release --no-default-features --features "http,sqlx,json,mongodb"
```

### 可用功能

- `excel` - Excel 读取
- `sqlx` - SQLx 数据库（MySQL, PostgreSQL, SQLite）
- `mongodb` - MongoDB
- `websocket` - WebSocket 客户端
- `http` - HTTP 客户端
- `json` - JSON 处理
- `tiberius` - SQL Server

## 常见问题

### 问题 1: 找不到 ltask 库

**错误**: `error: could not find native static library 'ltask'`

**解决**:
1. 确保 ltask 已编译
2. 设置 `LTASK_LIB_PATH` 环境变量指向 ltask 库目录
3. 或修改 `build.rs` 中的路径

### 问题 2: 链接错误

**错误**: `undefined reference to 'ltask_external_send_message'`

**解决**:
1. 确保 `src/ltask.c` 中的 `ltask_external_send_message` 函数已添加
2. 重新编译 ltask: `make clean && make`
3. 确保链接了正确的 ltask 库

### 问题 3: Lua 找不到模块

**错误**: `module 'rust.httpc' not found`

**解决**:
1. 检查 `package.cpath` 是否包含库路径
2. 检查库文件是否存在
3. 检查库文件权限

### 问题 4: 运行时错误

**错误**: `attempt to call a nil value`

**解决**:
1. 确保 Rust 代码已修改为使用 `ltask_send_bytes`
2. 确保 `lib_ltask.rs` 模块已正确添加
3. 检查函数签名是否正确

## 验证编译

编译完成后，可以运行简单测试：

```bash
# 测试基础功能（不需要 Rust 模块）
lua test_lrust_simple.lua

# 如果编译成功，可以测试完整功能
lua test_lrust.lua
```

## 开发流程

1. **修改 Rust 代码**
2. **编译**: `cd 3rd/lrust && cargo build`
3. **测试**: `cd ../.. && lua test_lrust.lua`
4. **调试**: 使用 `cargo build` (debug 版本) 进行调试
5. **发布**: 使用 `cargo build --release` 构建发布版本

## 自动化编译脚本

可以创建一个脚本自动编译：

```bash
#!/bin/bash
# build_lrust.sh

set -e

echo "Building lrust for ltask..."

cd 3rd/lrust

# 设置 ltask 库路径
export LTASK_LIB_PATH="../../target/release"

# 编译
cargo build --release

echo "Build complete!"
echo "Library location: target/release/librust.so"
```

## 下一步

编译完成后，参考：
- `docs/lrust-implementation-guide.md` - 实施指南
- `test/README_lrust_test.md` - 测试说明
