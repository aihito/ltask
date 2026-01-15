# ltask 整体架构文档

本文档全面梳理 ltask 的整体架构，帮助理解系统的设计思路和实现机制。

## 目录

1. [架构概览](#架构概览)
2. [核心设计理念](#核心设计理念)
3. [系统层次结构](#系统层次结构)
4. [核心组件](#核心组件)
5. [关键机制](#关键机制)
6. [数据流](#数据流)
7. [模块关系](#模块关系)
8. [目录结构](#目录结构)

---

## 架构概览

### n:m 调度器架构

ltask 实现了 **n:m 调度器**（协程调度器）：

- **n 个 OS 线程**（Worker Threads）：实际执行单元
- **m 个 Lua VM**（Services）：逻辑服务单元
- **动态调度**：多个服务可以在多个线程间动态调度

```
┌─────────────────────────────────────────┐
│                ltask                    │
├─────────────────────────────────────────┤
│                                         │
│  ┌────────┐  ┌────────┐  ┌────────┐     │
│  │Worker 0│  │Worker 1│  │Worker 2│     │
│  │Thread  │  │Thread  │  │Thread  │     │
│  └───┬────┘  └───┬────┘  └───┬────┘     │
│      │           │           │          │
│      └───────────┼───────────┘          │
│                  │                      │
│         ┌────────▼────────┐             │
│         │  Schedule Queue │             │
│         └────────┬────────┘             │
│                  │                      │
│  ┌───────────────┼───────────────┐      │
│  │                               │      │
│  │  Service Pool (muti Lua VM)   │      │
│  │                               │      │
│  │  Service 1  Service 2  ...    │      │
│  │  (Lua VM)   (Lua VM)          │      │
│  │                               │      │
│  └───────────────────────────────┘      │
│                                         │
└─────────────────────────────────────────┘
```

### 核心特点

1. **协程调度**：每个服务运行在独立的 Lua VM 中，通过协程实现并发
2. **消息传递**：服务间通过消息通道通信
3. **工作窃取**：空闲线程可以从忙碌线程窃取任务
4. **绑定服务**：服务可以绑定到特定线程执行

---

## 核心设计理念

### 1. 服务隔离

- 每个服务运行在**独立的 Lua VM** 中
- 服务间**不能直接共享内存**
- 只能通过**消息传递**通信

**优势**：
- 故障隔离：一个服务崩溃不影响其他服务
- 内存隔离：服务间内存独立，便于管理
- 并发安全：避免共享状态导致的竞态条件

### 2. 异步消息传递

- 所有服务间通信都是**异步的**
- 消息发送后立即返回，不阻塞
- 通过消息队列实现缓冲

**优势**：
- 高并发：服务可以同时处理多个请求
- 解耦：服务间松耦合，易于扩展
- 容错：消息队列可以缓冲，提高系统稳定性

### 3. 动态调度

- 服务可以在多个线程间**动态调度**
- 支持**工作窃取**：空闲线程可以窃取忙碌线程的任务
- 支持**绑定**：关键服务可以绑定到特定线程

**优势**：
- 负载均衡：自动分配任务，提高 CPU 利用率
- 灵活性：可以根据需求调整调度策略
- 性能优化：关键服务可以绑定到专用线程

---

## 系统层次结构

### 层次划分

```
┌─────────────────────────────────────┐
│     应用层 (Lua)                     │
│  - service/root.lua                 │
│  - service/timer.lua                │
│  - user services                    │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│    service framework layer (Lua)    │
│  - lualib/service.lua               │
│  - lualib/bootstrap.lua             │
│  - 消息处理、协程管理                  │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│    核心调度层 (C)                     │
│  - src/ltask.c                      │
│  - src/service.c                    │
│  - src/worker.h                     │
│  - 调度、消息传递、线程管理             │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│    基础设施层 (C)                     │
│  - src/queue.c                      │
│  - src/message.c                    │
│  - src/timer.c                      │
│  - src/sockevent.h                  │
│  - 队列、消息、定时器、网络事件          │
└─────────────────────────────────────┘
```

### 各层职责

#### 应用层
- **职责**：业务逻辑实现
- **特点**：纯 Lua 代码，易于编写和维护
- **示例**：`service/root.lua`、`service/timer.lua`

#### 服务框架层
- **职责**：服务生命周期管理、消息路由、协程调度
- **特点**：提供统一的服务开发框架
- **文件**：`lualib/service.lua`、`lualib/bootstrap.lua`

#### 核心调度层
- **职责**：服务调度、消息传递、线程管理
- **特点**：C 实现，高性能
- **文件**：`src/ltask.c`、`src/service.c`、`src/worker.h`

#### 基础设施层
- **职责**：底层数据结构、系统调用封装
- **特点**：可复用组件
- **文件**：`src/queue.c`、`src/message.c`、`src/timer.c`

---

## 核心组件

### 1. ltask (全局任务结构)

**定义**：`src/ltask.c`

```c
struct ltask {
    const struct ltask_config *config;       // 配置
    struct worker_thread *workers;           // 工作线程数组
    struct service_pool *services;           // 服务池
    struct queue *schedule;                  // 调度队列
    struct timer *timer;                     // 定时器
    struct logqueue *lqueue;                 // 日志队列
    struct queue *external_message;          // 外部消息队列
    struct sockevent event[MAX_SOCKEVENT];   // 网络事件数组
    struct mainthread_session mt;            // 主线程会话
    atomic_int schedule_owner;               // 调度器所有者
    // ...
};
```

**职责**：
- 管理所有工作线程
- 管理服务池
- 管理调度队列
- 协调各组件

**生命周期**：
- 创建：`boot.init()` 时创建
- 运行：`boot.run()` 时启动线程
- 销毁：`boot.deinit()` 时清理

### 2. service_pool (服务池)

**定义**：`src/service.c`

**职责**：
- 管理所有服务的生命周期
- 管理服务的消息队列
- 管理服务的状态
- 管理服务的 Lua VM

**关键操作**：
- `service_new()`: 创建新服务
- `service_init()`: 初始化服务 VM
- `service_push_message()`: 推送消息到服务
- `service_pop_message()`: 从服务弹出消息
- `service_resume()`: 恢复服务执行

**服务状态**：
```c
SERVICE_STATUS_UNINITIALIZED  // 未初始化
SERVICE_STATUS_IDLE           // 空闲
SERVICE_STATUS_SCHEDULE       // 已加入调度队列
SERVICE_STATUS_RUNNING        // 正在运行
SERVICE_STATUS_DONE           // 执行完成
SERVICE_STATUS_DEAD           // 已死亡
SERVICE_STATUS_MAINTHREAD     // 主线程模式
```

### 3. worker_thread (工作线程)

**定义**：`src/worker.h`

```c
struct worker_thread {
    struct ltask *task;                     // 指向全局任务
    int worker_id;                          // 线程 ID
    service_id running;                     // 当前运行的服务
    service_id binding;                     // 绑定的服务
    service_id waiting;                     // 等待的服务
    atomic_int service_ready;               // 准备执行的服务 ID
    atomic_int service_done;                // 完成的服务 ID
    struct binding_service binding_queue;   // 绑定服务队列
    struct cond trigger;                    // 条件变量（用于唤醒）
    int busy;                               // 是否忙碌
    // ...
};
```

**职责**：
- 从调度队列获取服务
- 执行服务的消息处理
- 处理消息发送
- 支持工作窃取

**执行循环**：
```c
while (running) {
    1. 获取服务 (worker_get_job)
    2. 执行服务 (service_resume)
    3. 处理消息发送
    4. 处理绑定服务
    5. 标记服务完成 (worker_complete_job)
}
```

### 4. message (消息)

**定义**：`src/message.h`

```c
struct message {
    service_id from;      // 发送者
    service_id to;        // 接收者
    session_t session;    // 会话 ID
    int type;             // 消息类型
    void *msg;            // 消息数据
    size_t sz;            // 消息大小
};
```

**消息类型**：
```c
MESSAGE_SYSTEM    // 系统消息（如 init）
MESSAGE_REQUEST   // 请求消息
MESSAGE_RESPONSE  // 响应消息
MESSAGE_ERROR     // 错误消息
MESSAGE_SIGNAL    // 信号消息（如服务退出）
MESSAGE_IDLE      // 空闲消息
```

**消息流转**：
```
发送者 → 消息队列 → 接收者消息队列 → 接收者处理
```

---

## 关键机制

### 1. 服务调度机制

#### 调度流程

```
1. 服务收到消息
   ↓
2. 服务状态变为 IDLE
   ↓
3. 加入调度队列 (schedule_back)
   ↓
4. 调度器分配服务到工作线程
   ↓
5. 工作线程执行服务
   ↓
6. 服务处理消息
   ↓
7. 服务状态变为 DONE
   ↓
8. 如果还有消息，回到步骤 1
```

#### 调度策略

1. **绑定服务优先**：
   - 如果服务绑定到特定线程，优先分配给该线程
   - 如果绑定线程忙碌，加入绑定队列等待

2. **工作窃取**：
   - 空闲线程可以从忙碌线程窃取任务
   - 但不能窃取绑定服务的任务

3. **负载均衡**：
   - 优先分配给空闲线程
   - 如果所有线程都忙碌，分配给最不忙碌的线程

### 2. 消息传递机制

#### 消息发送流程

```
Service A 调用 ltask.call(Service B, "func", args)
  ↓
生成 MESSAGE_REQUEST 消息
  ↓
调用 service_push_message(Service B, msg)
  ↓
消息加入 Service B 的消息队列
  ↓
如果 Service B 是 IDLE 状态
  ↓
Service B 加入调度队列
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

#### 消息队列

- 每个服务有**独立的消息队列**
- 队列是**线程安全的**
- 支持**阻塞**和**非阻塞**推送

**队列状态**：
- **空队列**：服务进入 IDLE 状态
- **有消息**：服务进入 SCHEDULE 状态
- **队列满**：推送返回 BLOCK，消息暂存

### 3. 协程管理机制

#### 协程生命周期

```
1. 服务初始化时创建主协程
   ↓
2. 收到消息时创建新协程处理
   ↓
3. 协程执行服务函数
   ↓
4. 如果调用 ltask.call()，协程挂起
   ↓
5. 收到响应后，协程恢复
   ↓
6. 处理完成后，协程结束
```

#### 协程状态管理

- **运行中**：协程正在执行
- **挂起**：等待消息响应
- **完成**：处理完成

**关键数据结构**：
```lua
session_coroutine_suspend_lookup[session] = coroutine
session_coroutine_response[coroutine] = session
session_coroutine_address[coroutine] = from
```

### 4. 工作窃取机制

#### 工作原理

```
Worker A (空闲)          Worker B (忙碌)
    │                        │
    │  1. 检查调度队列         │
    │     (空)               │
    │                        │
    │  2. 尝试窃取            │
    │     ──────────────────>│
    │                        │
    │  3. 检查 Worker B       │
    │     service_ready      │
    │                        │
    │  4. CAS 获取任务        │
    │     <──────────────────│
    │                        │
    │  5. 执行任务             │
```

#### 窃取规则

1. **只能窃取非绑定服务**
2. **使用 CAS 原子操作**
3. **避免重复窃取**

### 5. 绑定服务机制

#### 绑定目的

- **性能优化**：关键服务绑定到专用线程
- **缓存友好**：服务数据保持在同一线程
- **实时性**：减少线程切换开销

#### 绑定流程

```
1. 创建服务时指定 worker_id
   ↓
2. service_binding_set(service, worker_id)
   ↓
3. 服务加入绑定队列
   ↓
4. 绑定线程优先处理
   ↓
5. 如果绑定线程忙碌，等待
```

---

## 数据流

### 服务启动流程

```
test.lua
  ↓
test/start.lua
  ↓
lualib/bootstrap.lua
  ├─ boot.init()          # C 层初始化
  ├─ boot.init_timer()    # 初始化定时器
  ├─ bootstrap_root()     # 创建 Root Service
  └─ boot.run()           # 启动工作线程
      ↓
Root Service 初始化
  ├─ 接收 init 消息
  ├─ 执行 initfunc
  ├─ 加载 service/root.lua
  └─ 启动 Bootstrap Services
```

### 消息处理流程

```
Service A 发送消息
  ↓
service_push_message(Service B, msg)
  ↓
Service B 消息队列
  ↓
Service B 状态: IDLE → SCHEDULE
  ↓
加入调度队列
  ↓
Worker 线程获取服务
  ↓
service_resume(Service B)
  ↓
Service B 处理消息
  ↓
生成响应消息
  ↓
service_push_message(Service A, response)
  ↓
Service A 被唤醒
```

### 服务创建流程

```
Root Service 调用 root.init_service()
  ↓
ltask_initservice()
  ↓
newservice()
  ├─ service_new()        # 分配服务 ID
  ├─ service_init()       # 初始化 VM
  ├─ service_requiref()   # 加载 ltask 模块
  └─ service_loadstring() # 加载服务源码
      ↓
发送 init 消息给新服务
  ↓
新服务处理 init 消息
  ├─ 加载服务文件
  ├─ 执行服务代码
  └─ 注册服务接口
```

---

## 模块关系

### C 层模块

```
ltask.c
  ├─ 依赖 service.c (服务管理)
  ├─ 依赖 worker.h (工作线程)
  ├─ 依赖 queue.c (队列)
  ├─ 依赖 message.c (消息)
  ├─ 依赖 timer.c (定时器)
  └─ 依赖 sockevent.h (网络事件)

service.c
  ├─ 管理服务池
  ├─ 管理服务 VM
  └─ 管理消息队列

worker.h
  ├─ 工作线程结构
  └─ 工作窃取逻辑
```

### Lua 层模块

```
lualib/bootstrap.lua
  ├─ 调用 boot.init() (C)
  ├─ 调用 boot.new_service() (C)
  └─ 调用 boot.run() (C)

lualib/service.lua
  ├─ 消息处理
  ├─ 协程管理
  └─ 服务接口

service/root.lua
  ├─ 服务管理
  ├─ 服务创建/删除
  └─ 依赖 ltask.root (C)
```

### 模块依赖图

```
┌─────────────────┐
│  test.lua       │
└────────┬────────┘
         │
┌────────▼────────┐
│ test/start.lua  │
└────────┬────────┘
         │
┌────────▼──────────────┐
│ lualib/bootstrap.lua  │
└────────┬──────────────┘
         │
    ┌────┴────┐
    │         │
┌───▼───┐ ┌───▼────────┐
│ C API │ │service/    │
│       │ │root.lua    │
└───┬───┘ └───┬────────┘
    │         │
┌───▼─────────▼──┐
│ lualib/       │
│ service.lua   │
└───────────────┘
```

---

## 目录结构

### 源码目录

```
ltask/
├── src/              # C 源码
│   ├── ltask.c      # 核心调度
│   ├── service.c    # 服务管理
│   ├── worker.h     # 工作线程
│   ├── message.c    # 消息处理
│   ├── queue.c      # 队列实现
│   ├── timer.c      # 定时器
│   └── ...
├── lualib/          # Lua 库
│   ├── bootstrap.lua    # 启动模块
│   └── service.lua      # 服务框架
├── service/         # 系统服务
│   ├── root.lua     # Root Service
│   ├── timer.lua    # 定时器服务
│   └── logger.lua   # 日志服务
├── test/            # 测试代码
│   ├── start.lua    # 启动脚本
│   └── ...
└── docs/            # 文档
    └── ...
```

### 文件职责

| 文件 | 职责 |
|------|------|
| `src/ltask.c` | 核心调度、线程管理、消息分发 |
| `src/service.c` | 服务池管理、VM 管理、消息队列 |
| `src/worker.h` | 工作线程结构、工作窃取 |
| `src/message.c` | 消息创建、删除 |
| `src/queue.c` | 队列实现 |
| `src/timer.c` | 定时器实现 |
| `lualib/bootstrap.lua` | 系统启动、Root Service 创建 |
| `lualib/service.lua` | 服务框架、消息处理、协程管理 |
| `service/root.lua` | 服务管理、服务创建/删除 |

---

## 总结

ltask 的整体架构可以概括为：

1. **n:m 调度器**：多个 OS 线程调度多个 Lua VM
2. **服务隔离**：每个服务独立的 Lua VM，通过消息通信
3. **异步消息**：所有通信都是异步的，通过消息队列缓冲
4. **动态调度**：支持工作窃取和绑定服务
5. **分层设计**：应用层、框架层、调度层、基础设施层

这种架构设计实现了：
- **高并发**：多个服务可以并发执行
- **高可用**：服务隔离，故障不影响其他服务
- **高性能**：C 层实现核心调度，Lua 层实现业务逻辑
- **易扩展**：服务可以动态创建和删除

---

## 参考文档

- [服务启动流程](./service-startup-flow.md)
- [root_initfunc 调用流程](./root-initfunc-flow.md)
- [ltask.root 模块说明](./ltask-root-module.md)
