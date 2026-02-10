-- Test ext_lualib/sqlx with MySQL.
--
-- Prereq: MySQL reachable at host:port (default 127.0.0.1:23306).
-- Connect as root: mysql --protocol=tcp -h 127.0.0.1 -P 23306 -u root -p123
--
-- This script:
--   1. Connects using DB_URL (default: mysql://root:123@127.0.0.1:23306/test?ssl-mode=DISABLED)
--   2. Creates database `game` if not exists
--   3. Creates test table `game.extlibs_test` if not exists
--   4. Runs SELECT 1 and SELECT from the test table
--
-- Override: DB_URL="mysql://user:pass@host:port/db?ssl-mode=DISABLED"
--
local ltask = require "ltask"
local sqlx = require "sqlx"

print("extlibs startup", ltask.self())

-- 默认连 mysql 系统库（一定存在），脚本里再建 game 库和表
local db_url = os.getenv("DB_URL") or "mysql://hito:123@127.0.0.1:23306/game?ssl-mode=DISABLED"
local conn_name = "extlibs_conn"

local db = sqlx.connect(db_url, conn_name)
print("connected:", db_url)

-- Create database and test table
-- db:execute("CREATE DATABASE IF NOT EXISTS game")
-- db:execute([[
--   CREATE TABLE IF NOT EXISTS game.extlibs_test (
--     id INT PRIMARY KEY AUTO_INCREMENT,
--     name VARCHAR(64),
--     created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
--   )
-- ]])
-- db:execute("INSERT INTO game.extlibs_test (name) VALUES (?)", "extlibs_hello")

-- 测试用角色名，便于最后清理
local test_role_name = "extlibs_test_role"

local function print_role_rows(tbl, prefix)
	if not tbl or #tbl == 0 then
		print(prefix or "role", "rows: 0")
		return
	end
	print(prefix or "role", "rows:", #tbl)
	for i, row in ipairs(tbl) do
		print(string.format("  [%d] id=%s role_name=%s job_type=%s level=%s created_at=%s",
			i, tostring(row.id), tostring(row.role_name), tostring(row.job_type), tostring(row.level), tostring(row.created_at)))
	end
end

-- 1. 查询全部角色 (see stest/mysql: role 表 id, role_name, job_type, level, created_at)
print("--- 1. SELECT * FROM role ---")
local tbl = db:query("SELECT * FROM role")
print_role_rows(tbl, "role")

-- 2. 参数化查询：按职业
print("--- 2. 参数化查询 job_type = 'Mage' ---")
tbl = db:query("SELECT * FROM role WHERE job_type = ?", "Mage")
print_role_rows(tbl, "Mage")

-- 3. 参数化查询：等级 >= 某值
print("--- 3. 参数化查询 level >= 50 ---")
tbl = db:query("SELECT * FROM role WHERE level >= ?", 50)
print_role_rows(tbl, "level>=50")

-- 4. 单条查询 LIMIT 1
print("--- 4. SELECT 单条 (LIMIT 1) ---")
tbl = db:query("SELECT * FROM role ORDER BY id LIMIT 1")
print_role_rows(tbl, "first")

-- 5. 聚合 COUNT
print("--- 5. SELECT COUNT(*) ---")
tbl = db:query("SELECT COUNT(*) AS cnt FROM role")
local cnt = tbl and tbl[1] and tbl[1].cnt
print("  role count:", tostring(cnt))

-- 6. INSERT 测试角色（用 query 等待完成再查）
print("--- 6. INSERT 测试角色 ---")
local _ = db:query("INSERT INTO role (role_name, job_type, level) VALUES (?, ?, ?)", test_role_name, "Warrior", 1)
tbl = db:query("SELECT * FROM role WHERE role_name = ?", test_role_name)
print_role_rows(tbl, "after_insert")
local inserted_level = tbl and tbl[1] and tbl[1].level
print("  inserted level:", tostring(inserted_level))

-- 7. UPDATE 测试角色等级
print("--- 7. UPDATE level = 88 ---")
_ = db:query("UPDATE role SET level = ? WHERE role_name = ?", 88, test_role_name)
tbl = db:query("SELECT * FROM role WHERE role_name = ?", test_role_name)
print_role_rows(tbl, "after_update")
local updated_level = tbl and tbl[1] and tbl[1].level
print("  updated level:", tostring(updated_level))

-- 8. 事务：插入两条后回滚（或提交后删除）。这里用事务插入两条再查
print("--- 8. 事务 INSERT 两条 ---")
local trans_ok = db:transaction({
	{"INSERT INTO role (role_name, job_type, level) VALUES (?, ?, ?)", test_role_name .. "_a", "Archer", 10},
	{"INSERT INTO role (role_name, job_type, level) VALUES (?, ?, ?)", test_role_name .. "_b", "Mage", 20},
})
print("  transaction result:", trans_ok and (trans_ok.message == "ok" and "ok" or tostring(trans_ok.message)) or tostring(trans_ok))
tbl = db:query("SELECT * FROM role WHERE role_name LIKE ? ORDER BY role_name", test_role_name .. "%")
print_role_rows(tbl, "after_trans")

-- 9. 清理测试数据
print("--- 9. DELETE 测试数据 ---")
_ = db:query("DELETE FROM role WHERE role_name = ? OR role_name = ? OR role_name = ?",
	test_role_name, test_role_name .. "_a", test_role_name .. "_b")
tbl = db:query("SELECT * FROM role WHERE role_name LIKE ?", test_role_name .. "%")
print("  remaining test rows:", tbl and #tbl or 0)

db:close()
print("extlibs done")
ltask.quit()

-- while true do
-- 	ltask.sleep(1)
-- end