--- Test configuration for lrust-ltask integration
--- Usage: lua test_lrust.lua

local start = require "test.start"

-- Add Rust library to Lua C path (also check repo root)
if package.config:sub(1,1) == "\\" then
    -- Windows
    package.cpath = package.cpath .. ";./?.dll;./3rd/lrust/target/release/?.dll"
else
    -- Unix-like
    package.cpath = package.cpath .. ";./?.so;./?.dylib;./3rd/lrust/target/release/?.so;./3rd/lrust/target/release/?.dylib"
end

-- Add Rust Lua modules to package.path
package.path = package.path .. ";3rd/lrust/lualib/?.lua"

-- Note: rust_loader will be loaded by the service when it needs rust modules
-- We can't require it here because ltask environment isn't ready yet

start {
    core = {
        debuglog = "=", -- stdout
        worker = 3,
    },
    service_path = "service/?.lua;test/?.lua;3rd/lrust/lualib/?.lua",
    bootstrap = {
        {
            name = "timer",
            unique = true,
        },
        {
            name = "logger",
            unique = true,
        },
        {
            name = "sockevent",
            unique = true,
        },
        {
            name = "lrust_test_bootstrap",  -- Use our test bootstrap
        },
    },
}
