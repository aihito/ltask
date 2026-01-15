# luaopen_ltask_root 函数详解

本文档详细解释 `luaopen_ltask_root` 函数的作用和实现机制。

## 函数概述

`luaopen_ltask_root` 是 Lua 模块的入口函数，用于加载 `ltask.root` 模块。这个模块**只能被 Root Service 使用**，提供了服务管理的核心 API。

## 函数签名

```c
LUAMOD_API int
luaopen_ltask_root(lua_State *L)
```

## 代码解析

### 1. 单例检查

```c
static atomic_int init = 0;
if (atomic_int_inc(&init) != 1) {
    return luaL_error(L, "ltask.root can only require once");
}
```

**作用**:
- 使用静态原子变量确保模块只被加载一次
- 如果尝试多次加载，会报错
- **为什么需要单例**: `ltask.root` 是系统级模块，只能有一个实例

**执行流程**:
- 第一次调用: `atomic_int_inc(&init)` 返回 0，然后变为 1，条件不满足，继续执行
- 第二次调用: `atomic_int_inc(&init)` 返回 1，然后变为 2，条件满足，报错退出

### 2. 版本检查

```c
luaL_checkversion(L);
```

**作用**:
- 检查 Lua 版本兼容性
- 确保使用的 Lua 版本符合要求

### 3. 定义函数表

```c
luaL_Reg l[] = {
    { "init_service", ltask_initservice },
    { "close_service", ltask_closeservice },
    { NULL, NULL },
};
```

**作用**:
- 定义模块导出的函数
- `init_service`: 初始化新服务
- `close_service`: 关闭服务

**函数说明**:

#### `ltask_initservice`
```c
static int
ltask_initservice(lua_State *L) {
    const struct service_ud *S = getS(L);
    unsigned int sid = luaL_checkinteger(L, 1);      // 服务 ID
    const char *label = luaL_checkstring(L, 2);       // 服务标签
    const char *source = luaL_checklstring(L, 3, &source_sz);  // 服务源码
    const char *chunkname = luaL_checkstring(L, 4);  // 代码块名称
    int worker_id = luaL_optinteger(L, 5, -1);       // 工作线程 ID（可选）
    
    service_id id = { sid };
    if (newservice(L, S->task, id, label, source, source_sz, chunkname, worker_id)) {
        // 创建失败
        lua_pushboolean(L, 0);
        lua_insert(L, -2);
        return 2;  // 返回 (false, error_message)
    } else {
        // 创建成功
        lua_pushboolean(L, 1);
        return 1;  // 返回 true
    }
}
```

**作用**: 创建新的服务

#### `ltask_closeservice`
```c
static int
ltask_closeservice(lua_State *L) {
    const struct service_ud *S = getS(L);
    unsigned int sid = luaL_checkinteger(L, 1);
    service_id id = { sid };
    
    // 检查服务状态
    if (service_status_get(S->task->services, id) != SERVICE_STATUS_DEAD) {
        return luaL_error(L, "Hang %d before close it", sid);
    }
    
    // 关闭 sockevent
    int sockevent_id = service_sockevent_get(S->task->services, id);
    if (sockevent_id >= 0) {
        sockevent_close(&S->task->event[sockevent_id]);
        atomic_int_store(&S->task->event_init[sockevent_id], 0);
    }
    
    // 清理消息队列
    int ret = close_service_messages(L, S->task->services, id);
    
    // 删除服务
    service_delete(S->task->services, id);
    return ret;
}
```

**作用**: 关闭并清理服务

### 4. 创建模块表

```c
luaL_newlibtable(L, l);
```

**作用**:
- 创建一个空的 Lua 表，用于存储模块函数
- 此时表是空的，函数还没有注册

### 5. 获取服务上下文

```c
if (lua_getfield(L, LUA_REGISTRYINDEX, LTASK_KEY) != LUA_TSTRING) {
    luaL_error(L, "No service id, the VM is not inited by ltask");
}
const struct service_ud * ud = (const struct service_ud *)luaL_checkstring(L, -1);
lua_pop(L, 1);
```

**关键点**:

1. **LTASK_KEY**: 定义在 `service.h` 中，值为 `"LTASK_ID"`
   - 这是 Lua 注册表中的键，用于存储服务上下文

