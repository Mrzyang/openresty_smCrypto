-- hex_utils.lua
local M = {}

-- SM4 加密
function M.encrypt(data, sm4_key, sm4_iv, mode)
    local cipher = require("resty.openssl.cipher").new(mode)
    local encrypted_body = cipher:encrypt(sm4_key, sm4_iv, data, false)
    return ngx.encode_base64(encrypted_body) -- 转base64
end

-- SM2 签名，这里PEM格式的私钥，前面-----BEGIN PRIVATE KEY-----以及-----END PRIVATE KEY-----千万不能留空格和制表符，否则无法识别和加载
function M.sign(data, sm2_private_key_pem)
    local pkey = require "resty.openssl.pkey"

    local priv_key, err = pkey.new(sm2_private_key_pem, {
        type = "pr",
        format = "PEM"
    })
    if not priv_key then
        ngx.log(ngx.ERR, "Failed to load private key: " .. err)
        return nil
    end

    -- 使用私钥对哈希值进行签名
    local signature, err = priv_key:sign(data, "sm3")
    if not signature then
        ngx.log(ngx.ERR, "Failed to sign data: " .. err)
        return nil
    end
    return ngx.encode_base64(signature)
end

return M
