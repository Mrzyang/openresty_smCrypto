-- 测试新生成的PEM格式密钥
local pkey = require "resty.openssl.pkey"

ngx.header.content_type = "text/plain; charset=utf-8"

-- 新生成的PEM格式密钥（从Node.js测试脚本中复制）
local new_pub_key_pem = [[
-----BEGIN PUBLIC KEY-----
MFIwDQYHKoEcz1UBgi0FAANCAARqmxVBnUBBMAY4miWgB0Nt9jGtf7bHRYwcDkrX
gbRp0pqe7uQnpIrVM8wW5GTfgah6qciLgY4+D/ers3LOPx6t
-----END PUBLIC KEY-----
]]

local new_priv_key_pem = [[
-----BEGIN PRIVATE KEY-----
MEMCAQAwDQYHKoEcz1UBgi0FAAQwMA0GByqBHM9VAYItBQAEII1g4jR1NyMXHHS9
VHnW5XFzY2HKfX3G4GRpX2zt+LWb
-----END PRIVATE KEY-----
]]

ngx.say("测试新生成的PEM格式密钥")
ngx.say("================================")

-- 测试公钥加载
ngx.say("\n1. 测试新公钥加载:")
ngx.say(new_pub_key_pem)

local pub_key, err = pkey.new(new_pub_key_pem, {
    format = "PEM",
    type = "pu"
})

if not pub_key then
    ngx.say("新公钥加载失败: ", err)
    return
end

ngx.say("新公钥加载成功!")

-- 测试私钥加载
ngx.say("\n2. 测试新私钥加载:")
ngx.say(new_priv_key_pem)

local priv_key, err = pkey.new(new_priv_key_pem, {
    type = "pr",
    format = "PEM"
})

if not priv_key then
    ngx.say("新私钥加载失败: ", err)
    return
end

ngx.say("新私钥加载成功!")

-- 测试签名和验签
ngx.say("\n3. 测试签名和验签:")

local test_data = "Hello, SM2 from new format!"
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

-- 测试交叉验证（使用OpenResty生成的密钥验证Node.js生成的签名）
ngx.say("\n4. 测试交叉验证:")

-- 这里可以添加更多测试...

ngx.say("\n所有测试完成!")