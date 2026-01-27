-- 工具函数库
-- 提供通用的打印和格式化功能

-- 检查对象是否有字符串表示（通过 __tostring 元方法）
local function has_string_representation(obj)
    if type(obj) ~= "table" then
        return false
    end
    local mt = getmetatable(obj)
    -- 检查是否有 __tostring 元方法
    return mt and mt.__tostring ~= nil
end

-- 打印表格数据（支持嵌套、数组、字典等）
local function print_table_data(data, indent, max_depth)
    indent = indent or 0
    max_depth = max_depth or 1000  -- 增加默认深度限制，避免意外截断
    if max_depth <= 0 then
        io.write(string.rep("  ", indent) .. "... (max depth reached)\n")
        return
    end
    
    local prefix = string.rep("  ", indent)
    
    -- 对于有 __tostring 的对象，需要区分：
    -- 1. Octets 等特殊类型：直接打印字符串表示
    -- 2. RPCData 类对象：打印表内容（避免递归）
    if has_string_representation(data) and type(data) == "table" then
        -- 检查是否是 Octets 或 ProtocBuf 等特殊类型（通过检查是否有 get_data 方法）
        if data.get_data or (data.value and data.type) then
            -- 特殊类型，打印字符串表示
            io.write(prefix .. string.format("%q", tostring(data)) .. "\n")
            return
        end
        -- RPCData 类对象，继续打印表内容
    elseif has_string_representation(data) then
        -- 非表类型，直接打印字符串表示
        io.write(prefix .. string.format("%q", tostring(data)) .. "\n")
        return
    end
    
    if type(data) == "table" then
        -- 检查是否是数组
        local is_array = true
        local max_index = 0
        local has_non_numeric_keys = false
        
        for k, v in pairs(data) do
            if type(k) ~= "number" or k ~= math.floor(k) or k < 1 then
                is_array = false
                has_non_numeric_keys = true
                break
            end
            if k > max_index then
                max_index = k
            end
        end
        
        -- 如果只有数字键且从1开始连续，或者空表，当作数组处理
        if is_array and not has_non_numeric_keys then
            -- 数组格式：使用原始 Lua 表格式 {}
            if max_index == 0 then
                io.write("{\n")
                io.write(prefix .. "}\n")
            else
                io.write("{\n")
                for i = 1, max_index do
                    io.write(prefix .. "  [" .. i .. "] = ")
                    if data[i] == nil then
                        io.write("nil\n")
                    elseif type(data[i]) == "table" then
                        -- 对于表类型，直接打印内容（即使有 __tostring）
                        if has_string_representation(data[i]) and getmetatable(data[i]) and getmetatable(data[i])._type_name then
                            -- 有类型名的对象，打印其内容
                            io.write("{\n")
                            print_table_data(data[i], indent + 2, max_depth - 1)
                            io.write(prefix .. "  }\n")
                        else
                            io.write("{\n")
                            print_table_data(data[i], indent + 2, max_depth - 1)
                            io.write(prefix .. "  }\n")
                        end
                    elseif has_string_representation(data[i]) then
                        -- 非表的对象（如 Octets），打印字符串表示
                        io.write(string.format("%q", tostring(data[i])) .. "\n")
                    elseif type(data[i]) == "table" then
                        io.write("{\n")
                        print_table_data(data[i], indent + 2, max_depth - 1)
                        io.write(prefix .. "  }\n")
                    elseif type(data[i]) == "string" then
                        io.write(string.format("%q", data[i]) .. "\n")
                    elseif type(data[i]) == "number" then
                        -- 判断是否为整数
                        if data[i] == math.floor(data[i]) then
                            -- 整数：直接打印
                            io.write(string.format("%d", data[i]) .. "\n")
                        else
                            -- 小数：格式化打印（保留合理的小数位数）
                            io.write(string.format("%.10g", data[i]) .. "\n")
                        end
                    else
                        io.write(tostring(data[i]) .. "\n")
                    end
                end
                io.write(prefix .. "}\n")
            end
        else
            -- 字典格式（按键名排序，便于调试）
            local keys = {}
            for k in pairs(data) do
                table.insert(keys, k)
            end

            table.sort(keys, function(a, b)
                local ta, tb = type(a), type(b)
                if ta ~= tb then
                    return ta < tb
                end
                return a < b
            end)
            
            io.write(prefix .. "{\n")
            for _, k in ipairs(keys) do
                local v = data[k]
                io.write(prefix .. "  " .. tostring(k) .. " = ")
                if type(v) == "table" then
                    print_table_data(v, indent + 1, max_depth - 1)
                elseif has_string_representation(v) then
                    -- 非表的对象（如 Octets），打印字符串表示
                    io.write(string.format("%q", tostring(v)) .. "\n")
                elseif type(v) == "string" then
                    io.write(string.format("%q", v) .. "\n")
                elseif type(v) == "number" then
                    -- 判断是否为整数
                    if v == math.floor(v) then
                        -- 整数：直接打印
                        io.write(string.format("%d", v) .. "\n")
                    else
                        -- 小数：格式化打印（保留合理的小数位数）
                        io.write(string.format("%.10g", v) .. "\n")
                    end
                else
                    io.write(tostring(v) .. "\n")
                end
            end
            io.write(prefix .. "}\n")
        end
    elseif type(data) == "string" then
        io.write(prefix .. string.format("%q", data) .. "\n")
    elseif type(data) == "number" then
        -- 判断是否为整数
        if data == math.floor(data) then
            -- 整数：直接打印
            io.write(prefix .. string.format("%d", data) .. "\n")
        else
            -- 小数：格式化打印（保留合理的小数位数）
            io.write(prefix .. string.format("%.10g", data) .. "\n")
        end
    else
        io.write(prefix .. tostring(data) .. "\n")
    end
