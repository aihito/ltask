# root_initfunc 调用示例

这是一个简化的示例，帮助理解 `root_initfunc` 的调用过程。

## 简化示例

### 1. 准备 initfunc 字符串

```lua
-- test/start.lua
local initfunc_str = [[
local name = ...
package.path = "service/?.lua"
local filename = package.searchpath(name, "service/?.lua")
return loadfile(filename)
]]
```

### 2. 发送消息

```lua
-- bootstrap.lua
boot.post_message {
    to = SERVICE_ROOT,
    type = MESSAGE_SYSTEM,
    message = boot.pack("init", {
        initfunc = initfunc_str,  -- 字符串
        name = "root",
        args = {config}
    })
}
```

### 3. Root Service 接收并处理

```lua
-- service.lua 中的处理流程

-- 收到消息后，解包得到:
local command = "init"
local t = {
    initfunc = "local name = ... return loadfile(...)",  -- 字符串
    name = "root",
    args = {config}
}

-- 调用 sys_service.init(t)
function sys_service.init(t)
    -- 1. 编译字符串
    local initfunc = load(t.initfunc)
    -- initfunc 现在是: function(name, path) ... end
    
    -- 2. 执行 initfunc，获取加载函数
    local func = initfunc("root", t.path)  -- 只使用第一个参数 "root"，path 会被忽略
    -- func 现在是: loadfile("service/root.lua") 返回的函数
    
    -- 3. 执行加载函数，运行服务文件
    local handler = func(config)
    -- 这会执行 service/root.lua，传入 config
    -- service/root.lua 返回服务接口表 S
    
    -- 4. 注册服务接口
    ltask.dispatch(handler)
    -- 将 S 中的函数注册到 service 表
end
```

### 4. 等价代码

整个过程等价于：

```lua
-- 在 Root Service 的 VM 中执行:

-- 步骤 1: 编译 initfunc 字符串
local initfunc = load([[
local name = ...
package.path = "service/?.lua"
local filename = package.searchpath(name, "service/?.lua")
return loadfile(filename)
]])

-- 步骤 2: 执行 initfunc，获取加载函数
local func = initfunc("root", nil)
-- 等价于: func = loadfile("service/root.lua")

-- 步骤 3: 执行服务文件
local handler = func(config)
-- 等价于: local handler = loadfile("service/root.lua")(config)
-- 这会:
--   1. 加载 service/root.lua
--   2. 执行它，传入 config
--   3. 返回服务接口表

-- 步骤 4: 注册
ltask.dispatch(handler)
```

## 关键理解点

1. **initfunc 是字符串，不是函数**
   - 它包含加载服务文件的代码
   - 需要先 `load()` 编译，再执行

2. **执行过程是嵌套的**
   ```
   load(initfunc_str)()("root")("service/root.lua")(config)
   ```

3. **最终结果是服务接口表**
   - `service/root.lua` 执行后返回一个表
   - 这个表通过 `ltask.dispatch()` 注册
   - 后续消息处理会从这个表查找函数

## 实际执行顺序

```
时间线:
T1: boot.new_service()        # 创建 VM，加载源代码（不执行）
T2: boot.post_message()        # 发送 init 消息
T3: Root Service 开始运行     # Worker 线程处理消息
T4: schedule_message()         # 从消息队列获取消息
T5: SESSION[MESSAGE_SYSTEM]() # 路由到系统消息处理
T6: sys_service.init()         # 执行初始化
T7: load(initfunc_str)         # 编译字符串
T8: initfunc("root")           # 获取加载函数
T9: func(config)               # 执行服务文件
T10: service/root.lua 执行     # 服务代码运行
T11: ltask.dispatch(S)         # 注册接口
T12: 服务可以处理消息了        # 初始化完成
```
