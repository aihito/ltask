# lrust 模块适配 ltask 评估报告

## 概述

本报告评估将 `3rd/lrust` 中的 Lua 模块（特别是数据库模块如 MySQL、MongoDB 等）适配到 ltask 框架的可行性和实施方案。

## 框架差异分析

### Moon 框架 (lrust 当前设计目标)

lrust 模块是为 **Moon** 框架设计的，使用以下机制：

1. **异步等待机制**: `moon.wait(session)`
   - `session` 是一个数字标识符，由 Rust 库返回
   - Moon 框架通过 session 号匹配请求和响应

2. **会话管理**: 
   - `moon.id` - 当前服务 ID
   - `moon.next_sequence()` - 生成唯一的 session 序列号

3. **协议注册**: `moon.register_protocol()`
   - 注册自定义协议类型
   - 定义 pack/unpack 函数

4. **异步执行**: `moon.async(function() ... end)`

### Ltask 框架 (目标框架)

ltask 使用不同的异步模型：

1. **异步等待机制**: `ltask.wait(token)`
   - `token` 是协程对象或自定义标识符
   - 通过 `ltask.wakeup(token, ...)` 唤醒等待的协程

2. **会话管理**:
   - 内部使用 `session_id` 管理
   - 通过 `session_coroutine_suspend_lookup` 映射 session 到协程

3. **消息传递**: `ltask.call()`, `ltask.send()`
   - 基于服务地址和消息类型
   - 使用 `MESSAGE_REQUEST`, `MESSAGE_RESPONSE`, `MESSAGE_ERROR` 等类型

4. **协程模型**: 基于 Lua 协程的异步执行

## 关键差异点

### 1. 等待机制差异

**Moon 方式**:
```lua
local session = c.request(opts, protocol_type)  -- 返回 session 号
return moon.wait(session)  -- 等待该 session 的响应
```

**Ltask 方式**:
```lua
local token = {}  -- 创建 token
ltask.wait(token)  -- 等待 token 被唤醒
-- 在回调中: ltask.wakeup(token, result)
```

### 2. 会话标识差异

- **Moon**: 使用数字 session ID，由 `moon.next_sequence()` 生成
- **Ltask**: 使用协程对象或自定义 token，通过 `session_coroutine_suspend_lookup` 管理

### 3. 协议处理差异

- **Moon**: 通过 `moon.register_protocol()` 注册协议，框架自动路由
- **Ltask**: 需要手动处理消息类型和路由

## 适配方案

### 方案 A: 创建适配层 (推荐)

创建一个适配层，将 Moon 风格的 API 转换为 Ltask 风格的 API。

#### 实现思路

1. **创建 `moon_compat.lua` 适配模块**:
   ```lua
   local moon_compat = {}
   
   -- 模拟 moon.id
   function moon_compat.id()
       return ltask.self()
   end
   
   -- 模拟 moon.next_sequence()
   local sequence_counter = 0
   function moon_compat.next_sequence()
       sequence_counter = sequence_counter + 1
       return sequence_counter
   end
   
   -- 模拟 moon.wait(session)
   local session_tokens = {}  -- session_id -> token 映射
   function moon_compat.wait(session)
       local token = {}
       session_tokens[session] = token
       return ltask.wait(token)
   end
   
   -- 从 Rust 回调中调用此函数来唤醒等待
   function moon_compat.wakeup_session(session, ...)
       local token = session_tokens[session]
       if token then
           session_tokens[session] = nil
           ltask.wakeup(token, ...)
       end
   end
   ```

2. **修改 lrust 模块**:
   - 将 `require "moon"` 改为 `require "moon_compat"`
   - 保持其他代码逻辑不变

3. **修改 Rust 层** (如果需要):
   - 确保 Rust 回调能够调用 Lua 的 `moon_compat.wakeup_session()`
   - 或者通过 ltask 的消息机制传递结果

#### 优点
- ✅ 最小化代码修改
- ✅ 保持 lrust 模块的原有逻辑
- ✅ 易于维护和升级

#### 缺点
- ⚠️ 需要确保 Rust 层能够正确回调 Lua
- ⚠️ 可能需要修改 Rust 代码以适配 ltask 的消息机制

### 方案 B: 直接重写 Lua 包装层

完全重写 lrust 的 Lua 包装层，直接使用 ltask API。

#### 实现思路

1. **重写 `sqlx.lua`**:
   ```lua
   local ltask = require "ltask"
   local c = require "rust.sqlx"
   
   -- 不使用协议注册，直接处理
   local function query_with_wait(obj, sql, ...)
       local token = {}
       local session = generate_session()  -- 自定义 session 生成
       
       -- 调用 Rust 层，传入回调信息
       local result = obj:query_async(ltask.self(), session, sql, ...)
       
       if type(result) == "table" then
           return result  -- 立即返回错误
       end
       
       -- 等待异步结果
       return ltask.wait(token)
   end
   ```

