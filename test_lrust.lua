--- Test configuration for lrust-ltask integration
--- Usage: lua test_lrust.lua

local start = require "test.start"

package.cpath = package.cpath .. ";luaclib/?.so"
package.path = package.path .. ";ext_lualib/?.lua"

start {
    core = {
        debuglog = "=", -- stdout
        worker = 3,
    },
    service_path = "service/?.lua;test/?.lua",
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
            name = "extlibs",  -- Use our test bootstrap
        },
    },
}
