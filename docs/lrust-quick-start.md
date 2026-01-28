# lrust 适配 ltask 快速开始

## 已完成的工作 ✅

### 1. ltask C 层
- ✅ `src/ltask.c`: 添加 `ltask_external_send_message()` 函数
- ✅ `src/ltask.c`: 添加 `lget_service_pool()` 和 `lnext_session()` Lua 函数
- ✅ `src/ltask_external.h`: 外部 API 声明

### 2. Lua 层
- ✅ `lualib/service.lua`: 添加会话管理函数
  - `ltask.next_session()` - 生成会话ID
  - `ltask.wait_session(session)` - 等待会话结果
  - `ltask.wakeup_session(session, ...)` - 唤醒会话
- ✅ `lualib/service.lua`: 修改消息处理，支持来自 Rust 的消息

### 3. 文档和示例
- ✅ Rust ltask 集成模块: `3rd/lrust/crates/libs/lib-lualib/src/lib_ltask.rs`
- ✅ HTTP 模块修改示例: `3rd/lrust/crates/libs/lib-lualib/src/lua_http_ltask_example.rs`
- ✅ SQLx Lua 包装示例: `3rd/lrust/lualib/sqlx_ltask.lua`

## 下一步工作

### 1. 修改 Rust 代码

#### 修改 `lib.rs`

在 `3rd/lrust/crates/libs/lib-lualib/src/lib.rs` 中：

```rust
// 移除或注释掉 moon_send 相关代码
// 添加
pub mod lib_ltask;
pub use lib_ltask::{ltask_send_bytes, ltask_send_error};
```

#### 修改各个模块

参考 `lua_http_ltask_example.rs`，修改以下文件：

1. **`lua_http.rs`**
   - 添加 `service_pool: *mut c_void` 参数
   - 将 `session: i64` 改为 `session: u32`
   - 替换 `moon_send` 为 `ltask_send_bytes`

2. **`lua_sqlx.rs`** - 同样修改

3. **`lua_mongodb.rs`** - 同样修改

4. **其他模块** - 同样修改

### 2. 序列化方案

需要决定序列化格式。推荐使用 **bincode**:

```rust
// 在 Rust 中
let serialized = bincode::serialize(&response)?;
ltask_send_bytes(service_pool, owner, session, &serialized)?;
```

在 Lua 端需要对应的反序列化库。

### 3. 测试

1. 编译 ltask: `make`
2. 编译 Rust: `cd 3rd/lrust && cargo build`
3. 编写测试用例验证功能

## 使用示例

### Lua 端

```lua
local sqlx = require "sqlx_ltask"

-- 连接数据库
local db = sqlx.connect("postgres://user:pass@localhost/db", "mydb")

-- 查询
local rows = db:query("SELECT * FROM users WHERE id = $1", 123)

-- 事务
db:transaction({
    {"INSERT INTO users (name) VALUES ($1)", "Alice"},
    {"UPDATE stats SET count = count + 1"}
})
```

## 参考文档

- 设计文档: `docs/lrust-ltask-integration-design.md`
- 实施指南: `docs/lrust-implementation-guide.md`
- 实施状态: `docs/lrust-implementation-status.md`
