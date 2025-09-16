local digest = require "resty.openssl.digest"

ngx.header.content_type = "text/html; charset=utf-8"
-- 设置响应状态码为 200
ngx.status = 200
local hashed = digest.new("sm3"):final("hello")
ngx.say("hashed result: ", ngx.encode_base64(hashed)) -- base64编码，ngx自带这个函数

local utils = require "resty.utils"  -- 引入 hex_utils 模块
local hex_str = utils.bin_to_hex(hashed)
ngx.say(hex_str)

