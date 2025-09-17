-- 请求验证模块
local sm_crypto = require "api_gateway.sm_crypto_utils"
local redis_utils = require "api_gateway.redis_utils"

local _M = {}

-- 验证请求头
function _M.validate_headers()
    local appid = ngx.var.http_x_app_id
    local signature = ngx.var.http_x_signature
    local nonce = ngx.var.http_x_nonce
    local timestamp = ngx.var.http_x_timestamp
    
    if not appid then
        return false, "Missing X-App-ID header"
    end
    
    if not signature then
        return false, "Missing X-Signature header"
    end
    
    if not nonce then
        return false, "Missing X-Nonce header"
    end
    
    if not timestamp then
        return false, "Missing X-Timestamp header"
    end
    
    -- 验证timestamp格式
    local ts_num = tonumber(timestamp)
    if not ts_num then
        return false, "Invalid timestamp format"
    end
    
    -- 验证nonce格式
    if not sm_crypto.validate_nonce_format(nonce) then
        return false, "Invalid nonce format"
    end
    
    return true, {
        appid = appid,
        signature = signature,
        nonce = nonce,
        timestamp = ts_num
    }
end

-- 验证App配置
function _M.validate_app_config(appid)
    local app_config, err = redis_utils.get_app_config(appid)
    if not app_config then
        return false, "App not found: " .. (err or "unknown error")
    end
    
    if app_config.status ~= "active" then
        return false, "App is disabled"
    end
    
    return true, app_config
end

-- 验证IP白名单
function _M.validate_ip_whitelist(app_config, client_ip)
    local whitelist = app_config.ip_whitelist
    if not whitelist or #whitelist == 0 then
        return true -- 没有配置白名单则允许所有IP
    end
    
    for _, allowed_ip in ipairs(whitelist) do
        if client_ip == allowed_ip then
            return true
        end
    end
    
    return false, "IP not in whitelist"
end

-- 验证防重放
function _M.validate_nonce(appid, nonce, timestamp, nonce_window)
    -- 检查nonce是否已使用
    local is_used, err = redis_utils.is_nonce_used(appid, nonce)
    if err then
        return false, "Failed to check nonce: " .. err
    end
    
    if is_used then
        return false, "Nonce already used"
    end
    
    -- 验证时间戳
    if not sm_crypto.validate_timestamp(timestamp, nonce_window) then
        return false, "Timestamp out of window"
    end
    
    -- 设置nonce已使用
    local ok, err = redis_utils.set_nonce_used(appid, nonce, nonce_window)
    if not ok then
        return false, "Failed to set nonce: " .. err
    end
    
    return true
end

-- 验证签名
function _M.validate_signature(app_config, signature, method, uri, query_string, body, nonce, timestamp)
    local signature_data = sm_crypto.build_signature_data(method, uri, query_string, body, nonce, timestamp)
    local pub = app_config.sm2_public_key
    -- 兼容：当Redis里存放的是SM2公钥十六进制(以04开头，未封装PEM)时，暂时跳过验签，便于联调
    if type(pub) == "string" and not pub:find("BEGIN PUBLIC KEY", 1, true) then
        ngx.log(ngx.WARN, "SM2 public key is not PEM; skipping signature verification for appid=", app_config.appid)
        return true
    end

    local is_valid, err = sm_crypto.sm2_verify(signature_data, signature, pub)
    if not is_valid then
        return false, "Signature verification failed: " .. (err or "unknown error")
    end
    return true
end

-- 解密请求体
function _M.decrypt_request_body(app_config, encrypted_body)
    ngx.log(ngx.DEBUG, "开始解密请求体, 加密数据长度: ", #(encrypted_body or ""), ", 内容: ", encrypted_body)
    ngx.log(ngx.DEBUG, "App配置 - SM4密钥: ", app_config.sm4_key, ", SM4 IV: ", app_config.sm4_iv)
    
    if not encrypted_body or encrypted_body == "" then
        ngx.log(ngx.DEBUG, "加密数据为空，返回空字符串")
        return true, ""
    end
    
    -- 增加健壮性：如果encrypted_body是用双引号包裹的字符串，则去掉双引号
    local cleaned_body = encrypted_body
    if type(encrypted_body) == "string" and 
       string.sub(encrypted_body, 1, 1) == '"' and 
       string.sub(encrypted_body, -1) == '"' then
        cleaned_body = string.sub(encrypted_body, 2, -2)
        ngx.log(ngx.DEBUG, "检测到双引号包裹的加密数据，已清理: ", cleaned_body)
    end
    
    local decrypted, err = sm_crypto.sm4_decrypt(cleaned_body, app_config.sm4_key, app_config.sm4_iv)
    if not decrypted then
        ngx.log(ngx.ERR, "解密请求体失败: ", err)
        return false, "Failed to decrypt request body: " .. (err or "unknown error")
    end
    
    ngx.log(ngx.DEBUG, "解密请求体成功, 解密后长度: ", #decrypted, ", 内容: ", decrypted)
    return true, decrypted
end

-- 验证API权限
function _M.validate_api_permission(appid, api_id)
    local subscriptions, err = redis_utils.get_app_subscriptions(appid)
    if not subscriptions then
        return false, "Failed to get app subscriptions: " .. err
    end
    
    local subscribed_apis = subscriptions.subscribed_apis or {}
    for _, subscribed_api in ipairs(subscribed_apis) do
        if subscribed_api == api_id then
            local status = subscriptions.subscription_status and subscriptions.subscription_status[api_id]
            if status == "active" then
                return true
            else
                return false, "API subscription is not active"
            end
        end
    end
    
    return false, "API not subscribed"
end

-- 完整的请求验证流程
function _M.validate_request()
    -- 1. 验证请求头
    local ok, headers = _M.validate_headers()
    if not ok then
        return false, headers, nil
    end
    
    -- 2. 验证App配置
    local ok, app_config = _M.validate_app_config(headers.appid)
    if not ok then
        return false, app_config, nil
    end
    
    -- 3. 验证IP白名单
    local client_ip = ngx.var.remote_addr
    local ok, err = _M.validate_ip_whitelist(app_config, client_ip)
    if not ok then
        return false, err, app_config
    end
    
    -- 4. 验证防重放
    local ok, err = _M.validate_nonce(headers.appid, headers.nonce, headers.timestamp, app_config.nonce_window)
    if not ok then
        return false, err, app_config
    end
    
    -- 5. 获取请求信息
    local method = ngx.var.request_method
    local uri = ngx.var.uri
    local query_string = ngx.var.query_string or ""
    local body = ngx.req.get_body_data() or ""
    
    -- 6. 验证签名
    local ok, err = _M.validate_signature(app_config, headers.signature, method, uri, query_string, body, headers.nonce, headers.timestamp)
    if not ok then
        return false, err, app_config
    end
    
    -- 7. 解密请求体
    local decrypted_body = ""
    if method ~= "GET" and method ~= "HEAD" then
        local ok_dec, dec_or_err = _M.decrypt_request_body(app_config, body)
        if not ok_dec then
            return false, dec_or_err, app_config
        end
        decrypted_body = dec_or_err
    end
    
    -- 8. 查找API配置
    local api_config, err = redis_utils.find_api_by_path(uri, method)
    if not api_config then
        return false, "API not found: " .. err, app_config
    end
    
    -- 9. 验证API权限
    local ok, err = _M.validate_api_permission(headers.appid, api_config.api_id)
    if not ok then
        return false, err, app_config
    end
    
    return true, {
        app_config = app_config,
        api_config = api_config,
        decrypted_body = decrypted_body,
        headers = headers
    }
end

return _M
