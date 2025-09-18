-- 调试SM2算法实现
local resty_sm2 = require "resty.sm2"

local _M = {}

function _M.debug_sm2()
    -- 测试1: 使用generate_key生成的密钥对（十六进制格式）
    ngx.say("=== 测试1: 使用generate_key生成的密钥对（十六进制格式） ===")
    local pubkey, prvkey = resty_sm2.generate_key()
    ngx.say("公钥: ", pubkey)
    ngx.say("私钥: ", prvkey)
    
    local data = "Hello, SM2 test!"
    
    -- 直接使用resty_sm2模块进行签名和验签
    ngx.say("\n--- 直接使用resty_sm2模块 ---")
    local sm2_sign, err = resty_sm2.new({
        private_key = prvkey,
        public_key = pubkey,
        algorithm = "sm3",
        id = "default sm2 ID"
    }) -- 不传递第二个参数
    
    if not sm2_sign then
        ngx.say("创建签名实例失败: ", err)
    else
        local signature, err = sm2_sign:sign(data)
        if not signature then
            ngx.say("签名失败: ", err)
        else
            ngx.say("签名成功")
            
            local sm2_verify, err = resty_sm2.new({
                public_key = pubkey,
                algorithm = "sm3",
                id = "default sm2 ID"
            }) -- 不传递第二个参数
            
            if not sm2_verify then
                ngx.say("创建验签实例失败: ", err)
            else
                local is_valid, err = sm2_verify:verify(data, signature)
                if not is_valid then
                    ngx.say("验签失败: ", err)
                else
                    ngx.say("验签成功")
                end
            end
        end
    end
    
    -- 测试2: 使用generate_eckey生成的密钥对（PEM格式）
    ngx.say("\n=== 测试2: 使用generate_eckey生成的密钥对（PEM格式） ===")
    local pubkey_pem, prvkey_pem = resty_sm2.generate_eckey()
    ngx.say("PEM公钥: ", pubkey_pem)
    ngx.say("PEM私钥: ", prvkey_pem)
    
    -- 直接使用resty_sm2模块进行签名和验签
    ngx.say("\n--- 直接使用resty_sm2模块 ---")
    local sm2_sign_pem, err = resty_sm2.new({
        private_key = prvkey_pem,
        public_key = pubkey_pem,
        algorithm = "sm3",
        id = "default sm2 ID"
    }, true) -- 传递true作为第二个参数
    
    if not sm2_sign_pem then
        ngx.say("创建PEM签名实例失败: ", err)
    else
        local signature, err = sm2_sign_pem:sign(data)
        if not signature then
            ngx.say("PEM签名失败: ", err)
        else
            ngx.say("PEM签名成功")
            
            local sm2_verify_pem, err = resty_sm2.new({
                public_key = pubkey_pem,
                algorithm = "sm3",
                id = "default sm2 ID"
            }, true) -- 传递true作为第二个参数
            
            if not sm2_verify_pem then
                ngx.say("创建PEM验签实例失败: ", err)
            else
                local is_valid, err = sm2_verify_pem:verify(data, signature)
                if not is_valid then
                    ngx.say("PEM验签失败: ", err)
                else
                    ngx.say("PEM验签成功")
                end
            end
        end
    end
end

return _M