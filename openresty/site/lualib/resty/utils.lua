-- hex_utils.lua
local M = {}

-- 将二进制字符串转换为十六进制字符串
function M.bin_to_hex(binary_str)
    local hex_str = ""
    for i = 1, #binary_str do
        hex_str = hex_str .. string.format("%02x", string.byte(binary_str, i))
    end
    return hex_str
end

return M
