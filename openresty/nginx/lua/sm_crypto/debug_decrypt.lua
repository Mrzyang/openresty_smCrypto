-- 调试解密过程
local sm_crypto = require "api_gateway.sm_crypto_utils"

-- 测试数据（来自错误信息）
local encrypted_base64 = "fVkw5b5yc8FoIZfpns7ukB/xjSXhc5Q4xIOxHkhTHXt33j5KXA9iVabJzS2c4e/9Une/PZDCzrlXyHtnWogHJA=="
local key = "1234567890abcdef"  -- 16字节密钥
local iv = "abcdef1234567890"   -- 16字节IV

ngx.header.content_type = "text/html; charset=utf-8"
ngx.status = 200

ngx.say("=== SM4 解密调试 ===")
ngx.say("密钥: ", key)
ngx.say("IV: ", iv)
ngx.say("加密数据 (base64): ", encrypted_base64)
ngx.say("")

-- 解密
local decrypted, err = sm_crypto.sm4_decrypt(encrypted_base64, key, iv)
if not decrypted then
    ngx.say("解密失败: ", err)
    return
end

ngx.say("解密后: ", decrypted)
ngx.say("")

ngx.say("测试结果: 成功")