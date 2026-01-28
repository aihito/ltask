--- Bootstrap file for lrust-ltask integration test
--- Usage: Modify test.lua to use this as bootstrap

local ltask = require "ltask"

print("========== lrust-ltask Integration Test Bootstrap ==========")
print("Service:", ltask.self(), ltask.label())
-- ltask.now() returns time in seconds (already converted from 1/100 seconds)
local ok, time_str = pcall(function()
    return os.date("%c", ltask.now())
end)
if ok then
    print("Time:", time_str)
else
    print("Time: (unavailable)")
end

-- Test 1: Verify ltask extensions are available
print("\n--- Verifying ltask extensions ---")
local pool = ltask.get_service_pool()
local session = ltask.next_session()

assert(pool ~= nil, "get_service_pool() should return non-nil")
assert(session > 0, "next_session() should return positive number")

print("  [PASS] ltask.get_service_pool() =", pool)
print("  [PASS] ltask.next_session() =", session)

-- Test 2: Test HTTP client (if available)
print("\n--- Testing HTTP Client ---")
local function test_http()
    -- Load rust_loader first
    local loader_ok, loader = pcall(require, "rust_loader")
    if loader_ok and loader then
        print("  [INFO] rust_loader loaded")
        -- Try manual load using loader function
        local loader_func = loader.loader
        if loader_func then
            print("  [INFO] Trying manual loader for rust.httpc...")
            local ok2, mod2, err2 = pcall(loader_func, "rust.httpc")
            if ok2 and mod2 then
                print("  [INFO] Manual load succeeded!")
                print("  [INFO] Module type:", type(mod2))
                for k, v in pairs(mod2) do
                    print("    -", k, type(v))
                end
                -- Store in package.loaded so require can find it
                package.loaded["rust.httpc"] = mod2
            else
                print("  [INFO] Manual load failed:", mod2 or err2)
            end
        end
    else
        print("  [INFO] rust_loader failed:", loader)
    end
    
    -- Now try require again
    local rust_ok, rust_module = pcall(require, "rust.httpc")
    if rust_ok and rust_module then
        print("  [INFO] rust.httpc loaded via require")
    else
        print("  [INFO] rust.httpc require failed:", rust_module or "unknown")
    end
    
    local ok, result = pcall(require, "httpc_ltask")
    if not ok then
        print("  [SKIP] httpc_ltask module not found")
        print("         Error:", result or "unknown error")
        print("         Make sure:")
        print("           1. httpc_ltask.lua exists in 3rd/lrust/lualib/")
        print("           2. Rust http module (rust.httpc) is compiled")
        print("           3. Rust code is modified to use ltask API")
        return
    end
    local httpc = result
    
    print("  Making HTTP GET request to httpbin.org...")
    local response = httpc.get("https://httpbin.org/get?test=ltask")
    
    if response.status_code == 200 then
        print("  [PASS] HTTP GET successful")
        print("  Status:", response.status_code)
        if response.body and type(response.body) == "table" then
            print("  Response contains data")
        end
    else
        print("  [FAIL] HTTP GET failed")
        print("  Status:", response.status_code)
    end
end

ltask.fork(test_http)

-- Test 3: Test SQLx (if available)
print("\n--- Testing SQLx Database ---")
local function test_sqlx()
    local ok, result = pcall(require, "sqlx_ltask")
    if not ok then
        print("  [SKIP] sqlx_ltask module not found")
        print("         Error:", result or "unknown error")
        print("         Make sure:")
        print("           1. sqlx_ltask.lua exists in 3rd/lrust/lualib/")
        print("           2. Rust sqlx module (rust.sqlx) is compiled")
        print("           3. Rust code is modified to use ltask API")
        return
    end
    local sqlx = result
    
    -- Try to connect to SQLite in-memory database
    print("  Connecting to SQLite in-memory database...")
    local db = sqlx.connect("sqlite://:memory:", "test_conn")
    
    if db.kind then
        print("  [FAIL] Connection failed:", db.message)
        return
    end
    
    print("  [PASS] Database connection successful")
    
    -- Create a test table
    print("  Creating test table...")
    local create_result = db:query([[
        CREATE TABLE test_users (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            email TEXT
        )
    ]])
    
    if create_result.kind then
        print("  [FAIL] Create table failed:", create_result.message)
        return
    end
    
    print("  [PASS] Table created")
    
    -- Insert test data
    print("  Inserting test data...")
    local insert_result = db:query(
        "INSERT INTO test_users (name, email) VALUES (?, ?)",
        "Alice", "alice@example.com"
    )
    
    if insert_result.kind then
        print("  [FAIL] Insert failed:", insert_result.message)
        return
    end
    
    print("  [PASS] Data inserted")
    
    -- Query data
    print("  Querying data...")
    local query_result = db:query("SELECT * FROM test_users WHERE name = ?", "Alice")
    
    if query_result.kind then
        print("  [FAIL] Query failed:", query_result.message)
        return
    end
    
    if #query_result > 0 then
        print("  [PASS] Query successful")
        print("  Found", #query_result, "row(s)")
        print("  First row - name:", query_result[1].name, "email:", query_result[1].email)
    else
        print("  [FAIL] No rows returned")
    end
    
    -- Test transaction
    print("  Testing transaction...")
    local trans_result = db:transaction({
        {"INSERT INTO test_users (name, email) VALUES (?, ?)", "Bob", "bob@example.com"},
        {"INSERT INTO test_users (name, email) VALUES (?, ?)", "Charlie", "charlie@example.com"}
    })
    
    if trans_result.kind then
        print("  [FAIL] Transaction failed:", trans_result.message)
    else
        print("  [PASS] Transaction successful")
        
        -- Verify transaction
        local verify = db:query("SELECT COUNT(*) as count FROM test_users")
        if not verify.kind and verify[1] then
            print("  Total users:", verify[1].count)
        end
    end
    
    -- Close connection
    db:close()
    print("  [PASS] Connection closed")
end

ltask.fork(test_sqlx)

-- Wait for async tests to complete
print("\n--- Waiting for async tests to complete ---")
ltask.sleep(5)

print("\n========== Test Bootstrap Complete ==========")
print("Check output above for test results")
print("\nNote: Some tests may be skipped if Rust modules are not available")
print("To enable full testing:")
print("  1. Modify Rust code to use ltask_send_bytes")
print("  2. Compile lrust with ltask support")
print("  3. Ensure modules are properly linked")
