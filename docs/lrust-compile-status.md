# lrust 编译状态检查

## 当前状态

### ❌ **不能直接编译**

原因：
1. **Rust 代码还未修改**：所有模块仍在使用 `moon_send`，而不是 `ltask_send_bytes`
2. **build.rs 还在链接 moon**：需要修改为链接 ltask
3. **lib.rs 未添加 ltask 模块**：`lib_ltask.rs` 已创建但未在 `lib.rs` 中引用

## 需要完成的修改

### 1. 修改 `lib.rs`

**文件**: `3rd/lrust/crates/libs/lib-lualib/src/lib.rs`

需要添加：
```rust
pub mod lib_ltask;
pub use lib_ltask::{ltask_send_bytes, ltask_send_error};
```

### 2. 修改 `build.rs`

**文件**: `3rd/lrust/crates/libs/lib-lualib/build.rs`

需要修改为链接 ltask 而不是 moon：
```rust
// 替换 moon 为 ltask
println!("cargo:rustc-link-lib=ltask");
```

### 3. 修改各个模块

需要修改以下文件，将 `moon_send` 替换为 `ltask_send_bytes`：
- `lua_http.rs`
- `lua_sqlx.rs`
- `lua_mongodb.rs`
- `lua_websocket.rs`
- `lua_tiberius.rs`

## 如果现在尝试编译会发生什么？

### 情况 1: build.rs 链接 moon（当前状态）

```bash
./build_lrust.sh
```

**结果**: 
- ✅ 编译会成功（因为代码还在用 moon_send，链接 moon 库）
- ❌ 但功能不对（因为实际运行环境是 ltask，不是 moon）
- ❌ 运行时会出现链接错误或功能异常

### 情况 2: 修改 build.rs 链接 ltask（但代码未改）

**结果**:
- ❌ 编译会失败
- 错误：`undefined reference to 'send_integer_message'` 或类似
- 因为代码还在调用 moon 的函数，但链接的是 ltask 库

## 正确的编译流程

### 步骤 1: 修改 Rust 代码

1. 修改 `lib.rs` 添加 ltask 支持
2. 修改各个模块使用 `ltask_send_bytes`
3. 更新函数签名添加 `service_pool` 参数

### 步骤 2: 修改 build.rs

修改为链接 ltask 库

### 步骤 3: 编译

```bash
./build_lrust.sh
```

## 快速检查清单

在编译前，确认：

- [ ] `lib.rs` 中添加了 `pub mod lib_ltask;`
- [ ] `build.rs` 链接的是 `ltask` 而不是 `moon`
- [ ] 至少一个模块（如 `lua_http.rs`）已修改为使用 `ltask_send_bytes`
- [ ] 函数签名已更新（添加 `service_pool` 参数）

## 建议

**现在不要直接编译**，因为：
1. 代码还未适配 ltask
2. 即使编译成功，功能也不会正常工作

**应该先**：
1. 参考 `docs/lrust-implementation-guide.md` 修改代码
2. 至少修改一个简单模块（如 HTTP）进行验证
3. 然后再编译测试
