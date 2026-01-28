# lrust 适配 ltask 设计方案

## 设计目标

直接修改 lrust 源码，使其原生支持 ltask 框架，无需兼容层。

## 架构设计

### 1. C 层 API (ltask 端)

在 `src/ltask.c` 中添加外部调用接口：

```c
// 从外部（Rust）发送消息到 ltask 服务
// 这个函数会被 Rust 代码通过 extern "C" 调用
int ltask_external_send_message(
    struct service_pool *pool,  // 服务池指针
    service_id to,              // 目标服务ID
    session_t session,          // 会话ID
    int msg_type,              // 消息类型（MESSAGE_RESPONSE）
    void *data,                // 数据指针
    size_t data_size           // 数据大小
);
```

### 2. Rust 层修改

#### 2.1 修改 `lib.rs` - 替换 moon_send

```rust
// 新的 ltask_send 函数
pub fn ltask_send<T>(
    service_pool: *mut c_void,  // service_pool 指针
    to: u32,                    // 目标服务ID
    session: u32,               // 会话ID（ltask使用u32）
    res: T
) {
    unsafe extern "C-unwind" {
        fn ltask_external_send_message(
            pool: *mut c_void,
            to: u32,
            session: u32,
            msg_type: i32,
            data: *const i8,
            data_size: usize
        ) -> i32;
    }
    
    if session == 0 {
        return;
    }
    
    // 序列化数据
    let serialized = serialize_result(&res);
    
    unsafe {
        ltask_external_send_message(
            service_pool,
            to,
            session,
            MESSAGE_RESPONSE,  // 使用 MESSAGE_RESPONSE 类型
            serialized.as_ptr() as *const i8,
            serialized.len()
        );
    }
}
```

#### 2.2 获取 service_pool 指针

在 Lua 层注册一个全局函数，供 Rust 获取当前服务的 service_pool：

```lua
-- 在 ltask 模块中
function ltask.get_service_pool()
    return service_pool_ptr  -- 通过 C API 获取
end
```

### 3. Lua 包装层设计

#### 3.1 新的 API 设计

不使用 Moon 风格的 API，直接使用 ltask 原生 API：

```lua
-- sqlx_ltask.lua
local ltask = require "ltask"
local c = require "rust.sqlx"

local M = {}

-- 连接数据库
function M.connect(database_url, name, timeout)
    local service_pool = ltask.get_service_pool()
    local session = ltask.next_session()  -- 生成会话ID
    
    -- 调用 Rust
    local result = c.connect(service_pool, ltask.self(), session, database_url, name, timeout)
    
    if result.error then
        error("connect failed: " .. result.error)
    end
    
    -- 等待异步结果
    return ltask.wait_session(session)
end

-- 查询
function M:query(sql, ...)
    local session = ltask.next_session()
    local service_pool = ltask.get_service_pool()
    
    -- 调用 Rust（异步）
    c.query_async(service_pool, ltask.self(), session, self.obj, sql, ...)
    
    -- 等待结果
    return ltask.wait_session(session)
end
```

#### 3.2 会话管理

在 `service.lua` 中添加会话管理：

```lua
-- 会话ID生成器
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
    return ltask.wait(token)
end

-- 唤醒会话（从消息处理中调用）
function ltask.wakeup_session(session, ...)
    local token = session_waiting[session]
    if token then
        session_waiting[session] = nil
        ltask.wakeup(token, ...)
    end
end
```

### 4. 消息处理流程

```
Lua 代码
  ↓
调用 Rust 函数（传入 service_pool, service_id, session）
  ↓
Rust 异步操作完成
  ↓
调用 ltask_external_send_message (C)
  ↓
ltask 消息系统
  ↓
service.lua 的 schedule_message
  ↓
识别为协议消息（MESSAGE_RESPONSE + session）
  ↓
调用 ltask.wakeup_session(session, result)
  ↓
唤醒等待的协程
```

## 实施步骤

### 步骤 1: 修改 ltask C 层

1. 在 `src/ltask.c` 中添加 `ltask_external_send_message` 函数
2. 在 `src/ltask.h` 中声明（如果需要）
3. 在 Lua 模块中暴露 `get_service_pool` 函数

### 步骤 2: 修改 Rust 层

1. 修改 `crates/libs/lib-lualib/src/lib.rs`：
   - 移除 `moon_send` 和 `moon_send_bytes`
   - 添加 `ltask_send` 和 `ltask_send_bytes`
   - 修改函数签名，接受 `service_pool` 指针

2. 修改所有使用 `moon_send` 的模块：
   - `lua_http.rs`
   - `lua_sqlx.rs`
   - `lua_mongodb.rs`
   - `lua_websocket.rs`
   - `lua_tiberius.rs`

### 步骤 3: 重写 Lua 包装层

1. 重写 `lualib/sqlx_ltask.lua`
2. 重写 `lualib/mongodb_ltask.lua`
3. 重写 `lualib/httpc_ltask.lua`
4. 等等...

### 步骤 4: 修改 service.lua

1. 添加会话管理函数
2. 在 `schedule_message` 中处理协议消息

## 关键设计决策

### 1. 消息类型

使用 `MESSAGE_RESPONSE` 类型传递协议消息，通过 `session` 字段区分不同的异步操作。

### 2. 数据序列化

Rust 层负责序列化数据，ltask 层只负责传递字节流。Lua 层负责反序列化。

### 3. 错误处理

- Rust 层：返回错误结构 `{error: "message"}`
- Lua 层：检查错误并抛出异常

### 4. 线程安全

`service_send_message` 和 `service_push_message` 需要确保线程安全，因为 Rust 的异步操作可能在任意线程中完成。

## 优势

1. ✅ **性能更好**：直接使用 ltask API，无兼容层开销
2. ✅ **代码更清晰**：不需要维护兼容层
3. ✅ **更好的集成**：完全符合 ltask 的设计理念
4. ✅ **易于维护**：代码结构更简单

## 注意事项

1. ⚠️ **内存管理**：确保 Rust 传递的数据生命周期正确
2. ⚠️ **线程安全**：确保多线程环境下消息发送安全
3. ⚠️ **错误处理**：完善的错误传播机制
