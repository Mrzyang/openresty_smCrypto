local sm_crypto = require "resty.sm_crypto" -- 引入 sm_crypto 模块
-- SM4 加密
local sm4_key = "1234567890abcdef" -- 16 字节密钥
local sm4_iv = "abcdef1234567890" -- 16 字节 IV
local mode = "sm4-cbc"

local buffered = {}

local chunk, eof = ngx.arg[1], ngx.arg[2]

-- 将当前块添加到缓冲区
if chunk ~= "" then
    table.insert(ngx.ctx.buffered, chunk)
    ngx.arg[1] = nil -- 清空当前块，避免重复发送
end

-- 如果是最后一个块，拼接所有块并处理
if eof then
    local full_body = table.concat(ngx.ctx.buffered)
    ngx.log(ngx.INFO, "完整响应报文体: ", full_body, "分割线--------------")
    -- 对响应体进行加密或其他处理
    local encrypted_body = sm_crypto.encrypt(full_body, sm4_key, sm4_iv, mode) -- 进行对称加密
    ngx.log(ngx.INFO, "加密后的报文体: ", encrypted_body, "分割线--------------")
    -- 如果需要将完整的响应体发送给客户端，可以重新设置ngx.arg[1]
    ngx.arg[1] = encrypted_body
end