2. **service_ud 结构**:
   ```c
   struct service_ud {
       struct ltask *task;  // 指向全局任务结构
       service_id id;       // 服务 ID
   };
   ```

3. **存储方式**: 
   - `service_ud` 被序列化为字符串存储在注册表中
   - 通过 `luaL_checkstring` 获取，然后强制转换为指针

4. **何时设置**: 
   - 在 `service_init()` 中通过 `init_service_key()` 设置
   - 每个服务的 VM 初始化时都会设置

**为什么需要这个检查**:
- 确保这个 Lua State 是由 ltask 初始化的
- 防止在非 ltask 环境中使用这个模块
- 获取服务上下文，用于后续的函数调用

### 6. 注册函数

```c
lua_pushlightuserdata(L, (void *)ud);
luaL_setfuncs(L, l, 1);
```

**作用**:
- 将 `service_ud` 作为 upvalue 传递给所有函数
- 注册函数到模块表中
- 每个函数都可以通过 `getS(L)` 获取服务上下文

**upvalue 机制**:
- Lua 函数可以有 upvalue（闭包变量）
- 这里将 `service_ud` 作为第一个 upvalue
- 函数可以通过 `lua_upvalueindex(1)` 访问

**getS 宏**:
```c
static inline const struct service_ud *
getS(lua_State *L) {
    const struct service_ud * ud = (const struct service_ud *)lua_touserdata(L, lua_upvalueindex(1));
    assert(ud);
    return ud;
}
```

### 7. 返回模块

```c
return 1;
```

**作用**:
- 返回模块表（栈顶）
- Lua 的 `require "ltask.root"` 会得到这个表

---

## 调用时机

### 何时被调用

```c
// 在 ltask_init_root 中
if (service_requiref(task->services, id, "ltask.root", luaopen_ltask_root, L)) {
    return luaL_error(L, "require ltask.root fail : %s", get_error_message(L));
}
```

**调用流程**:
1. `boot.init_root(SERVICE_ROOT)` 被调用
2. `ltask_init_root()` 执行
3. `service_requiref()` 在 Root Service 的 VM 中调用 `luaopen_ltask_root`
4. 模块被加载，函数被注册

### 为什么只在 Root Service 中加载

- **权限控制**: 只有 Root Service 可以创建和关闭服务
- **安全性**: 防止普通服务随意创建/删除服务
- **设计**: Root Service 是服务管理器，需要这些特殊权限

---

## 使用示例

### 在 Root Service 中使用

```lua
-- service/root.lua
local root = require "ltask.root"

-- 创建新服务
local ok = root.init_service(
    sid,           -- 服务 ID
    "label",       -- 服务标签
    source_code,   -- 服务源码
    "@chunkname",  -- 代码块名称
    worker_id      -- 工作线程 ID（可选）
)

if not ok then
    -- 创建失败
    error("Failed to create service")
end

-- 关闭服务
local ret = root.close_service(sid)
```

---

## 关键数据结构

### service_ud

```c
struct service_ud {
    struct ltask *task;  // 全局任务结构指针
    service_id id;       // 服务 ID
};
```

**作用**:
- 连接 Lua 层和 C 层
- 提供访问全局任务结构和服务 ID 的方式
- 通过 upvalue 传递给所有模块函数

### service_id

```c
typedef struct {
    unsigned int id;
} service_id;
```

**作用**:
- 服务的唯一标识符
- Root Service 的 ID 固定为 1

---

## 错误处理

### 可能的错误

1. **重复加载**: "ltask.root can only require once"
2. **非 ltask 环境**: "No service id, the VM is not inited by ltask"
3. **服务创建失败**: `init_service` 返回 `(false, error_message)`
4. **服务未挂起**: "Hang %d before close it"

---

## 总结

`luaopen_ltask_root` 函数的作用：

1. **单例保证**: 确保模块只加载一次
2. **权限验证**: 检查是否在 ltask 环境中
3. **上下文获取**: 从注册表获取服务上下文
4. **函数注册**: 注册 `init_service` 和 `close_service`
5. **upvalue 传递**: 将服务上下文传递给所有函数

这个模块是 ltask 服务管理的核心，只有 Root Service 可以使用，提供了创建和关闭服务的能力。
