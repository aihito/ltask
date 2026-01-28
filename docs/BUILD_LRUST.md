# 编译 lrust 快速指南

## 快速开始

### 1. 先编译 ltask

```bash
cd /home/game/open-source/game-server/ltask
make clean
make
```

### 2. 修改 build.rs（如果需要）

如果需要链接 ltask 库，可以：

```bash
# 备份原文件
cp 3rd/lrust/crates/libs/lib-lualib/build.rs 3rd/lrust/crates/libs/lib-lualib/build.rs.moon

# 使用 ltask 版本（如果已创建）
cp 3rd/lrust/crates/libs/lib-lualib/build.rs.ltask 3rd/lrust/crates/libs/lib-lualib/build.rs
```

### 3. 编译 lrust

**方法 1: 使用脚本（推荐）**

```bash
./build_lrust.sh
```

**方法 2: 手动编译**

```bash
cd 3rd/lrust
export LTASK_LIB_PATH="../../target/release"
cargo build --release
```

### 4. 测试

```bash
# 基础测试（不需要 Rust）
lua test_lrust_simple.lua

# 完整测试（需要 Rust）
lua test_lrust.lua
```

## 完整流程

1. ✅ **编译 ltask**: `make`
2. ⚠️ **修改 Rust 代码**: 参考 `docs/lrust-implementation-guide.md`
3. ⚠️ **修改 build.rs**: 链接 ltask 而不是 moon
4. ✅ **编译 lrust**: `./build_lrust.sh` 或 `cargo build --release`
5. ✅ **测试**: `lua test_lrust_simple.lua`

## 详细文档

- 编译指南: `docs/lrust-build-guide.md`
- 实施指南: `docs/lrust-implementation-guide.md`
- 测试说明: `test/README_lrust_test.md`
