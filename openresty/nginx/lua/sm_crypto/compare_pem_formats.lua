-- 比较不同PEM格式的兼容性
local pkey = require "resty.openssl.pkey"

ngx.header.content_type = "text/plain; charset=utf-8"

-- Node.js生成的PEM格式密钥（从之前的测试中获取）
local nodejs_pub_key_pem = [[
-----BEGIN PUBLIC KEY-----
MFIwDQYHKoEcz1UBgi0FAANCAAQhiQqIVV7JoXFODU6J6BQm3FUPIC9H5AyAytFL
+ut1m8S/SqE93+LmQxgI/aWcgE+4Fk12u4zATpFixDNQikGH
-----END PUBLIC KEY-----
]]

local nodejs_priv_key_pem = [[
-----BEGIN PRIVATE KEY-----
MIGHAgEAMBMGByqGSM49AgEGCCqBHM9VAYItBG0wawIBAQQg8HLOQ9PlccsWBgNp
ForNIOvr0pFRp7jzUrNj78RbIuahRANCAASeMvuRVyaRFFkFCkrTHEo2xqKvIzp3
sfJjNNf5jyB7m9EVuiz0RpQqNfEk2PP1EpC40stZ351d6cYida6BGT7u
-----END PRIVATE KEY-----
]]

-- OpenResty生成的PEM格式密钥（从之前的测试中获取）
local openresty_pub_key_pem = [[
-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoEcz1UBgi0DQgAEXttp21VS51fvlJ3qUiPux2ab0RaG
zWZQWomlJOVdzkV3cu7dELUX9aCk3aQGcrLzSyuVZ8P0vb/igO+Jy9uGzQ==
-----END PUBLIC KEY-----
]]

local openresty_priv_key_pem = [[
-----BEGIN PRIVATE KEY-----
MIGHAgEAMBMGByqGSM49AgEGCCqBHM9VAYItBG0wawIBAQQgxz4kIT7pMGBoytm9
GzPk1nooOqOwjdSeD4WgGHaFCUehRANCAARe22nbVVLnV++UnepSI+7HZpvRFobN
ZlBaiaUk5V3ORXdy7t0QtRf1oKTdpAZysvNLK5Vnw/S9v+KA74nL24bN
-----END PRIVATE KEY-----
]]

ngx.say("比较不同PEM格式的兼容性")
ngx.say("================================")

-- 测试Node.js生成的公钥
ngx.say("\n1. 测试Node.js生成的公钥:")
ngx.say(nodejs_pub_key_pem)

local nodejs_pub_key, err = pkey.new(nodejs_pub_key_pem, {
    format = "PEM",
    type = "pu"
})

if not nodejs_pub_key then
    ngx.say("Node.js公钥加载失败: ", err)
else
    ngx.say("Node.js公钥加载成功!")
end

-- 测试Node.js生成的私钥
ngx.say("\n2. 测试Node.js生成的私钥:")
ngx.say(nodejs_priv_key_pem)

local nodejs_priv_key, err = pkey.new(nodejs_priv_key_pem, {
    type = "pr",
    format = "PEM"
})

if not nodejs_priv_key then
    ngx.say("Node.js私钥加载失败: ", err)
else
    ngx.say("Node.js私钥加载成功!")
end

-- 测试OpenResty生成的公钥
ngx.say("\n3. 测试OpenResty生成的公钥:")
ngx.say(openresty_pub_key_pem)

local openresty_pub_key, err = pkey.new(openresty_pub_key_pem, {
    format = "PEM",
    type = "pu"
})

if not openresty_pub_key then
    ngx.say("OpenResty公钥加载失败: ", err)
else
    ngx.say("OpenResty公钥加载成功!")
end

-- 测试OpenResty生成的私钥
ngx.say("\n4. 测试OpenResty生成的私钥:")
ngx.say(openresty_priv_key_pem)

local openresty_priv_key, err = pkey.new(openresty_priv_key_pem, {
    type = "pr",
    format = "PEM"
})

if not openresty_priv_key then
    ngx.say("OpenResty私钥加载失败: ", err)
else
    ngx.say("OpenResty私钥加载成功!")
end

-- 尝试交叉验证签名和验签
ngx.say("\n5. 交叉验证签名和验签:")

if nodejs_priv_key and openresty_pub_key then
    local test_data = "Cross validation test"
    local sig, err = nodejs_priv_key:sign(test_data, "sm3")
    if sig then
        local is_valid, err = openresty_pub_key:verify(sig, test_data, "sm3")
        if is_valid then
            ngx.say("Node.js签名 + OpenResty验签: 成功")
        else
            ngx.say("Node.js签名 + OpenResty验签: 失败 - ", err)
        end
    else
        ngx.say("Node.js签名失败: ", err)
    end
end

if openresty_priv_key and nodejs_pub_key then
    local test_data = "Cross validation test"
    local sig, err = openresty_priv_key:sign(test_data, "sm3")
    if sig then
        local is_valid, err = nodejs_pub_key:verify(sig, test_data, "sm3")
        if is_valid then
            ngx.say("OpenResty签名 + Node.js验签: 成功")
        else
            ngx.say("OpenResty签名 + Node.js验签: 失败 - ", err)
        end
    else
        ngx.say("OpenResty签名失败: ", err)
    end
end

ngx.say("\n测试完成!")