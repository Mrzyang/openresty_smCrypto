-- 直接对sm3的hash值做sm2签名
local function sign_direct(sm3_hashed, sm2_private_key_pem)
    local pkey = require "resty.openssl.pkey"
    local priv_key, err = pkey.new(sm2_private_key_pem, {
        type = "pr",
        format = "PEM"
    })
    if not priv_key then
        ngx.log(ngx.ERR, "Failed to load private key: " .. err)
        return nil
    end

    -- 使用私钥对哈希值进行签名
    local signature, err = priv_key:sign(sm3_hashed)
    if not signature then
        ngx.log(ngx.ERR, "Failed to sign data: " .. err)
        return nil
    end
    return ngx.encode_base64(signature)
end

local sm2_private_key_pem = [[
-----BEGIN PRIVATE KEY-----
MIGHAgEAMBMGByqGSM49AgEGCCqBHM9VAYItBG0wawIBAQQg8HLOQ9PlccsWBgNp
ForNIOvr0pFRp7jzUrNj78RbIuahRANCAASeMvuRVyaRFFkFCkrTHEo2xqKvIzp3
sfJjNNf5jyB7m9EVuiz0RpQqNfEk2PP1EpC40stZ351d6cYida6BGT7u
-----END PRIVATE KEY-----
]]

-- 网络传输过程中hash摘要经过了base64处理，下面解base64为字节数组
local sm3Hashed_buffer = ngx.decode_base64(ngx.header["hashed"])
local signature = sign_direct(sm3Hashed_buffer, sm2_private_key_pem)
if not signature then
    ngx.log(ngx.ERR, "签名出现异常")
    ngx.exit(ngx.ERROR)
    return
end

ngx.header["hashed"] = nil
ngx.header["X-Signature"] = signature -- 设置签名头

-- 响应头中的Content-Length字段一定要设置为nil，因为报文加密了并且做了base64，即使算出了报文长度也无法加在响应头中了，为避免客户端接收的数据被截断，就设置为空，让自动识别
ngx.header["Content-Length"] = nil
ngx.ctx.buffered = {}  -- 用于存储响应块

