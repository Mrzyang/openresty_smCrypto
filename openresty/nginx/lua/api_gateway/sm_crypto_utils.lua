-- 国密算法工具模块
local pkey = require "resty.openssl.pkey"
local digest = require "resty.openssl.digest"
local cipher = require "resty.openssl.cipher"
local cjson = require "cjson"

local _M = {}

-- SM3哈希计算
function _M.sm3_hash(data)
    local hasher = digest.new("sm3")
    if not hasher then
        return nil, "Failed to create SM3 hasher"
    end
    return hasher:final(data)
end

-- SM2签名
function _M.sm2_sign(data, private_key_pem)
    local priv_key, err = pkey.new(private_key_pem, {
        type = "pr",
        format = "PEM"
    })
    if not priv_key then
        return nil, "Failed to load private key: " .. (err or "unknown error")
    end

    local signature, err = priv_key:sign(data, "sm3")
    if not signature then
        return nil, "Failed to sign data: " .. (err or "unknown error")
    end

    return ngx.encode_base64(signature)
end

-- SM2验签
function _M.sm2_verify(data, signature, public_key_pem)
    local pub_key, err = pkey.new(public_key_pem, {
        format = "PEM",
        type = "pu"
    })
    if not pub_key then
        return false, "Failed to load public key: " .. (err or "unknown error")
    end

    local sig_bytes = ngx.decode_base64(signature)
    if not sig_bytes then
        return false, "Failed to decode signature"
    end

    local is_valid, err = pub_key:verify(sig_bytes, data, "sm3")
    if not is_valid then
        return false, "Signature verification failed: " .. (err or "unknown error")
    end

    return true
end

-- SM4加密
function _M.sm4_encrypt(plaintext, key, iv)
    local mode = "sm4-cbc"
    local cipher_obj = cipher.new(mode)
    if not cipher_obj then
        return nil, "Failed to create SM4 cipher"
    end

    local encrypted = cipher_obj:encrypt(key, iv, plaintext, false)
    if not encrypted then
        return nil, "Failed to encrypt data"
    end

    return ngx.encode_base64(encrypted)
end

-- SM4解密
function _M.sm4_decrypt(ciphertext, key, iv)
    local mode = "sm4-cbc"
    local cipher_obj = cipher.new(mode)
    if not cipher_obj then
        return nil, "Failed to create SM4 cipher"
    end

    local cipher_bytes = ngx.decode_base64(ciphertext)
    if not cipher_bytes then
        return nil, "Failed to decode ciphertext"
    end

    local decrypted = cipher_obj:decrypt(key, iv, cipher_bytes, false)
    if not decrypted then
        return nil, "Failed to decrypt data"
    end

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
