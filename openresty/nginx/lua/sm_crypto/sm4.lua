local key = "1234567890abcdef" -- 16 字节密钥（128-bit）
local iv = "abcdef1234567890" -- 16 字节初始向量（IV）

ngx.header.content_type = "text/html; charset=utf-8"
-- 设置响应状态码为 200
ngx.status = 200

local to_be_encrypted = "hello"
local mode = "sm4-cbc"
ngx.say("use cipher ", mode)

-- 使用one shot interface进行加密
local cipher, err = require("resty.openssl.cipher").new(mode)
if not cipher then
    ngx.say("Failed to create cipher: ", err)
    return
end

local encrypted, err = cipher:encrypt(key, iv, to_be_encrypted, false)
if not encrypted then
    ngx.say("Failed to encrypt: ", err)
    return
end

ngx.say("encryption result: ", ngx.encode_base64(encrypted)) -- base64编码，ngx自带这个函数

-- 使用one shot interface进行解密
local decrypted, err = cipher:decrypt(key, iv, encrypted, false)
if not decrypted then
    ngx.say("Failed to decrypt: ", err)
    return
end

ngx.say("decryption result: ", decrypted)

-- 测试较长的数据
local long_data = string.rep("test data ", 100)
local encrypted_long, err = cipher:encrypt(key, iv, long_data, false)
if not encrypted_long then
    ngx.say("Failed to encrypt long data: ", err)
    return
end

local decrypted_long, err = cipher:decrypt(key, iv, encrypted_long, false)
if not decrypted_long then
    ngx.say("Failed to decrypt long data: ", err)
    return
end

ngx.say("long data encryption/decryption: ", decrypted_long == long_data and "success" or "failed")

local utils = require "resty.utils" -- 引入 hex_utils 模块
local hex_str = utils.bin_to_hex(encrypted)
ngx.say("encryption result: ", hex_str)