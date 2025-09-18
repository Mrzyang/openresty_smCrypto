-- 响应处理模块
local sm_crypto = require "api_gateway.sm_crypto_utils"
local redis_utils = require "api_gateway.redis_utils"
local cjson = require "cjson"

local _M = {}

-- 加密响应体
function _M.encrypt_response_body(app_config, response_body)
    if not response_body or response_body == "" then
        return ""
    end
    
    local encrypted, err = sm_crypto.sm4_encrypt(response_body, app_config.sm4_key, app_config.sm4_iv)
    if not encrypted then
        ngx.log(ngx.ERR, "Failed to encrypt response body: ", err)
        return response_body -- 返回原始响应体
    end
    
    return encrypted
end

-- 对响应体签名
function _M.sign_response_body(app_config, response_body)
    ngx.log(ngx.DEBUG, "到达函数function _M.sign_response_body内部")
    if not response_body or response_body == "" then
        return ""
    end
    -- 使用网关签名私钥（支持PEM格式和十六进制格式）
    local priv = app_config.gateway_sm2_private_key_pem or app_config.gateway_sm2_private_key or 
                 app_config.sm2_private_key_pem or app_config.sm2_private_key
    -- 检查是否有私钥
    if type(priv) ~= "string" or priv == "" then
        ngx.log(ngx.WARN, "SM2 private key is missing; skipping response signing for appid=", app_config.appid)
        return ""
    end
    local signature, err = sm_crypto.sm2_sign(response_body, priv)
    ngx.log(ngx.DEBUG, "函数function _M.sign_response_body内部签名结果:", signature)
    if not signature then
        ngx.log(ngx.ERR, "Failed to sign response body: ", err)
        return ""
    end
    
    return signature
end

-- 设置响应头
function _M.set_response_headers(signature, encrypted_body)
    ngx.header["X-Signature"] = signature
    ngx.header["Content-Type"] = "application/json; charset=utf-8"
    ngx.header["Content-Length"] = #encrypted_body
    ngx.header["X-Encrypted"] = "true"
end

-- 处理错误响应
function _M.handle_error_response(error_code, error_message, appid, api_id)
    local error_response = {
        code = error_code,
        message = error_message,
        timestamp = ngx.time()
    }
    
    local response_body = cjson.encode(error_response)
    
    -- 记录错误日志
    redis_utils.log_request(appid, api_id, "error", error_message)
    
    -- 设置错误响应头
    ngx.header["Content-Type"] = "application/json; charset=utf-8"
    ngx.header["Content-Length"] = #response_body
    ngx.status = error_code
    
    return response_body
end

-- 处理成功响应
function _M.handle_success_response(backend_response, app_config, api_id, appid)
    local response_body = backend_response.body or ""
    
    -- 加密响应体
    local encrypted_body = _M.encrypt_response_body(app_config, response_body)
    
    -- 对原始响应体签名
    local signature = _M.sign_response_body(app_config, response_body)
    
    -- 设置响应头
    _M.set_response_headers(signature, encrypted_body)
    
    -- 记录成功日志
    redis_utils.log_request(appid, api_id, "success", nil)
    
    ngx.status = backend_response.status or 200
    
    return encrypted_body
end

-- 代理请求到后端
function _M.proxy_to_backend(api_config, decrypted_body, headers)
    local method = ngx.var.request_method
    local query_string = ngx.var.query_string or ""
    local uri = ngx.var.uri

    -- 构建后端URL路径
    local backend_path = api_config.backend_url:gsub("^[^:]+://[^/]+", "")  -- 移除协议和主机部分
    if backend_path == "" then backend_path = "/" end

    -- 构建完整的代理URL
    local proxy_url = "/internal_backend" .. backend_path
    if query_string ~= "" then
        if proxy_url:find("?") then
            proxy_url = proxy_url .. "&" .. query_string
        else
            proxy_url = proxy_url .. "?" .. query_string
        end
    end

    -- 构建请求头
    local req_headers = {
        ["X-Original-Method"] = method,
        ["X-Original-URI"] = uri,
        ["X-Forwarded-For"] = ngx.var.remote_addr,
        ["X-Real-IP"] = ngx.var.remote_addr
    }

    -- 复制原始请求头
    local original_headers = ngx.req.get_headers()
    for k, v in pairs(original_headers) do
        local lk = k:lower()
        -- 跳过我们自己设置的头和一些内部头
        if not (lk == "x-original-method" or lk == "x-original-uri" or 
                lk == "x-forwarded-for" or lk == "x-real-ip" or
                lk == "content-length" or lk == "connection" or
                lk == "upgrade" or lk == "transfer-encoding") then
            req_headers[k] = v
        end
    end

    -- 使用ngx.location.capture代理请求
    local res = ngx.location.capture(proxy_url, {
        method = ngx["HTTP_" .. method],
        body = (method ~= "GET" and method ~= "HEAD") and (decrypted_body or "") or nil,
        headers = req_headers,
        share_all_vars = true,
    })

    if not res then
        return nil, "Failed to request backend"
    end

    if res.status >= 400 then
        return nil, "Backend returned error: " .. res.status
    end

    return {
        status = res.status,
        body = res.body,
        headers = res.header or {}
    }
end

-- 主要的响应处理流程
function _M.process_response(validation_result, api_config, appid)
    local app_config = validation_result.app_config
    local decrypted_body = validation_result.decrypted_body
    local headers = validation_result.headers
    
    -- 代理到后端
    local backend_response, err = _M.proxy_to_backend(api_config, decrypted_body, headers)
    if not backend_response then
        return _M.handle_error_response(502, "Backend service error: " .. (err or "unknown error"), appid, api_config.api_id)
    end
    
    -- 处理成功响应
    return _M.handle_success_response(backend_response, app_config, api_config.api_id, appid)
end

return _M