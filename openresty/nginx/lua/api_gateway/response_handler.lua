-- 响应处理模块
local redis_utils = require "redis_utils"
local sm_crypto_utils = require "gm_sm_crypto_utils"
local cjson = require "cjson"

local _M = {}

-- 加密响应体
function _M.encrypt_response(app_config, response_body)
    -- 使用SM4 CBC模式加密响应体
    local encrypted = sm_crypto_utils.sm4_cbc_encrypt(
        response_body, 
        app_config.sm4_key, 
        app_config.sm4_iv
    )
    
    if not encrypted then
        ngx.log(ngx.ERR, "响应体加密失败")
        return nil, "Failed to encrypt response"
    end
    
    return encrypted
end

-- 签名响应体
function _M.sign_response(app_config, response_body)
    -- 使用网关的SM2私钥对响应体进行签名（使用十六进制格式的私钥）
    local signature = sm_crypto_utils.sm2_sign(response_body, app_config.gateway_sm2_private_key)
    
    if not signature then
        ngx.log(ngx.ERR, "响应体签名失败")
        return nil, "Failed to sign response"
    end
    
    return signature
end

-- 处理响应
function _M.handle_response(app_config, response_body)
    -- 对响应体进行签名
    local signature, sign_err = _M.sign_response(app_config, response_body)
    if not signature then
        ngx.log(ngx.ERR, "签名响应体失败: ", sign_err)
        return nil, "Failed to sign response"
    end
    
    -- 对响应体进行加密
    local encrypted_body, encrypt_err = _M.encrypt_response(app_config, response_body)
    if not encrypted_body then
        ngx.log(ngx.ERR, "加密响应体失败: ", encrypt_err)
        return nil, "Failed to encrypt response"
    end
    
    -- 设置响应头
    ngx.header["X-Response-Signature"] = signature
    ngx.header["Content-Type"] = "application/octet-stream"
    
    -- 返回加密后的响应体
    return encrypted_body
end

-- 处理错误响应
function _M.handle_error_response(status_code, error_message, appid, api_id)
    local error_response = {
        error = error_message,
        timestamp = ngx.time(),
        status = status_code
    }
    
    -- 记录错误日志
    redis_utils.log_request(appid, api_id, "error", error_message)
    
    return cjson.encode(error_response)
end

return _M