end

-- 格式化表格数据为字符串（返回字符串而不是直接输出）
local function format_table_data(data, indent, max_depth)
    local output = {}
    indent = indent or 0
    max_depth = max_depth or 1000
    
    local function write(str)
        table.insert(output, str)
    end
    
    local function format_recursive(data, indent, max_depth)
        if max_depth <= 0 then
            write(string.rep("  ", indent) .. "... (max depth reached)\n")
            return
        end
        
        local prefix = string.rep("  ", indent)
        
        if has_string_representation(data) and type(data) == "table" then
            if data.get_data or (data.value and data.type) then
                write(prefix .. tostring(data) .. "\n")
                return
            end
        elseif has_string_representation(data) then
            write(prefix .. tostring(data) .. "\n")
            return
        end
        
        if type(data) == "table" then
            local is_array = true
            local max_index = 0
            local has_non_numeric_keys = false
            
            for k, v in pairs(data) do
                if type(k) ~= "number" or k ~= math.floor(k) or k < 1 then
                    is_array = false
                    has_non_numeric_keys = true
                    break
                end
                if k > max_index then
                    max_index = k
                end
            end
            
            if is_array and not has_non_numeric_keys then
                if max_index == 0 then
                    write("{}\n")
                else
                    write("{\n")
                    for i = 1, max_index do
                        write(prefix .. "  [" .. i .. "] = ")
                        if data[i] == nil then
                            write("nil\n")
                        elseif type(data[i]) == "table" then
                            write("{\n")
                            format_recursive(data[i], indent + 2, max_depth - 1)
                            write(prefix .. "  }\n")
                        elseif type(data[i]) == "string" then
                            write(data[i] .. "\n")
                        elseif type(data[i]) == "number" then
                            if data[i] == math.floor(data[i]) then
                                write(string.format("%d", data[i]) .. "\n")
                            else
                                write(string.format("%.10g", data[i]) .. "\n")
                            end
                        else
                            write(tostring(data[i]) .. "\n")
                        end
                    end
                    write(prefix .. "}\n")
                end
            else
                local keys = {}
                for k in pairs(data) do
                    table.insert(keys, k)
                end
                table.sort(keys, function(a, b)
                    local ta, tb = type(a), type(b)
                    if ta ~= tb then
                        return ta < tb
                    end
                    return a < b
                end)
                
                write(prefix .. "{\n")
                for _, k in ipairs(keys) do
                    local v = data[k]
                    write(prefix .. "  " .. tostring(k) .. " = ")
                    if type(v) == "table" then
                        format_recursive(v, indent + 1, max_depth - 1)
                    elseif type(v) == "string" then
                        write(v .. "\n")
                    elseif type(v) == "number" then
                        if v == math.floor(v) then
                            write(string.format("%d", v) .. "\n")
                        else
                            write(string.format("%.10g", v) .. "\n")
                        end
                    else
                        write(tostring(v) .. "\n")
                    end
                end
                write(prefix .. "}\n")
            end
        elseif type(data) == "string" then
            write(prefix .. data .. "\n")
        elseif type(data) == "number" then
            if data == math.floor(data) then
                write(prefix .. string.format("%d", data) .. "\n")
            else
                write(prefix .. string.format("%.10g", data) .. "\n")
            end
        else
            write(prefix .. tostring(data) .. "\n")
        end
    end
    
    format_recursive(data, indent, max_depth)
    return table.concat(output)
