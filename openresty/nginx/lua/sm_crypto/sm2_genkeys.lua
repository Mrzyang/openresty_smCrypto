local pkey = require "resty.openssl.pkey"

-- 生成 SM2 密钥对
local key, err = pkey.new({
    type = "EC",  -- 指定密钥类型为椭圆曲线（EC）
    curve = "sm2",  -- 指定曲线为 SM2
})

if not key then
    ngx.say("Failed to generate SM2 key pair: ", err)
    return
end

-- 提取私钥（PEM 格式）
local priv_key_pem, err = key:to_PEM("private")
if not priv_key_pem then
    ngx.say("Failed to extract private key: ", err)
    return
end

-- 提取公钥（PEM 格式）
local pub_key_pem, err = key:to_PEM("public")
if not pub_key_pem then
    ngx.say("Failed to extract public key: ", err)
    return
end

-- 输出私钥和公钥
ngx.say("Private Key (PEM):\n", priv_key_pem)
ngx.say("Public Key (PEM):\n", pub_key_pem)