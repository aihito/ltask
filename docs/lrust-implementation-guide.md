# lrust 适配 ltask 实施指南

## 概述

本指南详细说明如何修改 lrust 源码以适配 ltask 框架。

## 修改清单

### 1. ltask C 层修改 ✅

**文件**: `src/ltask.c`

- ✅ 添加 `ltask_external_send_message()` 函数
- ✅ 添加 `lget_service_pool()` Lua 函数
- ✅ 添加 `lnext_session()` Lua 函数

**文件**: `src/ltask_external.h` (新建)

- ✅ 声明外部 API

### 2. Rust 层修改

#### 2.1 修改 `lib.rs`

**文件**: `3rd/lrust/crates/libs/lib-lualib/src/lib.rs`

**修改内容**:
```rust
// 移除 moon_send 相关代码
// 添加 ltask 支持
pub mod lib_ltask;

pub use lib_ltask::{ltask_send, ltask_send_bytes, ltask_send_error};
```

#### 2.2 创建新的 ltask 模块

**文件**: `3rd/lrust/crates/libs/lib-lualib/src/lib_ltask.rs` ✅ (已创建)

#### 2.3 修改各个模块

需要修改以下文件，将 `moon_send` 替换为 `ltask_send`:

- `lua_http.rs`
- `lua_sqlx.rs`
- `lua_mongodb.rs`
- `lua_websocket.rs`
- `lua_tiberius.rs`

**修改模式**:
```rust
// 旧代码
moon_send(protocol_type, req.owner, req.session, response);

// 新代码
// 需要从 Lua 获取 service_pool 指针
// 在函数参数中添加 service_pool: *mut c_void
ltask_send_bytes(service_pool, req.owner, req.session, &serialized_data)?;
```

### 3. Lua 包装层修改

#### 3.1 修改 `service.lua`

**文件**: `lualib/service.lua`

添加会话管理:

```lua
-- 会话ID生成器（使用线程局部存储或原子操作）
local session_counter = 0
function ltask.next_session()
    session_counter = session_counter + 1
    return session_counter
end

-- 会话等待表
local session_waiting = {}  -- session_id -> token

-- 等待会话结果
function ltask.wait_session(session)
    local token = {}
    session_waiting[session] = token
    local results = {ltask.wait(token)}
    session_waiting[session] = nil
    return table.unpack(results)
end

-- 唤醒会话（在消息处理中调用）
function ltask.wakeup_session(session, ...)
    local token = session_waiting[session]
    if token then
        session_waiting[session] = nil
        ltask.wakeup(token, ...)
    end
end
```

修改 `schedule_message` 函数，处理来自 Rust 的消息:

```lua
local function schedule_message()
    local from, session, type, msg, sz = ltask.recv_message()
    
    -- 处理来自 Rust 的响应消息
    if type == MESSAGE_RESPONSE and from == 0 then
        -- from == 0 表示来自外部（Rust）
        -- 通过 session 唤醒等待的协程
        local decoded = ltask.unpack_remove(msg, sz)
        ltask.wakeup_session(session, decoded)
        return
    end
    
    -- ... 现有的消息处理 ...
end
```

#### 3.2 创建新的 Lua 包装模块

**文件**: `3rd/lrust/lualib/sqlx_ltask.lua` (新建)

```lua
--- SQLx for Ltask
---@diagnostic disable: inject-field, undefined-global
local ltask = require "ltask"
local c = require "rust.sqlx"

local M = {}

--- Connect to database
function M.connect(database_url, name, timeout)
    local service_pool = ltask.get_service_pool()
    local service_id = ltask.self()
    local session = ltask.next_session()
    
    local result = c.connect(service_pool, service_id, session, database_url, name, timeout)
    
    if result.error then
        error("connect failed: " .. result.error)
    end
    
    -- Wait for async result
    return ltask.wait_session(session)
end

--- Find connection
function M.find_connection(name)
    local o = {
        obj = c.find_connection(name)
    }
    return setmetatable(o, { __index = M })
end

--- Query
function M:query(sql, ...)
    local service_pool = ltask.get_service_pool()
    local service_id = ltask.self()
    local session = ltask.next_session()
    
    -- Call Rust async
    c.query_async(service_pool, service_id, session, self.obj, sql, ...)
    
    -- Wait for result
    return ltask.wait_session(session)
end

-- ... 其他方法类似 ...

return M
```

## 实施步骤

### 步骤 1: 编译 ltask 并测试 C API

```bash
cd /home/game/open-source/game-server/ltask
make
```

### 步骤 2: 修改 Rust 代码

1. 修改 `lib.rs`，添加 `lib_ltask` 模块
2. 修改各个模块，替换 `moon_send` 为 `ltask_send`
3. 更新函数签名，添加 `service_pool` 参数

### 步骤 3: 更新 Lua 绑定

在 Rust 的 Lua 绑定代码中，从 Lua 栈获取 `service_pool`:

```rust
// 在 Lua 函数中
let service_pool = lua.get::<*mut c_void>(1)?;  // 从 Lua 获取
```

### 步骤 4: 修改 service.lua

添加会话管理函数和消息处理逻辑。

### 步骤 5: 创建新的 Lua 包装

为每个模块创建新的 Lua 包装文件。

### 步骤 6: 测试

编写测试用例验证功能。

## 关键注意事项

### 1. 线程安全

`ltask_external_send_message` 可能从任意线程调用（Rust 的异步运行时），需要确保 `service_push_message` 是线程安全的。

### 2. 内存管理

- Rust 传递的数据会被复制到 C 层
- C 层负责释放消息内存
- 确保没有内存泄漏

### 3. 序列化

需要决定使用什么序列化格式：
- 选项 1: 使用与 Moon 相同的格式（指针传递）
- 选项 2: 使用 bincode 或其他序列化库
- 选项 3: 使用 ltask 的 lua-seri 格式

### 4. 错误处理

确保错误能够正确传播到 Lua 层。

## 测试计划

1. **单元测试**: 测试 C API 函数
2. **集成测试**: 测试 Rust -> C -> Lua 的完整流程
3. **功能测试**: 测试各个模块（HTTP, SQL, MongoDB 等）

## 参考

- ltask 源码: `src/`
- lrust 源码: `3rd/lrust/`
- 设计文档: `docs/lrust-ltask-integration-design.md`
