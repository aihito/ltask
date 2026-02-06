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
local db_url = os.getenv("DB_URL") or "mysql://root:123@127.0.0.1:23306/game?ssl-mode=DISABLED"
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

-- Query the test table
local tbl = db:query("SELECT id, name, created_at FROM game.extlibs_test ORDER BY id DESC LIMIT 5")
print("game.extlibs_test rows:", tbl and #tbl or 0)
if tbl then
	for i, row in ipairs(tbl) do
		print(string.format("  [%d] id=%s name=%s created_at=%s", i, tostring(row.id), tostring(row.name), tostring(row.created_at)))
	end
end

db:close()
print("extlibs done")
ltask.quit()
