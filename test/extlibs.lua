-- Test ext_lualib/sqlx with MySQL: connect and run one query.
-- Set DB_URL to your MySQL, e.g. DB_URL="mysql://root:123456@127.0.0.1:3306/test?ssl-mode=DISABLED"
local ltask = require "ltask"
local sqlx = require "sqlx"

print("extlibs startup", ltask.self())

local db_url = os.getenv("DB_URL") or "mysql://root:123@127.0.0.1:3306/test?ssl-mode=DISABLED"
local conn_name = "extlibs_conn"

local db = sqlx.connect(db_url, conn_name)
print("connected:", db_url)

local rows = db:query("SELECT 1 as n")
print("query result:", rows)
if rows and rows[1] then
	print("row.n =", rows[1].n)
end

db:close()
print("extlibs done")
ltask.quit()
