-- 测试解密逻辑
local sm_crypto = require "api_gateway.sm_crypto_utils"

-- 测试数据（来自Node.js客户端）
local encrypted_base64 = "fVkw5b5yc8FoIZfpns7ukB/xjSXhc5Q4xIOxHkhTHXupodGiwyrF3Yv0/J9grcFq"
local key = "1234567890abcdef"  -- 16字节密钥
local iv = "abcdef1234567890"   -- 16字节IV
local expected_result = '{"name":"Test User","email":"test@example.com"}'

ngx.header.content_type = "text/html; charset=utf-8"
ngx.status = 200

ngx.say("=== SM4 解密测试 ===")
ngx.say("密钥: ", key)
ngx.say("IV: ", iv)
ngx.say("加密数据 (base64): ", encrypted_base64)
ngx.say("")

-- 检查base64解码
local cipher_bytes = ngx.decode_base64(encrypted_base64)
if not cipher_bytes then
    ngx.say("Base64解码失败")
    return
end
ngx.say("Base64解码成功，长度: ", #cipher_bytes)

-- 检查密钥和IV处理
local function ensure_16_bytes(str)
    if type(str) ~= "string" then
        return nil, "Invalid input type"
    end
    
    if #str == 16 then
        return str
    elseif #str > 16 then
        return string.sub(str, 1, 16)
    else
        return str .. string.rep("\0", 16 - #str)
    end
end

local fixed_key, err = ensure_16_bytes(key)
if not fixed_key then
    ngx.say("密钥处理失败: ", err)
    return
end

local fixed_iv, err = ensure_16_bytes(iv)
if not fixed_iv then
    ngx.say("IV处理失败: ", err)
    return
end

ngx.say("固定后密钥: ", fixed_key, " (长度: ", #fixed_key, ")")
ngx.say("固定后IV: ", fixed_iv, " (长度: ", #fixed_iv, ")")

-- 解密
local decrypted, err = sm_crypto.sm4_decrypt(encrypted_base64, key, iv)
if not decrypted then
    ngx.say("解密失败: ", err)
    return
end

ngx.say("解密后: ", decrypted)
ngx.say("")

if decrypted == expected_result then
    ngx.say("测试结果: 成功")
else
    ngx.say("测试结果: 失败 - 解密结果不匹配")
    ngx.say("期望结果: ", expected_result)
end