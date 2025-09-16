local pkey = require "resty.openssl.pkey"

ngx.header.content_type = "text/html; charset=utf-8"
-- 设置响应状态码为 200
ngx.status = 200

-- 自定义 SM2 私钥（PEM 格式）
local priv_key_pem = [[
-----BEGIN PRIVATE KEY-----
MIGHAgEAMBMGByqGSM49AgEGCCqBHM9VAYItBG0wawIBAQQg8HLOQ9PlccsWBgNp
ForNIOvr0pFRp7jzUrNj78RbIuahRANCAASeMvuRVyaRFFkFCkrTHEo2xqKvIzp3
sfJjNNf5jyB7m9EVuiz0RpQqNfEk2PP1EpC40stZ351d6cYida6BGT7u
-----END PRIVATE KEY-----
]]

local priv_key, err = pkey.new(priv_key_pem, {
    type = "pr",
    format = "PEM"
})
if not priv_key then
    ngx.say("Failed to load private key: ", err)
    return
end

-- 要签名的数据
local data = "hello"

-- 使用私钥对哈希值进行签名
local sig, err = priv_key:sign(data, "sm3")
if not sig then
    ngx.say("Failed to sign data: ", err)
    return
end

-- 输出签名结果（Base64 编码）
ngx.say("Signature: ", ngx.encode_base64(sig))

-- 自定义 SM2 公钥（PEM 格式）
local pub_key_pem = [[
-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoEcz1UBgi0DQgAEnjL7kVcmkRRZBQpK0xxKNsairyM6
d7HyYzTX+Y8ge5vRFbos9EaUKjXxJNjz9RKQuNLLWd+dXenGInWugRk+7g==
-----END PUBLIC KEY-----
]]

local pub_key, err = pkey.new(pub_key_pem, {
    format = "PEM",
    type = "pu"
})

if not pub_key then
    ngx.say("Failed to load public key: ", err)
    return
end

-- 使用公钥验证签名
local is_valid, err = pub_key:verify(sig, data, "sm3")
if not is_valid then
    ngx.say("Signature is invalid: ", err)
    return
end

-- 输出验证结果
ngx.say("Signature is valid!")
