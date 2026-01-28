# lrust 适配 ltask - 完整指南

## 概述

本指南说明如何将 lrust（原为 Moon 框架设计）适配到 ltask 框架。

## 快速开始

### 1. 测试基础功能（不需要编译）

```bash
# 测试 ltask 扩展功能
lua test_lrust_simple.lua
```

这会验证：
- `ltask.get_service_pool()` 是否工作
- `ltask.next_session()` 是否工作
- 会话管理机制是否正常

### 2. 编译 lrust（需要 Rust）

```bash
# 使用自动化脚本
./build_lrust.sh

# 或手动编译
cd 3rd/lrust
cargo build --release
```

### 3. 运行完整测试

```bash
# 完整功能测试（需要 Rust 模块）
lua test_lrust.lua
```

## 文件结构

### 核心文件

- `src/ltask.c` - ltask C 实现（已添加外部 API）
- `src/ltask_external.h` - 外部 API 声明
- `lualib/service.lua` - ltask 服务框架（已添加会话管理）

### Rust 文件

- `3rd/lrust/crates/libs/lib-lualib/src/lib_ltask.rs` - ltask 集成模块
- `3rd/lrust/crates/libs/lib-lualib/src/lib.rs` - 需要修改，添加 ltask 支持
- `3rd/lrust/crates/libs/lib-lualib/src/lua_*.rs` - 各个模块，需要修改

### Lua 包装

- `3rd/lrust/lualib/sqlx_ltask.lua` - SQLx 包装示例
- `3rd/lrust/lualib/httpc_ltask.lua` - HTTP 包装示例（如果创建）

### 测试文件

- `test_lrust_simple.lua` - 简单测试配置
- `test_lrust.lua` - 完整测试配置
- `test/lrust_test_simple.lua` - 简单测试逻辑
- `test/lrust_test_bootstrap.lua` - 完整测试逻辑

### 文档

- `docs/lrust-ltask-integration-design.md` - 设计文档
- `docs/lrust-implementation-guide.md` - 实施指南
- `docs/lrust-build-guide.md` - 编译指南
- `BUILD_LRUST.md` - 快速编译指南

## 实施步骤

### 阶段 1: 基础验证 ✅

- [x] 添加 ltask C API
- [x] 添加 Lua 会话管理
- [x] 创建测试文件
- [x] 验证基础功能

### 阶段 2: Rust 代码修改 ⚠️

- [ ] 修改 `lib.rs` 添加 `lib_ltask` 模块
- [ ] 修改各个模块使用 `ltask_send_bytes`
- [ ] 更新函数签名添加 `service_pool` 参数
- [ ] 修改 `build.rs` 链接 ltask 库

### 阶段 3: Lua 包装层 ⚠️

- [ ] 创建所有模块的 Lua 包装
- [ ] 测试各个模块功能
- [ ] 完善错误处理

### 阶段 4: 测试和优化 ⚠️

- [ ] 编写完整测试用例
- [ ] 性能测试
- [ ] 文档完善

## 当前状态

### ✅ 已完成

1. ltask C 层扩展
2. Lua 会话管理
3. 测试框架
4. 文档和指南

### ⚠️ 待完成

1. Rust 代码修改
2. 编译配置调整
3. Lua 包装层完善
4. 完整测试

## 下一步

1. **立即可以做的**: 运行 `lua test_lrust_simple.lua` 测试基础功能
2. **需要 Rust 的**: 修改 Rust 代码后编译并测试
3. **参考文档**: 查看 `docs/` 目录下的详细文档

## 获取帮助

- 设计问题: 查看 `docs/lrust-ltask-integration-design.md`
- 实施问题: 查看 `docs/lrust-implementation-guide.md`
- 编译问题: 查看 `docs/lrust-build-guide.md`
- 测试问题: 查看 `test/README_lrust_test.md`
