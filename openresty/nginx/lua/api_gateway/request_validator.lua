-- 请求验证模块
local redis_utils = require "redis_utils"
local sm_crypto_utils = require "gm_sm_crypto_utils"
local cjson = require "cjson"
local ngx_re = require "ngx.re"

local _M = {}

-- 验证签名
function _M.validate_signature(app_config, method, uri, query_string, body, nonce, timestamp, signature)
    -- 先对请求体进行SM4解密（如果请求体不为空）
    local decrypted_body = body
    if body and body ~= "" then
        ngx.log(ngx.DEBUG, "解密前的请求体: ", body)
        ngx.log(ngx.DEBUG, "sm4算法key: ", app_config.sm4_key)
        ngx.log(ngx.DEBUG, "sm4算法iv: ", app_config.sm4_iv)
        local decrypted, err = sm_crypto_utils.sm4_cbc_decrypt(body, app_config.sm4_key, app_config.sm4_iv)
        if decrypted then
            decrypted_body = decrypted
            ngx.log(ngx.DEBUG, "解密后的请求体: ", decrypted_body)
        else
            ngx.log(ngx.WARN, "请求体解密失败: ", err)
            -- 如果解密失败，仍然使用原始body进行签名验证
        end
    end
    
    -- 构建签名数据（使用解密后的请求体）
    local sign_data = sm_crypto_utils.build_signature_data(method, uri, query_string, decrypted_body, nonce, timestamp)
    
    ngx.log(ngx.DEBUG, "签名数据: ", sign_data)
    ngx.log(ngx.DEBUG, "签名: ", signature)
    ngx.log(ngx.DEBUG, "公钥: ", app_config.sm2_public_key)

    -- 验证签名（使用十六进制格式的公钥）
    local is_valid = sm_crypto_utils.sm2_verify(sign_data, signature, app_config.sm2_public_key)
    
    ngx.log(ngx.DEBUG, "签名验证结果: ", tostring(is_valid))
    
    if not is_valid then
        ngx.log(ngx.ERR, "签名验证失败")
        ngx.log(ngx.ERR, "签名数据: ", sign_data)
        ngx.log(ngx.ERR, "签名: ", signature)
        ngx.log(ngx.ERR, "公钥: ", app_config.sm2_public_key)
        return false, "Signature verification failed"
    end
    
    return true
end

-- 验证时间戳
function _M.validate_timestamp(timestamp, window_seconds)
    return sm_crypto_utils.validate_timestamp(timestamp, window_seconds)
end

-- 验证nonce
function _M.validate_nonce(nonce, appid)
    -- 检查nonce格式
    if not sm_crypto_utils.validate_nonce_format(nonce) then
        return false, "Invalid nonce format"
    end
    
    -- 检查nonce是否已存在（防重放攻击）
    local exists, err = redis_utils.exists("nonce:" .. appid .. ":" .. nonce)
    if err then
        ngx.log(ngx.ERR, "检查nonce时发生错误: ", err)
        return false, "Internal server error"
    end
    
    if exists then
        return false, "Nonce already used"
    end
    
    -- 存储nonce，设置过期时间
    local window_seconds = 300 -- 5分钟
    local ok, err = redis_utils.set("nonce:" .. appid .. ":" .. nonce, "1", "EX", window_seconds)
    if not ok then
        ngx.log(ngx.ERR, "存储nonce时发生错误: ", err)
        return false, "Internal server error"
    end
    
    return true
end

-- 验证IP白名单
function _M.validate_ip_whitelist(client_ip, ip_whitelist)
    for _, ip in ipairs(ip_whitelist) do
        if client_ip == ip then
            return true
        end
    end
    return false
end

-- 验证请求
function _M.validate_request(appid, method, uri, query_string, body, headers)
    -- 检查headers是否为nil
    if not headers then
        ngx.log(ngx.ERR, "请求头为空")
        return false, "Missing headers"
    end
    
    -- 检查必需的请求头
    if not appid or type(appid) ~= "string" then
        return false, "Missing required header: X-App-ID"
    end
    
    local signature = headers["x-signature"]
    if not signature then
        return false, "Missing required header: X-Signature"
    end
    
    -- 获取可选的防重放参数
    local nonce = headers["x-nonce"]
    local timestamp = headers["x-timestamp"]
    
    -- 如果提供了nonce或timestamp，必须同时提供两者
    if (nonce and not timestamp) or (timestamp and not nonce) then
        return false, "Both X-Nonce and X-Timestamp must be provided together"
    end
    
    local app_config, err
    -- 如果提供了防重放参数，则进行验证
    if nonce and timestamp then
        -- 转换时间戳为数字
        timestamp = tonumber(timestamp)
        if not timestamp then
            return false, "Invalid timestamp"
        end
        
        -- 获取App配置
        app_config, err = redis_utils.get_app_config(appid)
        if not app_config then
            ngx.log(ngx.ERR, "获取App配置失败: ", err)
            return false, "Invalid appid"
        end
        
        -- 验证时间戳
        if not _M.validate_timestamp(timestamp, app_config.nonce_window) then
            return false, "Timestamp out of window"
        end
        
        -- 验证nonce
        local nonce_valid, nonce_err = _M.validate_nonce(nonce, appid)
        if not nonce_valid then
            return false, nonce_err
        end
        
        -- 验证签名
        local sign_valid, sign_err = _M.validate_signature(app_config, method, uri, query_string, body, nonce, timestamp, signature)
        if not sign_valid then
            return false, sign_err
        end
    else
        -- 如果没有提供防重放参数，则只验证签名（使用空字符串作为nonce和0作为timestamp来构建签名数据）
        -- 获取App配置
        app_config, err = redis_utils.get_app_config(appid)
        if not app_config then
            ngx.log(ngx.ERR, "获取App配置失败: ", err)
            return false, "Invalid appid"
        end
        
        -- 验证签名
        local sign_valid, sign_err = _M.validate_signature(app_config, method, uri, query_string, body, "", 0, signature)
        if not sign_valid then
            return false, sign_err
        end
    end
    
    -- 验证IP白名单
    local client_ip = ngx.var.remote_addr
    if not _M.validate_ip_whitelist(client_ip, app_config.ip_whitelist) then
        return false, "IP not in whitelist"
    end
    
    return true, app_config
end

return _M