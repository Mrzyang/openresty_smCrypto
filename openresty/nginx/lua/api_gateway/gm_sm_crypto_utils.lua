-- 基于gmCryptor-go.so的国密算法工具模块
local gmCryptor = require "gmCryptor-go"
local cjson = require "cjson"

local _M = {}

-- 将base64解码后的字符串并转换成十六进制字符串
local function decode_base64_to_hex_str(base64_str)
    local decoded = ngx.decode_base64(base64_str)
    if not decoded then
        ngx.log(ngx.ERR, "Base64解码失败")
        return nil
    end
    local t = {}
    for i = 1, #decoded do
        t[#t+1] = string.format("%02X", string.byte(decoded, i))
    end
    return table.concat(t, "")
end

-- SM3哈希计算
function _M.sm3_hash(data)
    return gmCryptor.sm3Hash(data)
end

-- SM2签名
function _M.sm2_sign(data, private_key)
    local signature = gmCryptor.sm2Signature(data, private_key)
    return signature
end

-- SM2验签
function _M.sm2_verify(data, signature, public_key)
    local result = gmCryptor.sm2VerifySign(data, signature, public_key)
    return result
end

-- SM4 CBC模式加密
function _M.sm4_cbc_encrypt(plaintext, key, iv)
    local encrypted = gmCryptor.sm4CbcEncrypt(plaintext, key, iv)
    
    if encrypted then
        return ngx.encode_base64(encrypted)
    end
    return nil
end

-- SM4 CBC模式解密
function _M.sm4_cbc_decrypt(ciphertext, key, iv)
    local decoded = decode_base64_to_hex_str(ciphertext)
    if not decoded then
        ngx.log(ngx.ERR, "Base64解码失败")
        return nil
    end
    
    local decrypted = gmCryptor.sm4CbcDecrypt(decoded, key, iv)
    return decrypted
end

-- 生成签名数据
function _M.build_signature_data(method, uri, query_string, body, nonce, timestamp)
    local data_parts = {
        method or "",
        uri or "",
        query_string or "",
        body or "",
        nonce or "",
        tostring(timestamp or 0)
    }
    return table.concat(data_parts, "&")
end

-- 验证时间戳是否在有效范围内
function _M.validate_timestamp(timestamp, window_seconds)
    local current_time = ngx.time()
    local time_diff = math.abs(current_time - timestamp)
    return time_diff <= (window_seconds or 300) -- 默认5分钟
end

-- 生成随机nonce
function _M.generate_nonce()
    local random = math.random(1000000000, 9999999999)
    return tostring(random) .. tostring(ngx.time())
end

-- 验证nonce格式
function _M.validate_nonce_format(nonce)
    if not nonce or type(nonce) ~= "string" then
        return false
    end
    -- nonce应该是数字字符串，长度在10-20之间
    return string.match(nonce, "^%d+$") and #nonce >= 10 and #nonce <= 20
end

return _M