local key = "1234567890abcdef" -- 16 字节密钥（128-bit）
local iv = "abcdef1234567890" -- 16 字节初始向量（IV）

ngx.header.content_type = "text/html; charset=utf-8"
-- 设置响应状态码为 200
ngx.status = 200

local to_be_encrypted = "hello"
-- local mode = "AES-256-gcm"
local mode = "sm4-cbc"
ngx.say("use cipher ", mode)

-- using one shot interface
local cipher = assert(require("resty.openssl.cipher").new(mode))
local encrypted = assert(cipher:encrypt(key, iv, to_be_encrypted, false))
-------------------------------------------------------
-- OR using streaming interface
-- assert(cipher:init(key, iv, {
--     is_encrypt = true
-- }))
-- encrypted = assert(cipher:final(to_be_encrypted))
-------------------------------------------------------
ngx.say("encryption result: ", ngx.encode_base64(encrypted)) -- base64编码，ngx自带这个函数

local utils = require "resty.utils" -- 引入 hex_utils 模块
local hex_str = utils.bin_to_hex(encrypted)
ngx.say("encryption result: ", hex_str)

