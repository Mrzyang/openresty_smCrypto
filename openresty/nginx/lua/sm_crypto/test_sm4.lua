local sm_crypto = require "api_gateway.sm_crypto_utils"

-- 测试SM4加密和解密
local key = "1234567890abcdef"  -- 16字节密钥
local iv = "abcdef1234567890"   -- 16字节IV
local plaintext = "This is a test message for SM4 encryption and decryption."

ngx.header.content_type = "text/html; charset=utf-8"
ngx.status = 200

ngx.say("=== SM4 加密/解密测试 ===")
ngx.say("密钥: ", key)
ngx.say("IV: ", iv)
ngx.say("明文: ", plaintext)
ngx.say("")

-- 加密
local encrypted, err = sm_crypto.sm4_encrypt(plaintext, key, iv)
if not encrypted then
    ngx.say("加密失败: ", err)
    return
end

ngx.say("加密后: ", encrypted)
ngx.say("")

-- 解密
local decrypted, err = sm_crypto.sm4_decrypt(encrypted, key, iv)
if not decrypted then
    ngx.say("解密失败: ", err)
    return
end

ngx.say("解密后: ", decrypted)
ngx.say("")

-- 验证
if plaintext == decrypted then
    ngx.say("测试结果: 成功")
else
    ngx.say("测试结果: 失败")
    ngx.say("原始文本和解密文本不匹配")
end