end

-- 执行命令并检查结果
-- 使用 os.execute()：只检查命令是否成功执行，无法获取输出内容
-- 适合只需要知道命令是否成功的场景
local function execute_command(cmd, description, continue_on_error)
    print("执行:", cmd)
    local success, exit_type, exit_code = os.execute(cmd)
    
    if not success or (exit_code and exit_code ~= 0) then
        local err_msg = "命令执行失败: " .. description
        err_msg = err_msg .. "\n命令: " .. cmd
        if exit_code then
            err_msg = err_msg .. "\n退出码: " .. tostring(exit_code)
        end
        if continue_on_error then
            print("⚠️  " .. err_msg .. "\n")
            return false
        else
            error(err_msg)
        end
    end
    print("✓ 成功\n")
    return true
end

-- 读取二进制文件
-- @param filename: 文件路径
-- @return: 字节数组（table of numbers），每个元素是 0-255 的整数
local function read_binary_file(filename)
    local file = io.open(filename, "rb")
    if not file then
        error("Cannot open file: " .. filename)
    end
    
    -- 一次性读取所有内容（字符串），然后转换为字节数组
    local content = file:read("*all")
    file:close()
    
    if not content then
        return {}
    end
    
    -- 将字符串转换为字节数组
    local data = {}
    for i = 1, #content do
        data[i] = string.byte(content, i)
    end
    
    return data
end

-- 检查文件是否存在且可执行
local function check_file_exists(filepath)
    local check_cmd = string.format("test -x %s 2>/dev/null", filepath)
    local success, exit_type, exit_code = os.execute(check_cmd)
    return success or (exit_code and exit_code == 0)
end

-- 执行 protoc 命令并返回输出
-- 使用 io.popen()：可以获取命令的标准输出内容，用于分析输出（如检查警告信息）
-- io.popen() 的作用：
--   1. 打开一个进程管道，可以读取命令的输出
--   2. 返回一个文件句柄，可以像读取文件一样读取命令的输出
--   3. 需要手动关闭句柄（handle:close()）
-- 适合需要分析命令输出内容的场景（如检查 protoc 的警告信息）
local function run_protoc_command(cmd)
    local handle = io.popen(cmd)
    local output = ""
    if handle then
        output = handle:read("*all")
        handle:close()
    end
    return output
end

-- ============================================
-- 字节数组与整数转换工具（支持大小端序）
-- ============================================

-- 将无符号整数（可能为负数）转换为字符串表示
-- Lua 5.4 的 64 位整数范围是 -2^63 到 2^63-1
-- 对于无符号整数，如果值 >= 2^63，Lua 会将其解释为负数
-- 此函数将负数转换为正确的无符号字符串表示
-- @param value: 整数值（可能是负数，代表无符号整数）
-- @param bit_count: 位数（默认 64）
-- @return: 字符串表示的无符号整数
local function uint_to_string(value, bit_count)
    bit_count = bit_count or 64
    if value >= 0 then
        -- 对于正数，直接转换为字符串
        return tostring(value)
    end
    
    -- 如果 value < 0，说明它代表的是 2^bit_count + value（在无符号表示中）
    -- 对于 64 位：正确的无符号值 = value + 2^64
    
    if bit_count == 64 then
        -- Lua 5.4 中，math.maxinteger = 2^63 - 1, math.mininteger = -2^63
        -- 对于负数 value，无符号值 = value + 2^64
        
        -- 方法：使用 math.maxinteger 和 math.mininteger 来避免直接计算 2^64
        -- value + 2^64 = value - min_int + max_int + 1
        -- 但 max_int + 1 会溢出，所以需要分段计算
        
        local max_int = math.maxinteger  -- 2^63 - 1
        local min_int = math.mininteger  -- -2^63
        
        -- 计算 diff = value - min_int
        -- 这个结果在 [0, 2^63-1] 范围内，是整数
        local diff = value - min_int
        
        if diff >= 0 and diff <= max_int then
            -- 现在需要计算：diff + max_int + 1 = diff + 2^63
            -- 但 max_int + 1 = 2^63 会变成浮点数，所以需要特殊处理
            
            -- 分段计算：先计算 diff + max_int（都是整数，结果可能是整数或浮点数）
            local step1 = diff + max_int
            
            -- 如果 step1 是整数且在范围内，继续加 1
            if step1 >= 0 and step1 <= max_int * 2 then
                local result = step1 + 1
                -- 尝试使用 %d 格式
                local ok, str = pcall(string.format, "%d", result)
                if ok and tonumber(str) == result then
                    return str
                end
                -- 如果 result 是浮点数，使用 %.0f（可能有精度损失）
                ok, str = pcall(string.format, "%.0f", result)
                if ok then
                    return str
                end
            else
                -- step1 超出了整数范围，变成了浮点数
                -- 使用 %.0f 格式化
                local result = step1 + 1
                local ok, str = pcall(string.format, "%.0f", result)
                if ok then
                    return str
                end
            end
        end
        
        -- 如果上述方法都失败，返回十六进制表示
        -- 对于调试目的，十六进制表示更清晰且无精度损失
        local hex_str = string.format("0x%016X", value & 0xFFFFFFFFFFFFFFFF)
        return string.format("%d (unsigned, hex: %s)", value, hex_str)
    end
    
    -- 对于其他位数（< 64），可以直接计算
    local max_unsigned = (1 << bit_count) - 1
    if value < 0 then
        -- 对于小于 64 位的情况，1 << bit_count 仍在整数范围内
        local unsigned_value = value + (1 << bit_count)
        return tostring(unsigned_value)
    end
    
    return tostring(value)
