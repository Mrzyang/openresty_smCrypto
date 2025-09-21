local gmCryptor = require "gmCryptor-go"
local cjson = require "cjson"

local base64_str = "Xpqxnw+xf6KO2aKPZ5oG75UXOqC74FRgiYAcMZ+F2oMLXPMZGCYnD44aZFc3Cv2p"

-- 将base64解码后的字符串并转换成十六进制字符串
local function decode_base64_to_hex_str(base64_str)
    local decoded = ngx.decode_base64(base64_str)
    if not decoded then
        ngx.log(ngx.ERR, "Base64解码失败")
        return nil
    end
    local t = {}
    for i = 1, #decoded do
        t[#t+1] = string.format("%02X", string.byte(decoded, i))
    end
    return table.concat(t, "")
end

ngx.say(decode_base64_to_hex_str(base64_str))