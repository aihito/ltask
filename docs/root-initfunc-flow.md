# root_initfunc 调用流程详解

本文档详细解释 `root_initfunc` 是如何被调用的，这是理解 ltask 服务启动的关键。

## 目录

1. [root_initfunc 是什么](#root_initfunc-是什么)
2. [完整调用流程](#完整调用流程)
3. [代码执行细节](#代码执行细节)
4. [关键函数解析](#关键函数解析)
5. [流程图](#流程图)

---

## root_initfunc 是什么

`root_initfunc` 是一个 **Lua 代码字符串**，用于加载和初始化服务文件。

### 在 test/start.lua 中的定义

```lua
root_config = {
    initfunc = ([=[
local name = ...
package.path = [[${lua_path}]]
package.cpath = [[${lua_cpath}]]
local filename, err = package.searchpath(name, "${service_path}")
if not filename then
    return nil, err
end
return loadfile(filename)
]=]):gsub("%$%{([^}]*)%}", {
    lua_path = package.path,
    lua_cpath = package.cpath,
    service_path = config.service_path,
}),
}
```

**实际生成的字符串示例**:
```lua
local name = ...
package.path = [[/path/to/lua/?.lua;...]]
package.cpath = [[/path/to/?.so;...]]
local filename, err = package.searchpath(name, "service/?.lua;test/?.lua")
if not filename then
    return nil, err
end
return loadfile(filename)
```

这个字符串会被：
1. 打包成消息
2. 发送给 Root Service
3. 在 Root Service 中执行

---

## 完整调用流程

### 阶段 1: 准备和发送 (test/start.lua → bootstrap.lua)

```lua
-- test/start.lua
local root_config = {
    initfunc = "...",  -- 字符串代码
    ...
}

-- 传递给 bootstrap.start
bootstrap.start {
    root_initfunc = root_config.initfunc,  -- 传递字符串
    ...
}
```

```lua
-- lualib/bootstrap.lua
local function bootstrap_root(initfunc, config)
    -- 1. 创建 Root Service (此时只是创建 VM，还未执行代码)
    local sid = boot.new_service("root", 
        config.service_source,      -- service/root.lua 的源代码
        config.service_chunkname,   -- "@service/root.lua"
        SERVICE_ROOT)
    
    -- 2. 初始化 Root Service (加载 ltask.root 模块)
    boot.init_root(SERVICE_ROOT)
    
    -- 3. 打包 init 消息
    local init_msg, sz = boot.pack("init", {
        initfunc = initfunc,        -- root_initfunc 字符串
        name = "root",
        args = {config}             -- 整个 config 对象
    })
    
    -- 4. 发送系统消息给 Root Service
    boot.post_message {
        from = SERVICE_ROOT,
        to = SERVICE_ROOT,
        session = 1,
        type = MESSAGE_SYSTEM,      -- 系统消息类型
        message = init_msg,
        size = sz,
    }
end
```

**关键点**:
- `boot.new_service()` 只是创建了 Root Service 的 VM 和加载了 `service/root.lua` 的源代码
- 但此时 `service/root.lua` 还没有执行！
- `root_initfunc` 作为字符串被打包在消息中

---

### 阶段 2: Root Service 接收消息 (service/root.lua)

当 Root Service 的 worker 线程开始运行时，会处理消息队列：

```lua
-- lualib/service.lua
local function schedule_message()
    local from, session, type, msg, sz = ltask.recv_message()
    local f = SESSION[type]  -- 根据消息类型获取处理函数
    
    if f then
        local co = new_session(f, from, session)
        wakeup_session(co, type, msg, sz)
    end
end
```

对于 `MESSAGE_SYSTEM` 类型：

```lua
SESSION[MESSAGE_SYSTEM] = function (type, msg, sz)
    system(ltask.unpack_remove(msg, sz))
end
```

`system()` 函数：

```lua
local function system(command, ...)
    local s = sys_service[command]  -- 查找 sys_service.init
    if not s then
        error("Unknown system message : " .. command)
        return
    end
    send_response(s(...))  -- 调用 sys_service.init(...)
end
```

**消息解包后的参数**:
- `command = "init"`
- `... = { initfunc = "...", name = "root", args = {config} }`

---

### 阶段 3: 执行 initfunc (sys_service.init)

```lua
-- lualib/service.lua
function sys_service.init(t)
    -- t = { initfunc = "...", name = "root", args = {config} }
    local ok, errobj = xpcall(sys_service_init, error_handler, t)
    if not ok then
        ltask.quit()
        rethrow_error(1, errobj)
    end
end
```

**核心执行函数 `sys_service_init`**:

```lua
local function sys_service_init(t)
    -- t.initfunc 是字符串: "local name = ... package.path = ... return loadfile(filename)"
    -- t.name = "root"
    -- t.args = {config}
    
    -- 1. 替换全局 require 为可 yield 的版本
    _G.require = yieldable_require
    
    -- 2. 将字符串编译成 Lua 函数
    local initfunc = assert(load(t.initfunc))
    -- 现在 initfunc 是一个函数，等价于:
    -- function(...)
    --     local name = ...  -- 只使用第一个参数
    --     package.path = ...
    --     local filename, err = package.searchpath(name, "service/?.lua;test/?.lua")
    --     if not filename then return nil, err end
    --     return loadfile(filename)
    -- end
    -- 注意：虽然函数可以接受多个参数（通过 ...），但实际上只使用了 name 参数
    
    -- 3. 执行 initfunc，传入服务名（path 参数会被忽略），得到加载函数
    local func = assert(initfunc(t.name, t.path))
    -- func 就是 loadfile("service/root.lua") 返回的函数
    -- 等价于: function(...) return loadfile("service/root.lua")(...) end
    
    -- 4. 调用加载函数，传入参数，执行服务文件，得到 handler
    local handler = func(table.unpack(t.args))
    -- 等价于: loadfile("service/root.lua")(config)
    -- 这会执行 service/root.lua，传入 config 作为参数
    -- service/root.lua 返回一个表 S = { spawn = ..., queryservice = ..., ... }
    
    -- 5. 注册服务接口
    ltask.dispatch(handler)
    -- 将 handler 中的函数注册到 service 表中
    
    -- 6. 检查是否有服务接口
    if service == nil then
        ltask.quit()  -- 如果没有注册任何接口，退出
    end
end
```

---

### 阶段 4: 服务文件执行 (service/root.lua)

当 `func(table.unpack(t.args))` 执行时，实际上就是：

```lua
-- 等价于执行:
local config = ...  -- 从 t.args[1] 获取
-- 然后执行 service/root.lua 的代码

local ltask = require "ltask"
local root = require "ltask.root"

local S = {}

function S.spawn(name, ...)
    -- ...
end

function S.queryservice(name)
    -- ...
end

-- ... 其他函数

ltask.dispatch(S)  -- 注册服务接口

bootstrap()  -- 启动引导服务
quit()

return S  -- 返回服务接口表
```

**关键点**:
- `service/root.lua` 执行时，`config` 作为参数传入
- 执行完成后返回服务接口表 `S`
- `ltask.dispatch(S)` 将 `S` 中的函数注册到 `service` 表中

---

## 代码执行细节

### 步骤 1: 字符串编译

```lua
-- 输入: 字符串
local initfunc_str = "local name = ... package.path = ... return loadfile(filename)"

-- 编译成函数
local initfunc = load(initfunc_str)

-- 等价于:
local initfunc = function(name, path)
    package.path = ...
    local filename, err = package.searchpath(name, "service/?.lua;test/?.lua")
    if not filename then
        return nil, err
    end
    return loadfile(filename)
end
```

### 步骤 2: 获取加载函数

```lua
-- 调用 initfunc，传入 "root"（第二个参数会被忽略）
local func = initfunc("root", t.path)  -- t.path 可能是 nil，但不影响

-- 执行过程:
-- 1. name = "root"  (从 ... 中取第一个参数)
-- 2. package.searchpath("root", "service/?.lua;test/?.lua")
--    找到 "service/root.lua"
-- 3. return loadfile("service/root.lua")

-- func 现在是一个函数，调用它会加载并执行 service/root.lua
-- 注意：虽然传入了两个参数，但 initfunc 函数内部只使用了第一个参数 name
```

### 步骤 3: 执行服务文件

```lua
-- 调用 func，传入 config
local handler = func(config)

-- 等价于:
local handler = loadfile("service/root.lua")(config)

-- 执行过程:
-- 1. loadfile("service/root.lua") 返回一个函数
-- 2. 调用这个函数，传入 config
-- 3. service/root.lua 执行，返回服务接口表 S
-- 4. handler = S
```

### 步骤 4: 注册服务接口

```lua
ltask.dispatch(handler)

-- dispatch 函数:
function ltask.dispatch(handler)
    if handler then
        service = service or {}
        for k, v in pairs(handler) do
            if type(v) == "function" then
                service[k] = v  -- 注册函数到 service 表
            end
        end
    end
    return service
end

-- 现在 service 表包含:
-- service.spawn = S.spawn
-- service.queryservice = S.queryservice
-- service.uniqueservice = S.uniqueservice
-- ...
```

---

## 关键函数解析

### 1. `load(string)` - 编译字符串

```lua
local func = load("return 1 + 2")
-- func 是一个函数，调用 func() 返回 3
```

### 2. `loadfile(filename)` - 加载文件

```lua
local func = loadfile("service/root.lua")
-- func 是一个函数，调用 func(...) 会执行 service/root.lua
-- 传入的参数会成为 service/root.lua 中的 ...
```

### 3. `ltask.dispatch(handler)` - 注册服务接口

```lua
-- 将 handler 表中的函数注册到全局 service 表
-- 后续的消息处理会从 service 表中查找函数
```

### 4. `package.searchpath(name, path)` - 搜索文件

```lua
local filename = package.searchpath("root", "service/?.lua;test/?.lua")
-- 在 service/?.lua 和 test/?.lua 中搜索 "root"
-- 找到 "service/root.lua"
```

---

## 流程图

```
test/start.lua
  ↓
创建 root_initfunc 字符串
  ↓
bootstrap.start()
  ↓
bootstrap_root()
  ├─ boot.new_service()      # 创建 Root Service VM
  ├─ boot.init_root()         # 加载 ltask.root 模块
  └─ boot.post_message()      # 发送 init 消息
      ↓
Root Service 消息队列
  ↓
schedule_message()
  ↓
SESSION[MESSAGE_SYSTEM]()
  ↓
system("init", {initfunc, name, args})
  ↓
sys_service.init(t)
  ↓
sys_service_init(t)
  ├─ load(t.initfunc)        # 编译字符串 → 函数1
  ├─ initfunc(name, path)    # 执行函数1 → loadfile() 函数
  ├─ func(args)              # 执行 loadfile() → 执行 service/root.lua
  └─ ltask.dispatch(handler) # 注册服务接口
      ↓
service/root.lua 执行
  ├─ local config = ...
  ├─ 定义服务函数 S = { ... }
  ├─ ltask.dispatch(S)
  ├─ bootstrap()
  └─ return S
      ↓
服务接口注册完成
  ↓
可以处理消息了
```

---

## 为什么这样设计？

### 1. 延迟执行

- `boot.new_service()` 只创建 VM 和加载源代码
- 不立即执行服务文件
- 通过消息机制触发执行

### 2. 统一初始化流程

- 所有服务都通过 `init` 消息初始化
- 使用相同的 `initfunc` 机制
- 便于管理和控制

### 3. 参数传递

- `initfunc` 可以访问正确的 `package.path` 和 `service_path`
- 服务文件执行时能正确加载依赖
- 配置参数通过 `args` 传递

### 4. 错误处理

- 使用 `xpcall` 捕获初始化错误
- 错误会通过消息返回给发送者
- Root Service 的 init 错误会导致系统退出

---

## 总结

`root_initfunc` 的调用流程：

1. **准备阶段**: 生成包含加载逻辑的字符串
2. **发送阶段**: 打包成消息发送给 Root Service
3. **接收阶段**: Root Service 接收 MESSAGE_SYSTEM 消息
4. **编译阶段**: 将字符串编译成函数
5. **执行阶段**: 执行函数加载服务文件
6. **注册阶段**: 注册服务接口到 service 表

整个过程通过消息机制实现，保证了服务初始化的统一性和可控性。