end

-- 将字节数组转换为无符号整数（小端序，Little-Endian）
-- @param bytes: 字节字符串
-- @param byte_count: 字节数量（1-8），如果为 nil，则使用 bytes 的长度
-- @return: 无符号整数值（number）
-- 注意：Lua 5.3+ 支持 64 位整数，但可能显示为负数（如果最高位为1）
-- 此函数使用 string.unpack 来正确处理无符号整数
local function bytes_to_uint_le(bytes, byte_count)
    byte_count = byte_count or #bytes
    if byte_count == 0 then
        return 0
    end
    if byte_count > 8 then
        error("byte_count must be <= 8, got " .. tostring(byte_count))
    end
    
    -- 构建格式字符串：<I1, <I2, <I4, <I8 分别对应 1, 2, 4, 8 字节
    local format_map = {
        [1] = "<I1",
        [2] = "<I2",
        [3] = "<I3",  -- 3 字节需要特殊处理
        [4] = "<I4",
        [5] = "<I5",  -- 5 字节需要特殊处理
        [6] = "<I6",  -- 6 字节需要特殊处理
        [7] = "<I7",  -- 7 字节需要特殊处理
        [8] = "<I8"
    }
    
    -- 对于 3, 5, 6, 7 字节，需要手动计算（string.unpack 不支持这些格式）
    if byte_count == 3 or byte_count == 5 or byte_count == 6 or byte_count == 7 then
        local value = 0
        for i = 1, byte_count do
            local byte = string.byte(bytes, i)
            value = value | (byte << ((i - 1) * 8))
        end
        return value
    end
    
    -- 使用 string.unpack 处理标准格式（1, 2, 4, 8 字节）
    local format = format_map[byte_count]
    local val = string.unpack(format, bytes)
    return val
end

-- 将字节数组转换为有符号整数（小端序，Little-Endian）
-- @param bytes: 字节字符串
-- @param byte_count: 字节数量（1-8），如果为 nil，则使用 bytes 的长度
-- @return: 有符号整数值（number）
local function bytes_to_int_le(bytes, byte_count)
    byte_count = byte_count or #bytes
    if byte_count == 0 then
        return 0
    end
    if byte_count > 8 then
        error("byte_count must be <= 8, got " .. tostring(byte_count))
    end
    
    -- 先按无符号读取
    local uint_val = bytes_to_uint_le(bytes, byte_count)
    
    -- 根据字节数确定符号位位置
    local sign_bit_shift = (byte_count * 8) - 1
    local sign_bit = (uint_val >> sign_bit_shift) & 1
    
    -- 如果符号位为 1，转换为负数
    if sign_bit == 1 then
        local max_unsigned = (1 << (byte_count * 8)) - 1
        local max_signed = (1 << (sign_bit_shift)) - 1
        if uint_val > max_signed then
            return uint_val - (max_unsigned + 1)
        end
    end
    
    return uint_val
end

