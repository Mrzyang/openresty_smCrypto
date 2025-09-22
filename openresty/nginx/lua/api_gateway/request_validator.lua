-- 请求验证模块
local redis_utils = require "redis_utils"
local sm_crypto_utils = require "gm_sm_crypto_utils"
local context = require "context"
local cjson = require "cjson"

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
    
    return true, decrypted_body
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
    local is_used, err = redis_utils.is_nonce_used(appid, nonce)
    if err then
        ngx.log(ngx.ERR, "检查nonce时发生错误: ", err)
        return false, "Internal server error"
    end
    
    if is_used then
        ngx.log(ngx.WARN, "Nonce已被使用，可能是重放攻击: ", appid, ":", nonce)
        return false, "Nonce already used"
    end
    
    -- 存储nonce到防重放缓存，设置过期时间为5分钟
    local window_seconds = 300 -- 5分钟
    local ok, err = redis_utils.set_nonce_used(appid, nonce, window_seconds)
    if not ok then
        ngx.log(ngx.ERR, "存储nonce到防重放缓存时发生错误: ", err)
        return false, "Internal server error"
    end
    
    ngx.log(ngx.DEBUG, "Nonce验证通过并已存储到防重放缓存: nonce:", appid, ":", nonce)
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

-- 验证API订阅
function _M.validate_api_subscription(appid, uri, method)
    -- 获取App订阅信息
    local subscriptions, err = redis_utils.get_app_subscriptions(appid)
    if not subscriptions then
        ngx.log(ngx.ERR, "获取App订阅信息失败: ", err)
        return false, "Failed to get app subscriptions"
    end
    
    -- 查找匹配的API（使用新的方法根据路径获取API配置）
    local api_config, err = redis_utils.get_api_config_by_path(uri)
    if not api_config then
        ngx.log(ngx.ERR, "API未找到: ", uri, " ", method)
        return false, "API not found"
    end
    
    -- 检查API方法是否匹配
    if api_config.method ~= method then
        ngx.log(ngx.ERR, "API方法不匹配: ", uri, " ", method)
        return false, "API method not match"
    end
    
    -- 检查API是否在订阅列表中
    local is_subscribed = false
    for _, api_path in ipairs(subscriptions.subscribed_apis) do
        if api_path == api_config.path then
            is_subscribed = true
            break
        end
    end
    
    if not is_subscribed then
        ngx.log(ngx.ERR, "App未订阅此API: ", appid, " ", api_config.path)
        return false, "API not subscribed"
    end
    
    -- 检查API状态和订阅状态
    if api_config.status ~= "active" then
        ngx.log(ngx.ERR, "API状态不活跃: ", api_config.path)
        return false, "API is disabled"
    end
    
    if subscriptions.subscription_status[api_config.path] ~= "active" then
        ngx.log(ngx.ERR, "API订阅状态不活跃: ", api_config.path)
        return false, "API subscription is disabled"
    end
    
    return true, api_config
end

-- 验证请求体是否为空（除GET请求外）
function _M.validate_request_body(method, body, decrypted_body)
    -- GET请求不需要检查请求体
    if method == "GET" then
        return true
    end
    
    -- 检查原始请求体是否为空
    if not body or body == "" then
        return false, "Request body is required for " .. method .. " requests"
    end
    
    -- 检查解密后的请求体是否为空
    if not decrypted_body or decrypted_body == "" then
        return false, "Decrypted request body is empty for " .. method .. " requests"
    end
    
    return true
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
    local decrypted_body = nil
    
    -- 直接从Redis获取App配置，不再使用缓存
    app_config, err = redis_utils.get_app_config(appid)
    if not app_config then
        ngx.log(ngx.ERR, "获取App配置失败: ", err)
        return false, "Invalid appid"
    end
    
    -- 如果提供了防重放参数，则进行验证
    if nonce and timestamp then
        -- 转换时间戳为数字
        timestamp = tonumber(timestamp)
        if not timestamp then
            return false, "Invalid timestamp"
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
        local sign_valid, decrypt_result = _M.validate_signature(app_config, method, uri, query_string, body, nonce, timestamp, signature)
        if not sign_valid then
            return false, decrypt_result
        end
        
        -- 保存解密后的请求体
        decrypted_body = decrypt_result
    else
        -- 如果没有提供防重放参数，则只验证签名（使用空字符串作为nonce和0作为timestamp来构建签名数据）
        -- 验证签名
        local sign_valid, decrypt_result = _M.validate_signature(app_config, method, uri, query_string, body, "", 0, signature)
        if not sign_valid then
            return false, decrypt_result
        end
        
        -- 保存解密后的请求体
        decrypted_body = decrypt_result
    end
    
    -- 验证请求体是否为空（除GET请求外）
    local body_valid, body_err = _M.validate_request_body(method, body, decrypted_body)
    if not body_valid then
        return false, body_err
    end
    
    -- 验证IP白名单
    local client_ip = ngx.var.remote_addr
    if not _M.validate_ip_whitelist(client_ip, app_config.ip_whitelist) then
        return false, "IP not in whitelist"
    end
    
    -- 验证API订阅
    local api_valid, api_result = _M.validate_api_subscription(appid, uri, method)
    if not api_valid then
        return false, api_result
    end
    
    -- 返回包含App配置、API配置和解密后请求体的结果
    return true, {
        app_config = app_config, 
        api_config = api_result,
        decrypted_body = decrypted_body
    }
end

return _M