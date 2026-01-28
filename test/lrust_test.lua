--- Test file for lrust modules adapted to ltask
--- This file demonstrates how to use lrust modules (httpc, sqlx, mongodb) with ltask

local ltask = require "ltask"

print("========== lrust-ltask Integration Test ==========")
print("Service ID:", ltask.self())
print("Service Pool:", ltask.get_service_pool())
print("Next Session:", ltask.next_session())

-- Test 1: Basic session management
print("\n--- Test 1: Session Management ---")
local session1 = ltask.next_session()
local session2 = ltask.next_session()
print("Session 1:", session1)
print("Session 2:", session2)
assert(session2 > session1, "Session counter should increment")

-- Test 2: HTTP Client (if available)
print("\n--- Test 2: HTTP Client ---")
local function test_http_client()
    local httpc = require "httpc_ltask"
    if not httpc then
        print("  [SKIP] httpc_ltask not available (Rust module not compiled)")
        return
    end
    
    print("  Testing HTTP GET request...")
    local response = httpc.get("https://httpbin.org/get")
    print("  Status Code:", response.status_code)
    print("  Response OK:", response.status_code == 200)
    
    if response.status_code == 200 then
        print("  [PASS] HTTP GET test")
    else
        print("  [FAIL] HTTP GET test - status:", response.status_code)
    end
end

-- Run HTTP test in a coroutine to handle async
ltask.fork(function()
    local ok, err = pcall(test_http_client)
    if not ok then
        print("  [ERROR] HTTP test failed:", err)
    end
end)

-- Test 3: SQLx Database (if available)
print("\n--- Test 3: SQLx Database ---")
local function test_sqlx()
    local sqlx = require "sqlx_ltask"
    if not sqlx then
        print("  [SKIP] sqlx_ltask not available (Rust module not compiled)")
        return
    end
    
    -- Test connection
    print("  Testing database connection...")
    local db_url = os.getenv("TEST_DB_URL") or "sqlite://:memory:"
    print("  Database URL:", db_url)
    
    local db = sqlx.connect(db_url, "test_db")
    if db.kind then
        print("  [FAIL] Connection failed:", db.message)
        return
    end
    
    print("  [PASS] Database connection successful")
    
    -- Test query
    print("  Testing SQL query...")
    local result = db:query("SELECT 1 as test_value")
    if result.kind then
        print("  [FAIL] Query failed:", result.message)
        return
    end
    
    print("  Query result:", #result, "rows")
    if #result > 0 then
        print("  First row:", result[1].test_value)
        print("  [PASS] SQL query test")
    else
        print("  [FAIL] No rows returned")
    end
    
    -- Test transaction
    print("  Testing transaction...")
    local trans_result = db:transaction({
        {"CREATE TABLE IF NOT EXISTS test_table (id INTEGER PRIMARY KEY, name TEXT)"},
        {"INSERT INTO test_table (name) VALUES (?)", "test_name"}
    })
    
    if trans_result.kind then
        print("  [FAIL] Transaction failed:", trans_result.message)
    else
        print("  [PASS] Transaction test")
        
        -- Verify insert
        local verify = db:query("SELECT name FROM test_table WHERE name = ?", "test_name")
        if not verify.kind and #verify > 0 then
            print("  [PASS] Transaction verification")
        else
            print("  [FAIL] Transaction verification failed")
        end
    end
    
    db:close()
    print("  [PASS] Database close")
end

-- Run SQLx test
ltask.fork(function()
    local ok, err = pcall(test_sqlx)
    if not ok then
        print("  [ERROR] SQLx test failed:", err)
    end
end)

-- Test 4: Wait for async operations
print("\n--- Test 4: Async Operations ---")
local function test_async_operations()
    -- Test wait_session
    print("  Testing wait_session...")
    local test_session = ltask.next_session()
    print("  Created session:", test_session)
    
    -- In a real scenario, this would be called from Rust callback
    -- For testing, we'll simulate it
    ltask.fork(function()
        ltask.sleep(1)  -- Simulate async operation
        -- Simulate Rust callback waking up the session
        -- In real usage, this would be done by Rust code via ltask_external_send_message
        print("  Simulating async callback for session:", test_session)
        -- ltask.wakeup_session(test_session, "test_result")
    end)
    
    print("  [INFO] Async operation test (requires Rust module to complete)")
end

test_async_operations()

-- Test 5: Error handling
print("\n--- Test 5: Error Handling ---")
local function test_error_handling()
    local sqlx = require "sqlx_ltask"
    if not sqlx then
        print("  [SKIP] sqlx_ltask not available")
        return
    end
    
    -- Test invalid query
    print("  Testing error handling with invalid query...")
    local db = sqlx.connect("sqlite://:memory:", "error_test_db")
    if db.kind then
        print("  [SKIP] Could not connect to test database")
        return
    end
    
    local result = db:query("SELECT * FROM non_existent_table")
    if result.kind then
        print("  [PASS] Error properly returned:", result.message)
    else
        print("  [FAIL] Error not properly handled")
    end
    
    db:close()
end

ltask.fork(function()
    local ok, err = pcall(test_error_handling)
    if not ok then
        print("  [ERROR] Error handling test failed:", err)
    end
end)

-- Wait a bit for async operations
print("\n--- Waiting for async operations to complete ---")
ltask.sleep(3)

print("\n========== Test Summary ==========")
print("Note: Some tests may be skipped if Rust modules are not compiled")
print("To enable full testing:")
print("1. Compile lrust with ltask support")
print("2. Ensure Rust modules are linked correctly")
print("3. Set TEST_DB_URL environment variable for database tests")

print("\nTest completed. Check output above for results.")