-- 将字节数组转换为无符号整数（大端序，Big-Endian）
-- @param bytes: 字节字符串
-- @param byte_count: 字节数量（1-8），如果为 nil，则使用 bytes 的长度
-- @return: 无符号整数值（number）
local function bytes_to_uint_be(bytes, byte_count)
    byte_count = byte_count or #bytes
    if byte_count == 0 then
        return 0
    end
    if byte_count > 8 then
        error("byte_count must be <= 8, got " .. tostring(byte_count))
    end
    
    -- 构建格式字符串：>I1, >I2, >I4, >I8 分别对应 1, 2, 4, 8 字节
    local format_map = {
        [1] = ">I1",
        [2] = ">I2",
        [4] = ">I4",
        [8] = ">I8"
    }
    
    -- 对于非标准字节数，需要手动计算
    if format_map[byte_count] == nil then
        local value = 0
        for i = 1, byte_count do
            local byte = string.byte(bytes, i)
            value = (value << 8) | byte
        end
        return value
    end
    
    local format = format_map[byte_count]
    local val = string.unpack(format, bytes)
    return val
end

-- 格式化 key 的字节十进制表示（用于长 key）
-- @param key_bytes: key 的字节字符串
-- @param max_bytes: 最多显示的字节数（默认 16）
-- @return: 格式化后的字符串，例如 "1 2 3 ... (100 bytes)"
local function format_key_bytes_decimal(key_bytes, max_bytes)
    max_bytes = max_bytes or 16
    local key_len = #key_bytes
    local decimals = {}
    local display_count = math.min(key_len, max_bytes)
    
    for i = 1, display_count do
        decimals[i] = tostring(string.byte(key_bytes, i))
    end
    
    if key_len > max_bytes then
        return table.concat(decimals, " ") .. " ... (" .. key_len .. " bytes)"
    else
        return table.concat(decimals, " ")
    end
end

-- ============================================
-- 将十六进制字符串转换为字节数组
-- ============================================
-- @param hex_str: 十六进制字符串（如 "48006900690072006f00"）
-- @return: 字节数组（table of numbers），每个元素是 0-255 的整数
local function hex_string_to_bytes(hex_str)
    if not hex_str or hex_str == "" then
        return {}
    end
    -- 移除空白字符
    hex_str = hex_str:gsub("%s+", "")
    local bytes = {}
    for i = 1, #hex_str, 2 do
        local byte_str = hex_str:sub(i, i + 1)
        if byte_str and #byte_str == 2 then
            local byte = tonumber(byte_str, 16)
            if byte then
                table.insert(bytes, byte)
            end
        end
    end
    return bytes
end

--[[
将字符串转换为字节数组（用于 OctetsStream）
@param str: 输入字符串（可以是普通字符串或二进制字符串）
@return: 字节数组（table of numbers），每个元素是 0-255 的整数值
@usage:
    local bytes = string_to_bytes("ABC")  -- 返回 {65, 66, 67}
    local bytes = string_to_bytes(binary_data)  -- 将二进制字符串转换为字节数组
]]
local function string_to_bytes(str)
    local bytes = {}
    for i = 1, #str do
        bytes[i] = string.byte(str:sub(i, i))
    end
    return bytes
end

--[[
将字节数组转换为十六进制字符串
@param bytes: 输入数据，可以是：
    - 字节数组（table of numbers，每个元素 0-255）
    - 字符串（会自动转换为字节数组）
@return: 十六进制字符串，每个字节用两位十六进制表示，字节之间用空格分隔
@usage:
    local hex = bytes_to_hex({255, 0, 26})  -- 返回 "FF 00 1A"
    local hex = bytes_to_hex(binary_string)  -- 返回二进制字符串的十六进制表示
    local hex = bytes_to_hex("ABC")  -- 返回 "41 42 43"（ASCII 值的十六进制）
]]
local function bytes_to_hex(bytes)
    if type(bytes) == "string" then
        bytes = string_to_bytes(bytes)
    end
    local hex = {}
    for i = 1, #bytes do
        hex[i] = string.format("%02X", bytes[i])
    end
    return table.concat(hex, " ")
end

