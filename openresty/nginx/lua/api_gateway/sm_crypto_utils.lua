-- 国密算法工具模块
local pkey = require "resty.openssl.pkey"
local digest = require "resty.openssl.digest"
local cipher = require "resty.openssl.cipher"
local cjson = require "cjson"

local _M = {}

-- 确保字符串是16字节长度
local function ensure_16_bytes(str)
    if type(str) ~= "string" then
        return nil, "Invalid input type"
    end
    
    if #str == 16 then
        return str
    elseif #str > 16 then
        return string.sub(str, 1, 16)
    else
        return str .. string.rep("\0", 16 - #str)
    end
end

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
    local cipher_obj, err = cipher.new(mode)
    if not cipher_obj then
        return nil, "Failed to create SM4 cipher: " .. (err or "unknown error")
    end

    -- 确保密钥和IV都是16字节长度
    local fixed_key, err = ensure_16_bytes(key)
    if not fixed_key then
        return nil, "Failed to fix key: " .. (err or "unknown error")
    end
    
    local fixed_iv, err = ensure_16_bytes(iv)
    if not fixed_iv then
        return nil, "Failed to fix IV: " .. (err or "unknown error")
    end

    -- 使用cipher:encrypt方法，参考示例代码的模式
    local encrypted, err = cipher_obj:encrypt(fixed_key, fixed_iv, plaintext, false)
    if not encrypted then
        return nil, "Failed to encrypt data: " .. (err or "unknown error")
    end

    -- 直接对二进制数据进行base64编码，与sm4.lua保持一致
    return ngx.encode_base64(encrypted)
end

-- SM4解密
function _M.sm4_decrypt(ciphertext, key, iv)
    ngx.log(ngx.DEBUG, "开始SM4解密, 密文长度: ", #ciphertext, ", 密文内容: ", ciphertext)
    ngx.log(ngx.DEBUG, "密钥: ", key, ", IV: ", iv)
    
    local mode = "sm4-cbc"
    local cipher_obj, err = cipher.new(mode)
    if not cipher_obj then
        ngx.log(ngx.ERR, "创建SM4 cipher失败: ", err)
        return nil, "Failed to create SM4 cipher: " .. (err or "unknown error")
    end

    -- 解码base64密文，直接得到二进制数据
    local cipher_bytes = ngx.decode_base64(ciphertext)
    if not cipher_bytes then
        ngx.log(ngx.ERR, "Base64解码失败, 密文: ", ciphertext)
        return nil, "Failed to decode ciphertext from base64"
    end
    ngx.log(ngx.DEBUG, "Base64解码成功, 解码后长度: ", #cipher_bytes)

    -- 确保密钥和IV都是16字节长度
    local fixed_key, err = ensure_16_bytes(key)
    if not fixed_key then
        ngx.log(ngx.ERR, "密钥处理失败: ", err)
        return nil, "Failed to fix key: " .. (err or "unknown error")
    end
    
    local fixed_iv, err = ensure_16_bytes(iv)
    if not fixed_iv then
        ngx.log(ngx.ERR, "IV处理失败: ", err)
        return nil, "Failed to fix IV: " .. (err or "unknown error")
    end
    
    ngx.log(ngx.DEBUG, "处理后密钥长度: ", #fixed_key, ", IV长度: ", #fixed_iv)

    -- 使用cipher:decrypt方法，参考示例代码的模式
    local decrypted, err = cipher_obj:decrypt(fixed_key, fixed_iv, cipher_bytes, false)
    if not decrypted then
        ngx.log(ngx.ERR, "解密失败: ", err)
        return nil, "Failed to decrypt data: " .. (err or "unknown error")
    end

    ngx.log(ngx.DEBUG, "解密成功, 结果: ", decrypted)
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