# 快速开始测试

## 最简单的测试（不需要 Rust 模块）

这个测试只验证 ltask 的扩展功能是否正常工作。

```bash
# 运行简单测试
lua test_lrust_simple.lua
```

**预期输出**:
```
========== Simple lrust-ltask Test ==========

1. Testing ltask.get_service_pool()
   Service pool pointer: 0x...
   [PASS] get_service_pool works

2. Testing ltask.next_session()
   Session 1: 1
   Session 2: 2
   ...
   [PASS] next_session increments correctly

3. Testing session waiting mechanism
   Created test session: 6
   Session registered for waiting
   [INFO] In real usage, Rust would call ltask_external_send_message

4. Testing service ID
   Current service ID: 5
   [PASS] Service ID is valid

========== Basic Tests Complete ==========
```

## 完整测试（需要 Rust 模块）

当 Rust 代码修改完成后，可以运行完整测试：

```bash
# 运行完整测试
lua test_lrust.lua
```

## 测试文件说明

| 文件 | 用途 | 是否需要 Rust |
|------|------|--------------|
| `test_lrust_simple.lua` | 基础功能测试 | ❌ 不需要 |
| `test_lrust.lua` | 完整功能测试 | ✅ 需要 |
| `test/lrust_test_simple.lua` | 简单测试逻辑 | ❌ 不需要 |
| `test/lrust_test_bootstrap.lua` | 完整测试逻辑 | ✅ 需要 |

## 下一步

1. ✅ **先运行简单测试** - 验证 ltask 扩展功能
2. ⚠️ **修改 Rust 代码** - 参考 `docs/lrust-implementation-guide.md`
3. ⚠️ **编译 Rust 模块** - `cd 3rd/lrust && cargo build`
4. ⚠️ **运行完整测试** - `lua test_lrust.lua`