-- 格式化 key 的十进制表示（智能选择整数或字节列表）
-- @param key_bytes: key 的字节字符串
-- @param options: 选项表
--   - max_bytes_for_int: 尝试转换为整数的最大字节数（默认 8）
--   - max_bytes_display: 显示的最大字节数（默认 16）
--   - use_unsigned: 是否使用无符号整数（默认 true）
--   - byte_order: "le" (小端序) 或 "be" (大端序)，默认 "le"
-- @return: 格式化后的字符串
local function format_key_decimal(key_bytes, options)
    options = options or {}
    local max_bytes_for_int = options.max_bytes_for_int or 8
    local max_bytes_display = options.max_bytes_display or 16
    local use_unsigned = options.use_unsigned ~= false  -- 默认 true
    local byte_order = options.byte_order or "le"  -- 默认小端序
    
    local key_len = #key_bytes
    if key_len == 0 then
        return "0"
    elseif key_len <= max_bytes_for_int then
        -- 尝试转换为整数
        local value
        if byte_order == "le" then
            value = use_unsigned and bytes_to_uint_le(key_bytes) or bytes_to_int_le(key_bytes)
        else
            value = bytes_to_uint_be(key_bytes)  -- 大端序暂时只支持无符号
        end
        
        -- 对于无符号整数，如果结果是负数（值 >= 2^63），需要转换为正确的无符号表示
        if use_unsigned and value < 0 then
            return uint_to_string(value, key_len * 8)
        end
        
        -- 使用 string.format 避免科学计数法
        -- 对于整数，使用 %d 格式可以避免科学计数法且保持精度
        -- 但如果值太大，%d 可能会失败，所以先尝试 %d，失败则使用 tostring
        local ok, result = pcall(string.format, "%d", value)
        if ok then
            return result
        end
        
        -- 如果 %d 失败，尝试 %.0f（可能有精度损失）
        ok, result = pcall(string.format, "%.0f", value)
        if ok then
            return result
        end
        
        return tostring(value)
    else
        -- 对于长 key，显示每个字节的十进制值
        return format_key_bytes_decimal(key_bytes, max_bytes_display)
    end
end

local function setup_luarocks_path()
    local luarocks_path_cmd = io.popen("luarocks path --local 2>/dev/null")
    if luarocks_path_cmd then
        local output = luarocks_path_cmd:read("*all")
        luarocks_path_cmd:close()
        
        for line in output:gmatch("[^\n]+") do
            if line:match("^export LUA_PATH") then
                local path = line:match("LUA_PATH='([^']+)'")
                if path then
                    package.path = path .. ";" .. package.path
                end
            elseif line:match("^export LUA_CPATH") then
                local path = line:match("LUA_CPATH='([^']+)'")
                if path then
                    package.cpath = path .. ";" .. package.cpath
                end
            end
        end
    end
end

local function read_int32_text(file)
    local digits = {}
    while true do
        local byte = file:read(1)
        if not byte then return nil end
        local b = string.byte(byte)
        if b >= 0x30 and b <= 0x39 then  -- '0'-'9'
            table.insert(digits, b - 0x30)
        elseif b == 0x2D then  -- '-'
            -- 负数，但这里应该都是正数
            -- 暂时忽略
        elseif b == 0x20 or b == 0x09 or b == 0x0A or b == 0x0D then
            -- 空白字符，跳过
            -- 0x20 = 空格 (Space)
            -- 0x09 = 制表符 (Tab, '\t')
            -- 0x0A = 换行符 (Line Feed, LF, '\n')
            -- 0x0D = 回车符 (Carriage Return, CR, '\r')
        else
            -- 非数字字符，回退
            file:seek("cur", -1)
            break
        end
    end
    if #digits == 0 then
        return nil 
    end
    local value = 0
    for i = 1, #digits do
        value = value * 10 + digits[i]
    end
    return value
end

-- 读取指定长度的字节
local function read_bytes(file, size)
    if size == 0 then return "" end
    local data = file:read(size)
    if not data or #data ~= size then 
        return nil    
    end
    return data
end

-- 导出函数
return {
    has_string_representation = has_string_representation,
    print_table_data = print_table_data,
    format_table_data = format_table_data,
    execute_command = execute_command,
    read_binary_file = read_binary_file,
    check_file_exists = check_file_exists,
    run_protoc_command = run_protoc_command,
    -- 字节转换函数
    bytes_to_uint_le = bytes_to_uint_le,
    bytes_to_int_le = bytes_to_int_le,
    bytes_to_uint_be = bytes_to_uint_be,
    format_key_decimal = format_key_decimal,
    format_key_bytes_decimal = format_key_bytes_decimal,
    string_to_bytes = string_to_bytes,
    bytes_to_hex = bytes_to_hex,
    -- 十六进制转换函数
    hex_string_to_bytes = hex_string_to_bytes,
    setup_luarocks_path = setup_luarocks_path,
    read_int32_text = read_int32_text,
    read_bytes = read_bytes,
}

