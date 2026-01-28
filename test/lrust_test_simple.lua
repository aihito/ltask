--- Simple test file for lrust-ltask integration
--- This is a minimal test that can run even without Rust modules compiled

local ltask = require "ltask"

print("========== Simple lrust-ltask Test ==========")

-- Test basic ltask functions for lrust integration
print("\n1. Testing ltask.get_service_pool()")
local pool = ltask.get_service_pool()
print("   Service pool pointer:", pool)
assert(pool ~= nil, "Service pool should not be nil")
print("   [PASS] get_service_pool works")

print("\n2. Testing ltask.next_session()")
local sessions = {}
for i = 1, 5 do
    sessions[i] = ltask.next_session()
    print("   Session", i .. ":", sessions[i])
end

-- Verify sessions are incrementing
for i = 2, 5 do
    assert(sessions[i] > sessions[i-1], "Sessions should increment")
end
print("   [PASS] next_session increments correctly")

print("\n3. Testing session waiting mechanism")
local test_session = ltask.next_session()
print("   Created test session:", test_session)

-- Create a token for waiting
local token = {}
local external_session_waiting = {}
external_session_waiting[test_session] = token

print("   Session registered for waiting")

-- Simulate what would happen when Rust callback arrives
-- In real scenario, this would be triggered by ltask_external_send_message
print("   [INFO] In real usage, Rust would call ltask_external_send_message")
print("   [INFO] which would trigger ltask.wakeup_session()")

print("\n4. Testing service ID")
local service_id = ltask.self()
print("   Current service ID:", service_id)
assert(service_id > 0, "Service ID should be positive")
print("   [PASS] Service ID is valid")

print("\n========== Basic Tests Complete ==========")
print("\nTo test with actual Rust modules:")
print("1. Ensure Rust code is modified to use ltask_send_bytes")
print("2. Compile lrust with ltask support")
print("3. Run: lua test.lua (with lrust_test.lua as bootstrap)")
