-- 前面写API网关基本请求报文验签、解密、黑白名单、限流、防重放
-- 下面实现响报文回签、加密给客户端
local uri = ngx.var.uri -- 只获取路径部分，例如 /api/user
-- 触发子请求，获取后端的原始响应。内部代理或需要调用同一台服务器上的不同location时，ngx.location.capture性能上比 proxy_pass 更好。
local res = ngx.location.capture(uri .. '_')

if not res or res.status ~= 200 then
    ngx.log(ngx.ERR, "Backend request failed")
    return ngx.exit(500)
end

local response_body = res.body -- 获取后端返回的响应体
-- SM2 签名，这里PEM格式的私钥，前面-----BEGIN PRIVATE KEY-----以及-----END PRIVATE KEY-----千万不能留空格和制表符，否则无法识别和加载
local sm2_private_key_pem = [[
-----BEGIN PRIVATE KEY-----
MIGHAgEAMBMGByqGSM49AgEGCCqBHM9VAYItBG0wawIBAQQg8HLOQ9PlccsWBgNp
ForNIOvr0pFRp7jzUrNj78RbIuahRANCAASeMvuRVyaRFFkFCkrTHEo2xqKvIzp3
sfJjNNf5jyB7m9EVuiz0RpQqNfEk2PP1EpC40stZ351d6cYida6BGT7u
-----END PRIVATE KEY-----
]]
local sm_crypto = require "resty.sm_crypto" -- 引入 sm_crypto 模块
local signature = sm_crypto.sign(response_body, sm2_private_key_pem) -- 计算签名
-- SM4 加密
local sm4_key = "1234567890abcdef" -- 16 字节密钥
local sm4_iv = "1234567890abcdef" -- 16 字节 IV
local mode = "sm4-cbc"
local encrypted_body = sm_crypto.encrypt(response_body, sm4_key, sm4_iv, mode) -- 进行对称加密

-- 设置修改后的响应头
ngx.header["X-Signature"] = signature
ngx.header["Content-Length"] = #encrypted_body -- 修正长度

ngx.header.content_type = "text/html; charset=utf-8"
-- 设置响应状态码为 200
ngx.status = 200
-- 返回加密后的响应体
ngx.say(encrypted_body)
return ngx.exit(ngx.HTTP_OK)
