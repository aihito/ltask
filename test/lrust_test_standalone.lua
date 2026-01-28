--- Standalone test that can be run directly
--- This test doesn't require the full ltask bootstrap
--- Usage: lua -e "dofile('test/lrust_test_standalone.lua')"

-- This is a simple test file that demonstrates the expected API
-- It won't actually work until Rust modules are compiled

print("========== lrust-ltask Standalone Test ==========")
print("This test demonstrates the expected API usage")
print("It requires Rust modules to be compiled with ltask support")
print()

-- Expected API usage examples:

print("--- Example 1: HTTP Client ---")
print([[
local httpc = require "httpc_ltask"

-- Simple GET request
local response = httpc.get("https://httpbin.org/get")
print("Status:", response.status_code)
print("Body:", response.body)

-- POST JSON
local json_response = httpc.post_json("https://httpbin.org/post", {
    name = "test",
    value = 123
})
]])

print("\n--- Example 2: SQLx Database ---")
print([[
local sqlx = require "sqlx_ltask"

-- Connect to database
local db = sqlx.connect("postgres://user:pass@localhost/dbname", "my_db")

-- Simple query
local rows = db:query("SELECT * FROM users WHERE id = $1", 123)
for _, row in ipairs(rows) do
    print("User:", row.name, row.email)
end

-- Transaction
db:transaction({
    {"INSERT INTO users (name) VALUES ($1)", "Alice"},
    {"UPDATE stats SET count = count + 1"}
})

-- Close connection
db:close()
]])

print("\n--- Example 3: MongoDB ---")
print([[
local mongodb = require "mongodb_ltask"

-- Connect
local db = mongodb.connect("mongodb://localhost:27017", "my_db")

-- Get collection
local coll = db:collection("mydb", "users")

-- Insert
coll:insert_one({
    name = "Alice",
    age = 30
})

-- Find
local users = coll:find({age = {["$gt"] = 25}})
for _, user in ipairs(users) do
    print("User:", user.name)
end
]])

print("\n--- Example 4: Using ltask API directly ---")
print([[
local ltask = require "ltask"

-- Get service pool (for Rust code)
local pool = ltask.get_service_pool()

-- Generate session ID
local session = ltask.next_session()

-- Wait for async result
local result = ltask.wait_session(session)
]])

print("\n========== API Examples Complete ==========")
print("\nTo actually run these examples:")
print("1. Ensure Rust code is modified (see docs/lrust-implementation-guide.md)")
print("2. Compile lrust with ltask support")
print("3. Use test/lrust_test_bootstrap.lua as bootstrap in test.lua")
