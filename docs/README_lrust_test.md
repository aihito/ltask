# lrust-ltask 集成测试说明

## 测试文件说明

### 1. `lrust_test_simple.lua`
**最简单的测试文件**，只测试 ltask 的基础扩展功能，不需要 Rust 模块。

**运行方式**:
```bash
# 修改 test.lua，将 bootstrap 改为 "lrust_test_simple"
lua test.lua
```

**测试内容**:
- `ltask.get_service_pool()` - 获取服务池指针
- `ltask.next_session()` - 生成会话ID
- 会话管理机制

### 2. `lrust_test_bootstrap.lua`
**完整的测试文件**，测试 HTTP 和数据库功能（需要 Rust 模块编译）。

**运行方式**:
```bash
# 使用专门的测试配置
lua test_lrust.lua
```

**或者修改 test.lua**:
```lua
bootstrap = {
    -- ... other services ...
    {
        name = "lrust_test_bootstrap",
    },
}
```

**测试内容**:
- HTTP 客户端测试
- SQLx 数据库测试（SQLite in-memory）
- 事务测试
- 错误处理测试

### 3. `lrust_test.lua`
**详细的测试文件**，包含更多测试场景。

### 4. `lrust_test_standalone.lua`
**API 示例文档**，展示如何使用各个模块的 API。

## 快速开始

### 步骤 1: 测试基础功能（不需要 Rust）

```bash
# 1. 修改 test.lua
# 将 bootstrap 中的 "bootstrap" 改为 "lrust_test_simple"

# 2. 运行测试
lua test.lua
```

### 步骤 2: 测试完整功能（需要 Rust 模块）

```bash
# 1. 确保 Rust 代码已修改（参考 docs/lrust-implementation-guide.md）
# 2. 编译 lrust
cd 3rd/lrust
cargo build

# 3. 运行测试
cd ../..
lua test_lrust.lua
```

## 测试环境变量

### 数据库测试

设置 `TEST_DB_URL` 环境变量来测试真实的数据库连接：

```bash
# PostgreSQL
export TEST_DB_URL="postgres://user:password@localhost/dbname"
lua test_lrust.lua

# MySQL
export TEST_DB_URL="mysql://user:password@localhost/dbname"
lua test_lrust.lua

# SQLite (默认使用 in-memory)
# 不需要设置环境变量
```

## 预期输出

### 成功输出示例

```
========== lrust-ltask Integration Test Bootstrap ==========
Service: 5 timer
Time: Wed Jan 28 10:00:00 2026

--- Verifying ltask extensions ---
  [PASS] ltask.get_service_pool() = 0x7f8b1c000000
  [PASS] ltask.next_session() = 1

--- Testing HTTP Client ---
  Making HTTP GET request to httpbin.org...
  [PASS] HTTP GET successful
  Status: 200

--- Testing SQLx Database ---
  Connecting to SQLite in-memory database...
  [PASS] Database connection successful
  [PASS] Table created
  [PASS] Data inserted
  [PASS] Query successful
  Found 1 row(s)
  First row - name: Alice email: alice@example.com
  [PASS] Transaction successful
  Total users: 3
  [PASS] Connection closed
```

### 跳过测试（Rust 模块未编译）

```
--- Testing HTTP Client ---
  [SKIP] httpc_ltask module not found
         Make sure Rust http module is compiled and linked

--- Testing SQLx Database ---
  [SKIP] sqlx_ltask module not found
         Make sure Rust sqlx module is compiled and linked
```

## 故障排除

### 问题 1: 模块未找到

**错误**: `module 'httpc_ltask' not found`

**解决**:
1. 检查 Rust 模块是否已编译
2. 检查 `service_path` 是否包含 `3rd/lrust/lualib/?.lua`
3. 确保 Lua 包装文件存在

### 问题 2: 函数未定义

**错误**: `attempt to call a nil value (global 'ltask.get_service_pool')`

**解决**:
1. 确保已重新编译 ltask（`make clean && make`）
2. 检查 `src/ltask.c` 中的函数是否已添加

### 问题 3: 数据库连接失败

**错误**: `connect database failed: ...`

**解决**:
1. 检查数据库 URL 格式
2. 确保数据库服务正在运行
3. 检查网络连接和权限

## 下一步

1. **修改 Rust 代码**: 参考 `docs/lrust-implementation-guide.md`
2. **编译测试**: 确保所有模块正确编译
3. **运行完整测试**: 使用 `test_lrust.lua`
4. **查看文档**: 参考 `docs/lrust-ltask-integration-design.md`
