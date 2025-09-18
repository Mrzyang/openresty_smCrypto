-- 国密算法工具模块
local resty_sm2 = require "resty.sm2"
local resty_digest = require "resty.digest"
local resty_sm4 = require "resty.sm4"
local resty_crypto = require "resty.crypto"
local cjson = require "cjson"

local _M = {}

-- 十六进制字符串转二进制数据
local function from_hex(hex)
    if not hex or type(hex) ~= "string" then
        return nil
    end
    
    -- 确保十六进制字符串长度为偶数
    if #hex % 2 ~= 0 then
        return nil
    end
    
    -- 检查是否只包含十六进制字符
    if not hex:match("^[%x]+$") then
        return nil
    end
    
    local result = {}
    for i = 1, #hex, 2 do
        local byte = tonumber(hex:sub(i, i+1), 16)
        if not byte then
            return nil
        end
        table.insert(result, string.char(byte))
    end
    
    return table.concat(result)
end

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
    local hasher, err = resty_digest.new("sm3")
    if not hasher then
        return nil, "Failed to create SM3 hasher: " .. (err or "unknown error")
    end
    return hasher:final(data)
end

-- SM2签名
function _M.sm2_sign(data, private_key)
    -- 使用lua-resty-crypto模块进行SM2签名
    ngx.log(ngx.DEBUG, "SM2签名 - 私钥长度: ", #(private_key or ""))
    ngx.log(ngx.DEBUG, "SM2签名 - 私钥内容: ", private_key)
    
    -- 根据密钥内容判断格式
    local is_pem_format = private_key:find("BEGIN PRIVATE KEY", 1, true) ~= nil
    
    ngx.log(ngx.DEBUG, "SM2签名 - 是否为PEM格式: ", is_pem_format)
    
    -- 根据项目规范，必须显式传递第二个参数指定密钥格式
    local sm2, err
    if is_pem_format then
        sm2, err = resty_sm2.new({
            private_key = private_key,
            algorithm = "sm3",  -- 明确指定使用SM3算法
            id = "default sm2 ID"
        }, true) -- PEM格式需要传递true
        ngx.log(ngx.DEBUG, "SM2签名 - 使用PEM格式创建实例")
    else
        sm2, err = resty_sm2.new({
            private_key = private_key,
            algorithm = "sm3",  -- 明确指定使用SM3算法
            id = "default sm2 ID"
        }, false) -- 十六进制格式需要传递false
        ngx.log(ngx.DEBUG, "SM2签名 - 使用十六进制格式创建实例")
    end
    
    if not sm2 then
        ngx.log(ngx.ERR, "创建SM2签名实例失败: ", err)
        return nil, "Failed to create SM2 signer: " .. (err or "unknown error")
    end

    local signature, err = sm2:sign(data)
    if not signature then
        ngx.log(ngx.ERR, "签名数据失败: ", err)
        return nil, "Failed to sign data: " .. (err or "unknown error")
    end

    -- 返回十六进制格式的签名，与Node.js客户端保持一致
    local resty_str = require "resty.utils.string"
    return resty_str.tohex(signature)
end

-- SM2验签
function _M.sm2_verify(data, signature, public_key)
    -- 使用lua-resty-crypto模块进行SM2验签
    ngx.log(ngx.DEBUG, "SM2验签 - 公钥长度: ", #(public_key or ""))
    ngx.log(ngx.DEBUG, "SM2验签 - 公钥内容: ", public_key)
    
    -- 根据密钥内容判断格式
    local is_pem_format = public_key:find("BEGIN PUBLIC KEY", 1, true) ~= nil
    
    ngx.log(ngx.DEBUG, "SM2验签 - 是否为PEM格式: ", is_pem_format)
    
    -- 根据项目规范，必须显式传递第二个参数指定密钥格式
    local sm2, err
    if is_pem_format then
        sm2, err = resty_sm2.new({
            public_key = public_key,
            algorithm = "sm3",  -- 明确指定使用SM3算法
            id = "default sm2 ID"
        }, true) -- PEM格式需要传递true
        ngx.log(ngx.DEBUG, "SM2验签 - 使用PEM格式创建实例")
    else
        sm2, err = resty_sm2.new({
            public_key = public_key,
            algorithm = "sm3",  -- 明确指定使用SM3算法
            id = "default sm2 ID"
        }, false) -- 十六进制格式需要传递false
        ngx.log(ngx.DEBUG, "SM2验签 - 使用十六进制格式创建实例")
    end
    
    if not sm2 then
        ngx.log(ngx.ERR, "创建SM2验证实例失败: ", err)
        return false, "Failed to create SM2 verifier: " .. (err or "unknown error")
    end

    -- 根据签名的格式进行相应的解码
    -- 如果签名是十六进制格式（不包含非十六进制字符），则使用from_hex解码
    -- 否则使用base64解码
    local sig_bytes
    if signature:match("^[%x]+$") then  -- 纯十六进制字符串
        sig_bytes = from_hex(signature)
        ngx.log(ngx.DEBUG, "使用十六进制解码签名")
    else
        sig_bytes = ngx.decode_base64(signature)
        ngx.log(ngx.DEBUG, "使用base64解码签名")
    end
    
    if not sig_bytes then
        ngx.log(ngx.ERR, "解码签名失败")
        return false, "Failed to decode signature"
    end

    ngx.log(ngx.ERR, "hex类型签名值:", signature)
    ngx.log(ngx.ERR, "请求报文体:", data)
    local is_valid, err = sm2:verify(data, sig_bytes)
    if not is_valid then
        ngx.log(ngx.ERR, "签名验证失败: ", err)
        return false, "Signature verification failed: " .. (err or "unknown error")
    end

    return true
end

-- SM4加密
function _M.sm4_encrypt(plaintext, key, iv)
    -- 确保密钥和IV都是16字节长度
    local fixed_key, err = ensure_16_bytes(key)
    if not fixed_key then
        return nil, "Failed to fix key: " .. (err or "unknown error")
    end
    
    local fixed_iv, err = ensure_16_bytes(iv)
    if not fixed_iv then
        return nil, "Failed to fix IV: " .. (err or "unknown error")
    end

    -- 修复：将salt设置为nil，直接使用IV
    local crypto, err = resty_crypto.new(fixed_key, nil, resty_sm4.cipher("cbc"))
    if not crypto then
        return nil, "Failed to create SM4 crypto: " .. (err or "unknown error")
    end

    local encrypted, err = crypto:encrypt(plaintext)
    if not encrypted then
        return nil, "Failed to encrypt data: " .. (err or "unknown error")
    end

    return ngx.encode_base64(encrypted)
end

-- SM4解密
function _M.sm4_decrypt(ciphertext, key, iv)
    ngx.log(ngx.DEBUG, "开始SM4解密, 密文长度: ", #ciphertext, ", 密文内容: ", ciphertext)
    ngx.log(ngx.DEBUG, "密钥: ", key, ", IV: ", iv)
    
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

    -- 修复：将salt设置为nil，直接使用IV
    local crypto, err = resty_crypto.new(fixed_key, nil, resty_sm4.cipher("cbc"))
    if not crypto then
        ngx.log(ngx.ERR, "创建SM4 crypto失败: ", err)
        return nil, "Failed to create SM4 crypto: " .. (err or "unknown error")
    end

    -- 解码base64密文，直接得到二进制数据
    local cipher_bytes = ngx.decode_base64(ciphertext)
    if not cipher_bytes then
        ngx.log(ngx.ERR, "Base64解码失败, 密文: ", ciphertext)
        return nil, "Failed to decode ciphertext from base64"
    end
    ngx.log(ngx.DEBUG, "Base64解码成功, 解码后长度: ", #cipher_bytes)

    local decrypted, err = crypto:decrypt(cipher_bytes)
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