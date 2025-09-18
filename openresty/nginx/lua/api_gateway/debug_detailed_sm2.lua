-- 详细调试SM2算法实现
local resty_sm2 = require "resty.sm2"

local _M = {}

function _M.debug_detailed_sm2()
    -- 测试1: 使用generate_key生成的密钥对（十六进制格式）
    ngx.say("=== 测试1: 使用generate_key生成的密钥对（十六进制格式） ===")
    local pubkey, prvkey = resty_sm2.generate_key()
    ngx.say("公钥: ", pubkey)
    ngx.say("私钥: ", prvkey)
    ngx.say("公钥长度: ", #pubkey)
    ngx.say("私钥长度: ", #prvkey)
    
    local data = "Hello, SM2 test!"
    
    -- 测试直接使用resty_sm2模块
    ngx.say("\n--- 直接使用resty_sm2模块 ---")
    local success, sm2_sign, err = pcall(function()
        return resty_sm2.new({
            private_key = prvkey,
            public_key = pubkey,
            algorithm = "sm3",
            id = "default sm2 ID"
        })
    end)
    
    if not success then
        ngx.say("创建签名实例时发生异常: ", err)
        return
    end
    
    if not sm2_sign then
        ngx.say("创建签名实例失败: ", err)
    else
        ngx.say("成功创建签名实例")
        
        local success, signature, err = pcall(function()
            return sm2_sign:sign(data)
        end)
        
        if not success then
            ngx.say("签名时发生异常: ", err)
            return
        end
        
        if not signature then
            ngx.say("签名失败: ", err)
        else
            ngx.say("签名成功，签名长度: ", #signature)
            
            local success, sm2_verify, err = pcall(function()
                return resty_sm2.new({
                    public_key = pubkey,
                    algorithm = "sm3",
                    id = "default sm2 ID"
                })
            end)
            
            if not success then
                ngx.say("创建验签实例时发生异常: ", err)
                return
            end
            
            if not sm2_verify then
                ngx.say("创建验签实例失败: ", err)
            else
                ngx.say("成功创建验签实例")
                
                local success, is_valid, err = pcall(function()
                    return sm2_verify:verify(data, signature)
                end)
                
                if not success then
                    ngx.say("验签时发生异常: ", err)
                    return
                end
                
                if not is_valid then
                    ngx.say("验签失败: ", err)
                else
                    ngx.say("验签成功")
                end
            end
        end
    end
    
    -- 测试2: 使用测试用的十六进制密钥
    ngx.say("\n=== 测试2: 使用测试用的十六进制密钥 ===")
    local test_private_key = "F136AE410D9C901E4A2F781C25D3728D0EFF4F8A7EB9C7F0D20D4A6E40D030D9"
    local test_public_key = "04980F68A41C01A19414545E11251D38CA0BE16A7DF9C24F69E2B8FCDC7639F9A632EEAA18762A87DA12CE050922C6F634CAECC3C4D76A2D0E052E9B7D9B6E9471"
    
    ngx.say("测试私钥: ", test_private_key)
    ngx.say("测试公钥: ", test_public_key)
    ngx.say("测试私钥长度: ", #test_private_key)
    ngx.say("测试公钥长度: ", #test_public_key)
    
    local success, sm2_sign2, err = pcall(function()
        return resty_sm2.new({
            private_key = test_private_key,
            public_key = test_public_key,
            algorithm = "sm3",
            id = "default sm2 ID"
        })
    end)
    
    if not success then
        ngx.say("创建测试签名实例时发生异常: ", err)
        return
    end
    
    if not sm2_sign2 then
        ngx.say("创建测试签名实例失败: ", err)
    else
        ngx.say("成功创建测试签名实例")
        
        local success, signature2, err = pcall(function()
            return sm2_sign2:sign(data)
        end)
        
        if not success then
            ngx.say("测试签名时发生异常: ", err)
            return
        end
        
        if not signature2 then
            ngx.say("测试签名失败: ", err)
        else
            ngx.say("测试签名成功，签名长度: ", #signature2)
        end
    end
end

return _M