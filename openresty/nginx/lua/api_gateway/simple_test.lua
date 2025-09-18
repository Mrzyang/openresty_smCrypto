-- 简单的SM2测试文件
local resty_sm2 = require "resty.sm2"

-- 测试十六进制格式密钥
ngx.say("=== 测试十六进制格式密钥 ===")
local pubkey_hex, prvkey_hex = resty_sm2.generate_key()
ngx.say("十六进制公钥: ", pubkey_hex)
ngx.say("十六进制私钥: ", prvkey_hex)

-- 使用十六进制格式密钥进行签名和验签（不传递第二个参数）
local sm2_sign_hex, err = resty_sm2.new({
    private_key = prvkey_hex,
    public_key = pubkey_hex,
    algorithm = "sm3",
    id = "default sm2 ID"
}) -- 不传递第二个参数

if not sm2_sign_hex then
    ngx.say("创建十六进制格式签名实例失败: ", err)
else
    local data = "test data for signing"
    local signature, err = sm2_sign_hex:sign(data)
    if not signature then
        ngx.say("十六进制格式签名失败: ", err)
    else
        ngx.say("十六进制格式签名成功")
        
        -- 验证签名
        local sm2_verify_hex, err = resty_sm2.new({
            public_key = pubkey_hex,
            algorithm = "sm3",
            id = "default sm2 ID"
        }) -- 不传递第二个参数
        
        if not sm2_verify_hex then
            ngx.say("创建十六进制格式验签实例失败: ", err)
        else
            local is_valid, err = sm2_verify_hex:verify(data, signature)
            if not is_valid then
                ngx.say("十六进制格式验签失败: ", err)
            else
                ngx.say("十六进制格式验签成功")
            end
        end
    end
end

ngx.say("")

-- 测试PEM格式密钥
ngx.say("=== 测试PEM格式密钥 ===")
local pubkey_pem, prvkey_pem = resty_sm2.generate_eckey()
ngx.say("PEM公钥: ", pubkey_pem)
ngx.say("PEM私钥: ", prvkey_pem)

-- 使用PEM格式密钥进行签名和验签（传递true作为第二个参数）
local sm2_sign_pem, err = resty_sm2.new({
    private_key = prvkey_pem,
    public_key = pubkey_pem,
    algorithm = "sm3",
    id = "default sm2 ID"
}, true) -- 传递true作为第二个参数

if not sm2_sign_pem then
    ngx.say("创建PEM格式签名实例失败: ", err)
else
    local data = "test data for signing"
    local signature, err = sm2_sign_pem:sign(data)
    if not signature then
        ngx.say("PEM格式签名失败: ", err)
    else
        ngx.say("PEM格式签名成功")
        
        -- 验证签名
        local sm2_verify_pem, err = resty_sm2.new({
            public_key = pubkey_pem,
            algorithm = "sm3",
            id = "default sm2 ID"
        }, true) -- 传递true作为第二个参数
        
        if not sm2_verify_pem then
            ngx.say("创建PEM格式验签实例失败: ", err)
        else
            local is_valid, err = sm2_verify_pem:verify(data, signature)
            if not is_valid then
                ngx.say("PEM格式验签失败: ", err)
            else
                ngx.say("PEM格式验签成功")
            end
        end
    end
end