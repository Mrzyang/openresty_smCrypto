-- 测试SM2算法使用lua-resty-crypto模块
local sm_crypto = require "api_gateway.sm_crypto_utils"
local resty_sm2 = require "resty.sm2"

local _M = {}

function _M.test_sm2()
    -- 测试1: 使用generate_key生成的密钥对（十六进制格式）
    ngx.say("=== 测试1: 使用generate_key生成的密钥对（十六进制格式） ===")
    local pubkey, prvkey = resty_sm2.generate_key()
    
    local test_data = "Hello, SM2 test!"

    -- 测试SM2签名
    local signature, err = sm_crypto.sm2_sign(test_data, prvkey)
    if not signature then
        ngx.say("SM2签名失败: ", err)
        return
    end
    ngx.say("SM2签名成功: ", signature)

    -- 测试SM2验签
    local is_valid, err = sm_crypto.sm2_verify(test_data, signature, pubkey)
    if not is_valid then
        ngx.say("SM2验签失败: ", err)
        return
    end
    ngx.say("SM2验签成功")

    -- 测试2: 使用generate_eckey生成的密钥对（PEM格式）
    ngx.say("\n=== 测试2: 使用generate_eckey生成的密钥对（PEM格式） ===")
    local pubkey_pem, prvkey_pem = resty_sm2.generate_eckey()
    
    -- 测试SM2签名
    local signature_pem, err_pem = sm_crypto.sm2_sign(test_data, prvkey_pem)
    if not signature_pem then
        ngx.say("SM2签名失败: ", err_pem)
        return
    end
    ngx.say("SM2签名成功: ", signature_pem)

    -- 测试SM2验签
    local is_valid_pem, err_pem = sm_crypto.sm2_verify(test_data, signature_pem, pubkey_pem)
    if not is_valid_pem then
        ngx.say("SM2验签失败: ", err_pem)
        return
    end
    ngx.say("SM2验签成功")

    -- 测试3: 使用十六进制格式的密钥（模拟Redis中的数据格式）
    ngx.say("\n=== 测试3: 使用十六进制格式的密钥 ===")
    local test_private_key = "F136AE410D9C901E4A2F781C25D3728D0EFF4F8A7EB9C7F0D20D4A6E40D030D9"
    local test_public_key = "04980F68A41C01A19414545E11251D38CA0BE16A7DF9C24F69E2B8FCDC7639F9A632EEAA18762A87DA12CE050922C6F634CAECC3C4D76A2D0E052E9B7D9B6E9471"

    -- 测试SM2签名
    local signature2, err2 = sm_crypto.sm2_sign(test_data, test_private_key)
    if not signature2 then
        ngx.say("SM2签名失败: ", err2)
        return
    end
    ngx.say("SM2签名成功: ", signature2)

    -- 测试SM2验签
    local is_valid2, err2 = sm_crypto.sm2_verify(test_data, signature2, test_public_key)
    if not is_valid2 then
        ngx.say("SM2验签失败: ", err2)
        return
    end
    ngx.say("SM2验签成功")

    -- 测试SM3哈希
    ngx.say("\n=== 测试SM3哈希 ===")
    local hash, err = sm_crypto.sm3_hash(test_data)
    if not hash then
        ngx.say("SM3哈希计算失败: ", err)
        return
    end
    ngx.say("SM3哈希计算成功: ", ngx.encode_base64(hash))

    -- 测试SM4加密和解密
    ngx.say("\n=== 测试SM4加密和解密 ===")
    local key = "1234567890123456"
    local iv = "1234567890123456"
    local plaintext = "Hello, SM4 test!"

    local encrypted, err = sm_crypto.sm4_encrypt(plaintext, key, iv)
    if not encrypted then
        ngx.say("SM4加密失败: ", err)
        return
    end
    ngx.say("SM4加密成功: ", encrypted)

    local decrypted, err = sm_crypto.sm4_decrypt(encrypted, key, iv)
    if not decrypted then
        ngx.say("SM4解密失败: ", err)
        return
    end
    ngx.say("SM4解密成功: ", decrypted)
end

return _M