2. **修改 Rust 层**:
   - 修改 Rust 代码，使其能够通过 ltask 的消息机制发送响应
   - 或者使用 ltask 提供的 C API 来唤醒协程

#### 优点
- ✅ 完全符合 ltask 的设计理念
- ✅ 更好的性能和集成度

#### 缺点
- ❌ 需要大量修改代码
- ❌ 需要深入理解 Rust 层的实现
- ❌ 维护成本高

### 方案 C: 混合方案 (最实用)

保留 Rust 层的核心逻辑，只修改 Lua 包装层，创建一个轻量级适配器。

## 技术可行性评估

### ✅ 可行的部分

1. **Lua 层适配**: 
   - ltask 支持协程和 `ltask.wait()`，可以模拟 `moon.wait()`
   - 可以创建 session 到 token 的映射机制

2. **异步模型兼容**:
   - 两者都基于协程，模型相似
   - ltask 的 `ltask.wait()` 和 `ltask.wakeup()` 可以替代 Moon 的机制

### ⚠️ 需要解决的部分

1. **Rust 回调机制**:
   - 需要确保 Rust 层能够正确回调到 Lua
   - 可能需要修改 Rust 代码以使用 ltask 的消息系统

2. **协议注册**:
   - ltask 没有 `register_protocol` 机制
   - 需要手动处理消息路由

3. **底层集成**:
   - 需要检查 Rust 层是否依赖 Moon 的特定 C API
   - 可能需要修改 Rust 的 Lua 绑定代码

## 实施建议

### 阶段 1: 可行性验证 (1-2 天)

1. 创建一个简单的适配层 `moon_compat.lua`
2. 尝试适配一个简单的模块（如 `httpc.lua`）
3. 验证基本的异步调用是否工作

### 阶段 2: 数据库模块适配 (3-5 天)

1. 适配 `sqlx.lua` (MySQL/PostgreSQL)
2. 适配 `mongodb.lua`
3. 测试各种数据库操作

### 阶段 3: 完善和优化 (2-3 天)

1. 处理错误情况
2. 性能优化
3. 文档和示例

## 关键发现：Rust 层的 C 函数依赖

经过代码分析，发现 **Rust 层依赖 Moon 框架提供的 C 函数**：

### Rust 层调用的 C 函数

在 `3rd/lrust/crates/libs/lib-lualib/src/lib.rs` 中：

```rust
pub fn moon_send<T>(protocol_type: u8, owner: u32, session: i64, res: T) {
    unsafe extern "C-unwind" {
        unsafe fn send_integer_message(type_: u8, receiver: u32, session: i64, val: isize);
    }
    // ...
    send_integer_message(protocol_type, owner, session, ptr as isize);
}

pub fn moon_send_bytes(protocol_type: u8, owner: u32, session: i64, data: &[u8]) {
    unsafe extern "C-unwind" {
        unsafe fn send_message(type_: u8, receiver: u32, session: i64, data: *const i8, len: usize);
    }
    // ...
    send_message(protocol_type, owner, session, data.as_ptr() as *const i8, data.len());
}
```

### 解决方案

需要为 ltask 提供等价的 C 函数实现：

1. **实现 `send_integer_message` 和 `send_message` C 函数**:
   - 这些函数需要调用 ltask 的 C API 来发送消息
   - 需要将 protocol_type, owner, session 映射到 ltask 的消息系统

2. **在 ltask 中注册这些函数**:
   - 通过 Lua C API 注册为全局函数
   - 或者通过 ltask 的扩展机制注册

3. **消息路由**:
   - 在 ltask 的消息处理中识别这些协议类型
   - 将消息路由到对应的 `moon_compat.wakeup_session()`

## 风险评估

### 低风险
- ✅ Lua 层代码修改
- ✅ 适配层创建

### 中风险
- ⚠️ Rust 层回调机制
- ⚠️ 协议处理
- ⚠️ **需要实现 C 函数桥接层**

### 高风险
- ❌ **必须实现 `send_integer_message` 和 `send_message` 的 ltask 版本**
- ❌ 如果 ltask 的 C API 不支持从外部 C 函数发送消息，可能需要修改 ltask 核心代码

## 结论

**总体评估: 可行，但需要一定工作量**

1. **推荐方案**: 方案 A (适配层) 或方案 C (混合方案)
2. **工作量**: 中等 (约 1-2 周)
3. **风险**: 中等，主要取决于 Rust 层的依赖程度
4. **收益**: 高，可以复用 lrust 的成熟数据库驱动

## 下一步行动

1. ✅ 创建 `moon_compat.lua` 适配层原型
2. ✅ 选择一个简单模块（如 `httpc.lua`）进行验证
3. ✅ 如果验证成功，逐步适配数据库模块
4. ✅ 编写测试用例确保功能正确

## 参考代码位置

- lrust Lua 模块: `3rd/lrust/lualib/`
- ltask 服务框架: `lualib/service.lua`
- ltask 协程处理: `test/coroutine.lua`
