# lrust 适配 ltask 总结

## 评估结论

**可行性**: ✅ **可行，但需要实现 C 层桥接**

**工作量**: 中等 (约 1-2 周)

**风险等级**: 中等

## 核心挑战

### 1. Rust 层依赖 Moon 的 C 函数

Rust 代码通过 `extern "C"` 调用以下函数（在 `lib.rs` 中）:
- `send_integer_message(type_: u8, receiver: u32, session: i64, val: isize)`
- `send_message(type_: u8, receiver: u32, session: i64, data: *const i8, len: usize)`

这些函数需要由 ltask 提供实现。

### 2. 解决方案

需要创建一个 **C 桥接层**，实现这些函数并调用 ltask 的 C API。

## 实施步骤

### 步骤 1: 创建 C 桥接层

创建 `src/lrust_bridge.c`:

```c
#include "ltask.h"
#include "service.h"
#include "message.h"
#include "lua-seri.h"

// 全局服务池指针（需要在初始化时设置）
static struct service_pool *g_service_pool = NULL;

void lrust_bridge_init(struct service_pool *pool) {
    g_service_pool = pool;
}

// 实现 send_integer_message (Moon 兼容)
void send_integer_message(uint8_t type, uint32_t receiver, int64_t session, intptr_t val) {
    if (g_service_pool == NULL) return;
    
    // 创建消息
    struct message msg = {
        .from = {0},  // 从外部调用，from 为 0
        .to = {receiver},
        .session = (session_t)session,
        .type = MESSAGE_RESPONSE,  // 或根据 type 映射
        .msg = (void*)val,
        .sz = sizeof(void*)
    };
    
    // 发送消息
    service_send_message(g_service_pool, (service_id){receiver}, &msg);
}

// 实现 send_message (Moon 兼容)
void send_message(uint8_t type, uint32_t receiver, int64_t session, 
                  const char *data, size_t len) {
    if (g_service_pool == NULL) return;
    
    // 分配消息缓冲区
    void *msg_buf = malloc(len);
    if (msg_buf == NULL) return;
    memcpy(msg_buf, data, len);
    
    // 创建消息
    struct message msg = {
        .from = {0},
        .to = {receiver},
        .session = (session_t)session,
        .type = MESSAGE_RESPONSE,
        .msg = msg_buf,
        .sz = len
    };
    
    // 发送消息
    service_send_message(g_service_pool, (service_id){receiver}, &msg);
}
```

### 步骤 2: 在 ltask 初始化时注册桥接层

在 `src/ltask.c` 的初始化代码中:

```c
extern void lrust_bridge_init(struct service_pool *pool);

// 在 ltask_init 或类似函数中
void ltask_init(...) {
    // ... 现有初始化代码 ...
    
    // 初始化 lrust 桥接层
    lrust_bridge_init(task->services);
}
```

### 步骤 3: 在 Lua 层处理协议消息

修改 `lualib/service.lua`，添加协议消息处理:

```lua
-- 在 schedule_message 函数中添加协议消息处理
local function schedule_message()
    local from, session, type, msg, sz = ltask.recv_message()
    
    -- 处理协议消息（来自 Rust 的回调）
    if type >= 20 and type <= 30 then  -- 协议类型范围
        local handler = protocol_handlers[type]
        if handler then
            local decoded = handler.unpack(msg, sz)
            -- 通过 moon_compat 唤醒等待的协程
            moon_compat.wakeup_session(session, decoded)
            return
        end
    end
    
    -- ... 现有的消息处理 ...
end
```

### 步骤 4: 使用适配层

在 Lua 代码中:

```lua
-- 使用适配后的模块
local sqlx = require "sqlx_ltask"  -- 适配后的版本
-- 或直接修改原模块使用 moon_compat
```

## 文件清单

### 需要创建的文件

1. ✅ `lualib/moon_compat.lua` - Moon API 兼容层
2. ⚠️ `src/lrust_bridge.c` - C 桥接层（需要实现）
3. ⚠️ `src/lrust_bridge.h` - C 桥接层头文件
4. ✅ `lualib/httpc_ltask.lua` - 适配示例

### 需要修改的文件

1. ⚠️ `src/ltask.c` - 添加桥接层初始化
2. ⚠️ `lualib/service.lua` - 添加协议消息处理
3. ⚠️ `3rd/lrust/lualib/*.lua` - 修改为使用 `moon_compat`

## 测试计划

### 阶段 1: 基础验证
- [ ] 验证 `moon_compat.lua` 基本功能
- [ ] 测试 `ltask.wait()` 和 `ltask.wakeup()` 机制
- [ ] 验证 C 桥接层能够发送消息

### 阶段 2: HTTP 客户端测试
- [ ] 适配 `httpc.lua`
- [ ] 测试 GET/POST 请求
- [ ] 验证异步回调正确工作

### 阶段 3: 数据库模块测试
- [ ] 适配 `sqlx.lua` (MySQL/PostgreSQL)
- [ ] 测试连接、查询、事务
- [ ] 适配 `mongodb.lua`
- [ ] 测试 CRUD 操作

## 潜在问题和解决方案

### 问题 1: 消息类型映射

**问题**: Moon 使用 protocol_type，ltask 使用 MESSAGE_TYPE

**解决**: 在桥接层中映射，或使用自定义消息类型范围 (20-30)

### 问题 2: 内存管理

**问题**: Rust 传递的数据需要正确管理生命周期

**解决**: 
- 对于 `send_integer_message`，数据在 Rust 端管理
- 对于 `send_message`，需要在 C 层复制数据

### 问题 3: 线程安全

**问题**: Rust 的异步操作可能在多线程环境中调用 C 函数

**解决**: 确保 `service_send_message` 是线程安全的，或使用消息队列

## 推荐实施顺序

1. **第一周**:
   - 实现 C 桥接层
   - 创建 `moon_compat.lua`
   - 适配一个简单模块（如 `httpc.lua`）进行验证

2. **第二周**:
   - 适配数据库模块（`sqlx.lua`, `mongodb.lua`）
   - 完善错误处理
   - 编写测试用例

## 参考资源

- lrust 源码: `3rd/lrust/`
- ltask 服务框架: `lualib/service.lua`
- ltask C API: `src/service.h`, `src/message.h`
- 评估报告: `docs/lrust-adaptation-evaluation.md`

## 结论

适配是**可行的**，主要工作在于：

1. ✅ Lua 层适配（已完成原型）
2. ⚠️ C 桥接层实现（需要实现）
3. ⚠️ 消息路由处理（需要实现）

一旦 C 桥接层完成，Lua 层的适配相对 straightforward。建议先实现一个简单的模块（如 HTTP 客户端）验证整个流程，然后再适配数据库模块。
