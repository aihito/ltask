# ltask 服务启动流程详解

本文档详细分析 ltask 服务的启动流程，以 `test.lua` 为例，从入口到服务运行的全过程。

## 目录

1. [整体架构](#整体架构)
2. [启动流程概览](#启动流程概览)
3. [详细流程分析](#详细流程分析)
4. [关键组件说明](#关键组件说明)
5. [消息流转机制](#消息流转机制)

---

## 整体架构

ltask 采用 **n:m 调度器**架构：
- **n 个 OS 线程**（worker threads）
- **m 个 Lua VM**（services）
- 每个 service 运行在独立的 Lua VM 中
- 通过消息通道进行服务间通信

---

## 启动流程概览

```
test.lua
  ↓
test/start.lua
  ↓
lualib/bootstrap.lua
  ↓
C 层初始化 (boot.init)
  ↓
创建 Root Service (boot.new_service)
  ↓
启动 Worker 线程 (boot.run)
  ↓
Root Service 处理 init 消息
  ↓
启动 Bootstrap Services (timer, logger, sockevent, bootstrap)
  ↓
服务运行循环
```

---

## 详细流程分析

### 阶段 1: 入口点 (test.lua)

**文件**: `test.lua`

```lua
local start = require "test.start"
start {
    core = {
        debuglog = "=",
        worker = 3,
    },
    service_path = "service/?.lua;test/?.lua",
    bootstrap = {
        { name = "timer", unique = true },
        { name = "logger", unique = true },
        { name = "sockevent", unique = true },
        { name = "bootstrap" },
    },
}
```

**作用**:
- 调用 `test.start` 模块
- 传入配置参数：
  - `core`: 核心配置（调试日志、工作线程数）
  - `service_path`: 服务文件搜索路径
  - `bootstrap`: 需要启动的引导服务列表

---

### 阶段 2: 启动脚本 (test/start.lua)

**文件**: `test/start.lua`

#### 2.1 准备 Root Service 配置

```lua
local servicepath = searchpath "service"
local root_config = {
    bootstrap = config.bootstrap,
    service_source = readall(servicepath),  -- 读取 service/root.lua 源码
    service_chunkname = "@" .. servicepath,
    initfunc = ...  -- 生成服务加载函数
}
```

**关键点**:
- 读取 `service/root.lua` 的源代码
- 生成 `initfunc`，用于后续加载服务文件
- `initfunc` 是一个字符串模板，会被编译成 Lua 函数

#### 2.2 调用 Bootstrap 模块

```lua
local bootstrap = dofile(searchpath "bootstrap")  -- 加载 lualib/bootstrap.lua
local ctx = bootstrap.start {
    core = config.core or {},
    root = root_config,
    root_initfunc = root_config.initfunc,
    mainthread = config.mainthread,
}
bootstrap.wait(ctx)  -- 等待所有线程结束
```

**作用**:
- 加载 `lualib/bootstrap.lua` 模块
- 调用 `bootstrap.start()` 启动系统
- 调用 `bootstrap.wait()` 等待系统运行

---

### 阶段 3: Bootstrap 启动 (lualib/bootstrap.lua)

**文件**: `lualib/bootstrap.lua`

#### 3.1 初始化 C 层 (boot.init)

```lua
local function start(config)
    boot.init(config.core)  -- 初始化 C 层
    boot.init_timer()       -- 初始化定时器
    bootstrap_root(...)      -- 创建 Root Service
    return boot.run(...)     -- 启动工作线程
end
```

**boot.init() 的作用** (C 层 `ltask_init`):

1. **加载配置**
   - 从 Lua 表读取配置（worker 数量、队列大小等）
   - 存储到 `LTASK_CONFIG` 注册表

2. **创建全局任务结构** (`LTASK_GLOBAL`)
   ```c
   struct ltask *task = lua_newuserdatauv(...);
   // 包含：
   // - workers: 工作线程数组
   // - services: 服务池
   // - schedule: 调度队列
   // - timer: 定时器
   // - event: sockevent 数组
   ```

3. **初始化工作线程**
   - 为每个 worker 线程创建 `worker_thread` 结构
   - 初始化调度队列、消息队列等

4. **初始化 sockevent**
   - 为每个可能的 sockevent 初始化事件结构

#### 3.2 创建 Root Service (bootstrap_root)

```lua
local function bootstrap_root(initfunc, config)
    -- 1. 创建 Root Service (ID = 1)
    local sid = assert(boot.new_service("root", 
        config.service_source, 
        config.service_chunkname, 
        SERVICE_ROOT))
    assert(sid == SERVICE_ROOT)  -- 确保 ID 为 1
    
    -- 2. 初始化 Root Service
    boot.init_root(SERVICE_ROOT)
    
    -- 3. 打包 init 消息
    local init_msg, sz = boot.pack("init", {
        initfunc = initfunc,
        name = "root",
        args = {config}
    })
    
    -- 4. 发送 init 消息给自己
    boot.post_message {
        from = SERVICE_ROOT,
        to = SERVICE_ROOT,
        session = 1,  -- session 1 用于 root init
        type = MESSAGE_SYSTEM,
        message = init_msg,
        size = sz,
    }
end
```

**boot.new_service() 的作用** (C 层 `ltask_newservice`):

1. **创建新的服务 ID**
   ```c
   service_id id = service_new(task->services, sid);
   ```

2. **初始化服务 VM**
   - 创建新的 Lua State
   - 加载 `ltask` 模块
   - 设置服务上下文 (`service_ud`)

3. **加载服务源码**
   - 将服务源码编译成 Lua 函数
   - 但**不立即执行**

**boot.init_root() 的作用** (C 层 `ltask_init_root`):

- 在 Root Service 的 VM 中加载 `ltask.root` 模块
- `ltask.root` 提供 `init_service`、`close_service` 等 API

#### 3.3 启动工作线程 (boot.run)

```lua
return boot.run(config.mainthread)
```

**boot.run() 的作用** (C 层 `ltask_run`):

1. **创建线程上下文**
   ```c
   struct task_context *ctx = ...;
   ctx->task = task;
   ctx->threads_count = worker_n + logthread;
   ```

2. **启动工作线程**
   ```c
   for (i=0; i<worker_n; i++) {
       t[i].func = thread_worker;  // 工作线程入口
       t[i].ud = &task->workers[i];
   }
   ctx->handle = thread_start(ctx->t, ctx->threads_count, usemainthread);
   ```

3. **工作线程执行流程** (`thread_worker`):
   ```
   while (running) {
       1. 从调度队列获取服务
       2. 执行服务的消息处理
       3. 如果服务挂起，放回调度队列
       4. 处理消息发送
   }
   ```

---

### 阶段 4: Root Service 初始化 (service/root.lua)

**文件**: `service/root.lua`

#### 4.1 处理 init 消息

Root Service 启动后，会收到 session=1 的 init 消息：

```lua
-- 注册 init 消息处理
ltask.suspend(1, init_receipt)

-- init_receipt 处理函数
local function init_receipt(type, session, msg, sz)
    local errobj = ltask.unpack_remove(msg, sz)
    if type == MESSAGE_ERROR then
        -- 初始化失败，退出
        root_quit()
    end
end
```

#### 4.2 执行 init 消息

Root Service 的 `dispatch` 机制会处理 `init` 消息：

```lua
ltask.dispatch(S)  -- 注册服务接口

-- dispatch 会处理 MESSAGE_REQUEST 类型的消息
-- 调用对应的服务函数
```

**init 消息处理流程**:

1. **消息到达**: Root Service 收到 `session=1, type=MESSAGE_SYSTEM` 的消息
2. **消息路由**: `schedule_message()` 识别为系统消息
3. **调用处理**: 调用 `S.init()` 函数（如果存在）
4. **执行初始化**: 
   ```lua
   -- 在 init 函数中（如果定义了）
   -- 或者通过 dispatch 机制调用
   ```

#### 4.3 启动 Bootstrap Services

```lua
local function bootstrap()
    for _, t in ipairs(config.bootstrap) do
        S.spawn_service(t)  -- 启动每个引导服务
    end
end

bootstrap()  -- 执行启动
```

**spawn_service() 流程**:

```lua
function S.spawn_service(t)
    if t.unique then
        return spawn_unique(t)  -- 唯一服务
    else
        return spawn(t)          -- 普通服务
    end
end
```

**spawn() 详细流程**:

```lua
local function spawn(t)
    -- 1. 向系统服务发送 MESSAGE_SCHEDULE_NEW
    local type, address = ltask.post_message(
        SERVICE_SYSTEM, 0, MESSAGE_SCHEDULE_NEW)
    
    -- 2. 系统分配新的服务 ID
    -- 3. 初始化服务
    assert(root.init_service(address, t.name, ...))
    
    -- 4. 发送 init 消息给新服务
    ltask.syscall(address, "init", {
        initfunc = t.initfunc or config.initfunc,
        name = t.name,
        args = t.args or {},
    })
    
    return address
end
```

**启动的服务** (按 test.lua 配置):

1. **timer** (unique)
   - 文件: `service/timer.lua`
   - 作用: 定时器服务，处理延时消息

2. **logger** (unique)
   - 文件: `service/logger.lua` (如果存在)
   - 作用: 日志服务

3. **sockevent** (unique)
   - 文件: `test/sockevent.lua`
   - 作用: 网络事件服务

4. **bootstrap**
   - 文件: `test/bootstrap.lua`
   - 作用: 测试引导服务

---

### 阶段 5: 服务运行循环

#### 5.1 Worker 线程循环

每个 worker 线程执行以下循环：

```c
void thread_worker(void *ud) {
    struct worker_thread *w = (struct worker_thread *)ud;
    while (running) {
        // 1. 从调度队列获取服务
        service_id id = schedule_pop(w->task);
        
        // 2. 执行服务消息处理
        worker_run_service(w, id);
        
        // 3. 处理消息发送
        worker_send_message(w);
        
        // 4. 处理绑定服务
        worker_binding_job(w);
    }
}
```

#### 5.2 服务消息处理

```lua
-- 在 service.lua 中
local function schedule_message()
    local from, session, type, msg, sz = ltask.recv_message()
    
    if type == MESSAGE_REQUEST then
        -- 处理请求消息
        request(command, ...)
    elseif type == MESSAGE_RESPONSE then
        -- 处理响应消息
        wakeup_session(co, type, session, msg, sz)
    end
    
    -- 处理 wakeup_queue
    while #wakeup_queue > 0 do
        local s = table.remove(wakeup_queue, 1)
        wakeup_session(table.unpack(s))
    end
end
```

---

## 关键组件说明

### 1. Service Pool (服务池)

- **作用**: 管理所有服务的生命周期
- **结构**: `struct service_pool`
- **功能**:
  - 服务创建/删除
  - 服务状态管理
  - 消息队列管理

### 2. Worker Thread (工作线程)

- **作用**: 执行服务的消息处理
- **数量**: 由 `core.worker` 配置决定
- **职责**:
  - 从调度队列获取服务
  - 执行服务消息处理
  - 处理消息发送

### 3. Schedule Queue (调度队列)

- **作用**: 管理待执行的服务
- **类型**: 整数队列（存储服务 ID）
- **操作**:
  - `schedule_push`: 将服务加入调度队列
  - `schedule_pop`: 从调度队列获取服务

### 4. Message Queue (消息队列)

- **作用**: 存储服务的消息
- **类型**: 每个服务有独立的消息队列
- **消息类型**:
  - `MESSAGE_REQUEST`: 请求消息
  - `MESSAGE_RESPONSE`: 响应消息
  - `MESSAGE_ERROR`: 错误消息
  - `MESSAGE_SYSTEM`: 系统消息
  - `MESSAGE_SIGNAL`: 信号消息

### 5. Sockevent (网络事件)

- **作用**: 处理网络 IO 事件
- **机制**: 通过 pipe 实现事件通知
- **使用**: 服务调用 `ltask.eventinit()` 获取事件句柄

---

## 消息流转机制

### 消息发送流程

```
Service A 调用 ltask.call(Service B, "func", args)
  ↓
生成 MESSAGE_REQUEST 消息
  ↓
消息加入 Service B 的消息队列
  ↓
Service B 被加入调度队列
  ↓
Worker 线程执行 Service B
  ↓
Service B 处理消息，调用对应函数
  ↓
返回结果，生成 MESSAGE_RESPONSE
  ↓
消息加入 Service A 的消息队列
  ↓
Service A 被唤醒，获取响应
```

### 消息类型说明

| 类型 | 值 | 说明 |
|------|-----|------|
| MESSAGE_SYSTEM | 0 | 系统消息（如 init） |
| MESSAGE_REQUEST | 1 | 请求消息 |
| MESSAGE_RESPONSE | 2 | 响应消息 |
| MESSAGE_ERROR | 3 | 错误消息 |
| MESSAGE_SIGNAL | 4 | 信号消息 |
| MESSAGE_IDLE | 5 | 空闲消息 |

---

## 总结

ltask 的启动流程可以概括为：

1. **配置加载**: 从 Lua 配置加载系统参数
2. **C 层初始化**: 创建 worker 线程、服务池、调度队列等
3. **Root Service 创建**: 创建第一个服务（ID=1）
4. **工作线程启动**: 启动多个 worker 线程执行服务
5. **Bootstrap 服务启动**: Root Service 启动引导服务
6. **消息循环**: 服务通过消息进行通信和协作

整个系统采用**事件驱动**和**消息传递**的架构，实现了高效的并发服务调度。

---

## 参考文件

- `test.lua`: 入口文件
- `test/start.lua`: 启动脚本
- `lualib/bootstrap.lua`: Bootstrap 模块
- `service/root.lua`: Root Service 实现
- `lualib/service.lua`: Service 基础库
- `src/ltask.c`: C 层实现
