-- 测试OpenResty兼容的PEM格式
local pkey = require "resty.openssl.pkey"
local digest = require "resty.openssl.digest"

ngx.header.content_type = "text/plain; charset=utf-8"

-- 测试用的OpenResty兼容PEM格式密钥（从Node.js生成的标准格式）
local test_pub_key_pem = [[
-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoEcz1UBgi0DQgAE
PZntvBVUHGbEhGUyHOCywu
kLV0x/MF3T0gMhETrx30s5JqbAn/CIkW/whnc3WQonr9O5iMPulnEPLK
49kMEv9o
-----END PUBLIC KEY-----
]]

local test_priv_key_pem = [[
-----BEGIN PRIVATE KEY-----
MIGEAgEAMBAGByqGSM49AgEGBSuBBAAjBIHWMIHTAgEBBEAD01RZh
eVDrEODiJ2OIQeanSr2OvxhXINid2l6irW1nEoACyGXTfYQBkIA
zZn
tvBVUHGbEhGUyHOCywu
kLV0x/MF3T0gMhETrx30s5JqbAn/CIkW/whnc3WQonr9O5iMPulnEPLK
49kMEv9o
QDQgAE
PZntvBVUHGbEhGUyHOCywu
kLV0x/MF3T0gMhETrx30s5JqbAn/CIkW/whnc3WQonr9O5iMPulnEPLK
49kMEv9o
-----END PRIVATE KEY-----
]]

ngx.say("测试OpenResty兼容的PEM格式密钥")
ngx.say("================================")

-- 测试公钥加载
ngx.say("\n1. 测试公钥加载:")
ngx.say(test_pub_key_pem)

local pub_key, err = pkey.new(test_pub_key_pem, {
    format = "PEM",
    type = "pu"
})

if not pub_key then
    ngx.say("公钥加载失败: ", err)
    return
end

ngx.say("公钥加载成功!")

-- 测试私钥加载
ngx.say("\n2. 测试私钥加载:")
ngx.say(test_priv_key_pem)

local priv_key, err = pkey.new(test_priv_key_pem, {
    type = "pr",
    format = "PEM"
})

if not priv_key then
    ngx.say("私钥加载失败: ", err)
    return
end

ngx.say("私钥加载成功!")

-- 测试签名和验签
ngx.say("\n3. 测试签名和验签:")

local test_data = "Hello, SM2 from OpenResty!"
ngx.say("测试数据: ", test_data)

-- 使用私钥签名
local sig, err = priv_key:sign(test_data, "sm3")
if not sig then
    ngx.say("签名失败: ", err)
    return
end

ngx.say("签名成功，签名长度: ", #sig)

-- 使用公钥验签
local is_valid, err = pub_key:verify(sig, test_data, "sm3")
if not is_valid then
    ngx.say("验签失败: ", err)
    return
end

ngx.say("验签成功!")

-- 测试SM3哈希
ngx.say("\n4. 测试SM3哈希:")

local hasher = digest.new("sm3")
if not hasher then
    ngx.say("创建SM3哈希器失败")
else
    local hash_result = hasher:final(test_data)
    if not hash_result then
        ngx.say("SM3哈希计算失败")
    else
        ngx.say("SM3哈希计算成功，结果长度: ", #hash_result)
        ngx.say("哈希值(HEX): ", ngx.encode_base64(hash_result))
    end
end

ngx.say("\n所有测试完成!")