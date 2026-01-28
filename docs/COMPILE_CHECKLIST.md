# lrust 编译检查清单

## ⚠️ 当前状态：**不能直接编译**

### 问题

1. **Rust 代码未修改**：
   - `lib.rs` 中还在使用 `moon_send`
   - 所有模块（http, sqlx, mongodb等）还在调用 `moon_send`
   - `lib_ltask.rs` 已创建但未在 `lib.rs` 中引用

2. **build.rs 配置未改**：
   - 还在链接 `moon` 库
   - 需要改为链接 `ltask` 库

3. **函数签名未更新**：
   - 需要添加 `service_pool: *mut c_void` 参数

## 如果现在编译会发生什么？

### 情况 A: 保持当前配置（链接 moon）

```bash
./build_lrust.sh
```

**结果**:
- ✅ 编译可能成功（如果 moon 库存在）
- ❌ 但运行时会出现问题（因为实际环境是 ltask）
- ❌ 功能不会正常工作

### 情况 B: 修改 build.rs 链接 ltask（但代码未改）

**结果**:
- ❌ 编译会失败
- 错误：`undefined reference to 'send_integer_message'`
- 因为代码还在调用 moon 的函数

## 需要完成的修改

### ✅ 已完成
- [x] 创建 `lib_ltask.rs` 模块
- [x] 创建 Lua 包装层（httpc_ltask.lua, sqlx_ltask.lua）
- [x] 添加 ltask C API
- [x] 添加 Lua 会话管理

### ❌ 待完成
- [ ] 修改 `lib.rs` 添加 `pub mod lib_ltask;`
- [ ] 修改 `build.rs` 链接 ltask 而不是 moon
- [ ] 修改 `lua_http.rs` 使用 `ltask_send_bytes`
- [ ] 修改 `lua_sqlx.rs` 使用 `ltask_send_bytes`
- [ ] 修改其他模块（mongodb, websocket等）
- [ ] 更新函数签名添加 `service_pool` 参数

## 建议的修改顺序

### 1. 最小修改（验证流程）

只修改一个简单模块进行验证：

1. 修改 `lib.rs`：
   ```rust
   pub mod lib_ltask;
   pub use lib_ltask::ltask_send_bytes;
   ```

2. 修改 `build.rs`：
   ```rust
   println!("cargo:rustc-link-lib=ltask");
   ```

3. 修改 `lua_http.rs`（最简单的模块）：
   - 添加 `service_pool` 参数
   - 替换 `moon_send` 为 `ltask_send_bytes`

4. 编译测试：
   ```bash
   ./build_lrust.sh
   ```

### 2. 完整修改

修改所有模块后编译。

## 快速检查命令

```bash
# 检查 lib.rs 是否添加了 lib_ltask
grep "lib_ltask" 3rd/lrust/crates/libs/lib-lualib/src/lib.rs

# 检查 build.rs 链接的是什么
grep "link-lib" 3rd/lrust/crates/libs/lib-lualib/build.rs

# 检查是否还有 moon_send
grep -r "moon_send" 3rd/lrust/crates/libs/lib-lualib/src/*.rs | grep -v "lib_ltask" | grep -v "example"
```

## 结论

**现在执行 `./build_lrust.sh` 不能完整编译出可用的 lrust**。

需要先完成 Rust 代码的修改，然后才能编译。

参考文档：
- `docs/lrust-implementation-guide.md` - 详细修改指南
- `docs/lrust-compile-status.md` - 编译状态说明
