# lrust 适配 ltask 实施状态

## ✅ 已完成的工作

### 1. ltask C 层修改

- ✅ **`src/ltask.c`**: 
  - 添加 `ltask_external_send_message()` 函数，供 Rust 调用
  - 添加 `lget_service_pool()` Lua 函数
  - 添加 `lnext_session()` Lua 函数

- ✅ **`src/ltask_external.h`**: 新建头文件，声明外部 API

### 2. Lua 层修改

- ✅ **`lualib/service.lua`**:
  - 添加 `ltask.next_session()` 函数
  - 添加 `ltask.wait_session()` 函数
  - 添加 `ltask.wakeup_session()` 函数
  - 修改 `schedule_message()` 处理来自 Rust 的消息（from == 0）

### 3. 文档和示例

- ✅ **`docs/lrust-ltask-integration-design.md`**: 完整的设计文档
- ✅ **`docs/lrust-implementation-guide.md`**: 详细的实施指南
- ✅ **`3rd/lrust/crates/libs/lib-lualib/src/lib_ltask.rs`**: Rust ltask 集成模块
- ✅ **`3rd/lrust/crates/libs/lib-lualib/src/lua_http_ltask_example.rs`**: HTTP 模块修改示例
- ✅ **`3rd/lrust/lualib/sqlx_ltask.lua`**: SQLx Lua 包装层示例

## ⚠️ 待完成的工作

### 1. Rust 层修改

#### 1.1 修改 `lib.rs`

**文件**: `3rd/lrust/crates/libs/lib-lualib/src/lib.rs`

**需要修改**:
```rust
// 移除或注释掉
// pub fn moon_send<T>(...)
// pub fn moon_send_bytes(...)

// 添加
pub mod lib_ltask;
pub use lib_ltask::{ltask_send, ltask_send_bytes, ltask_send_error};
```

#### 1.2 修改各个模块

需要修改以下文件，将 `moon_send` 替换为 `ltask_send`:

- [ ] `lua_http.rs` - HTTP 客户端
- [ ] `lua_sqlx.rs` - SQLx 数据库
- [ ] `lua_mongodb.rs` - MongoDB
- [ ] `lua_websocket.rs` - WebSocket
- [ ] `lua_tiberius.rs` - SQL Server

**修改要点**:

1. **函数签名修改**: 添加 `service_pool: *mut c_void` 参数
2. **Session 类型**: 将 `i64` 改为 `u32`
3. **调用方式**: 
   ```rust
   // 旧
   moon_send(protocol_type, owner, session, response);
   
   // 新
   let serialized = serialize_response(&response);
   ltask_send_bytes(service_pool, owner, session, &serialized)?;
   ```

4. **Lua 绑定**: 从 Lua 栈获取 `service_pool`:
   ```rust
   // 在 Lua 函数中
   let service_pool = laux::lua_get(state, "service_pool");
   // 或者从 upvalue/registry 获取
   ```

#### 1.3 序列化方案

需要决定使用什么序列化格式。选项：

- **选项 A**: 使用与 Moon 相同的格式（指针传递，需要 Rust 端管理内存）
- **选项 B**: 使用 bincode 序列化（推荐，更安全）
- **选项 C**: 使用 ltask 的 lua-seri 格式（需要实现 Rust 绑定）

**推荐**: 选项 B (bincode)，在 Lua 端使用对应的反序列化库。

### 2. Lua 包装层

需要为每个模块创建新的 Lua 包装：

- [ ] `sqlx_ltask.lua` ✅ (已创建示例)
- [ ] `mongodb_ltask.lua`
- [ ] `httpc_ltask.lua`
- [ ] `websocket_ltask.lua`
- [ ] `sqlserver_ltask.lua`

**参考**: `3rd/lrust/lualib/sqlx_ltask.lua`

### 3. 编译和链接

#### 3.1 修改 Rust 构建配置

**文件**: `3rd/lrust/crates/libs/lib-lualib/Cargo.toml`

可能需要添加依赖：
```toml
[dependencies]
bincode = "1.3"  # 如果使用 bincode 序列化
```

#### 3.2 链接 ltask 库

需要确保 Rust 代码能够链接到 ltask 的 C 函数：

**文件**: `3rd/lrust/crates/libs/lib-lualib/build.rs` (如果存在)

可能需要添加：
```rust
println!("cargo:rustc-link-lib=ltask");
```

或者通过 FFI 直接声明函数（已在 `lib_ltask.rs` 中实现）。

### 4. 测试

- [ ] 单元测试: 测试 C API 函数
- [ ] 集成测试: 测试 Rust -> C -> Lua 完整流程
- [ ] 功能测试: 
  - [ ] HTTP 客户端测试
  - [ ] SQLx 数据库测试
  - [ ] MongoDB 测试

## 实施优先级

### 高优先级 (核心功能)

1. ✅ ltask C API (已完成)
2. ✅ service.lua 会话管理 (已完成)
3. ⚠️ 修改 `lib.rs` 添加 ltask 支持
4. ⚠️ 修改一个简单模块（如 `lua_http.rs`）进行验证
5. ⚠️ 创建对应的 Lua 包装层

### 中优先级 (完整功能)

6. 修改所有 Rust 模块
7. 创建所有 Lua 包装层
8. 完善错误处理

### 低优先级 (优化)

9. 性能优化
10. 文档完善
11. 测试覆盖

## 关键决策点

### 1. 序列化格式

**建议**: 使用 bincode，因为：
- 类型安全
- 跨语言兼容性好
- Rust 生态成熟

**Lua 端**: 需要实现 bincode 解码器，或使用其他序列化格式（如 MessagePack）。

### 2. service_pool 传递方式

**选项 A**: 作为函数参数传递（推荐）
- 优点: 明确，易于理解
- 缺点: 需要修改所有函数签名

**选项 B**: 存储在 Lua registry 或 upvalue
- 优点: 不需要修改函数签名
- 缺点: 需要额外的获取逻辑

**建议**: 选项 A，更清晰。

### 3. Session ID 生成

当前实现使用简单的计数器，在多线程环境下可能需要原子操作。

**改进**: 使用原子计数器或线程局部存储。

## 下一步行动

1. **立即开始**: 修改 `lib.rs`，添加 `lib_ltask` 模块
2. **验证流程**: 修改 `lua_http.rs`，测试完整流程
3. **逐步迁移**: 依次修改其他模块
4. **完善测试**: 编写测试用例确保功能正确

## 参考文件

- 设计文档: `docs/lrust-ltask-integration-design.md`
- 实施指南: `docs/lrust-implementation-guide.md`
- Rust 示例: `3rd/lrust/crates/libs/lib-lualib/src/lua_http_ltask_example.rs`
- Lua 示例: `3rd/lrust/lualib/sqlx_ltask.lua`
