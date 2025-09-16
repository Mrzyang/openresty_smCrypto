-- 响应处理模块
local sm_crypto = require "api_gateway.sm_crypto_utils"
local redis_utils = require "api_gateway.redis_utils"
local cjson = require "cjson"
local http = require "resty.http"

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
    if not response_body or response_body == "" then
        return ""
    end
    -- 仅当私钥为PEM格式时才进行签名
    local priv = app_config.sm2_private_key
    if type(priv) ~= "string" or not priv:find("BEGIN PRIVATE KEY", 1, true) then
        ngx.log(ngx.WARN, "SM2 private key is not PEM; skipping response signing for appid=", app_config.appid)
        return ""
    end
    local signature, err = sm_crypto.sm2_sign(response_body, priv)
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

    local url = api_config.backend_url
    if query_string ~= "" then
        url = url .. "?" .. query_string
    end

    local httpc = http.new()
    httpc:set_timeout((api_config.timeout or 30) * 1000)

    local req_headers = {
        ["X-Original-Method"] = method,
        ["X-Original-URI"] = ngx.var.uri,
        ["X-Forwarded-For"] = ngx.var.remote_addr,
        ["X-Real-IP"] = ngx.var.remote_addr
    }

    local req_opts = {
        method = method,
        headers = req_headers,
        keepalive = true,
    }

    if method ~= "GET" and method ~= "HEAD" then
        req_headers["Content-Type"] = "application/json"
        req_opts.body = decrypted_body or ""
    end

    local res, err = httpc:request_uri(url, req_opts)
    if not res then
        return nil, "Failed to request backend: " .. (err or "unknown error")
    end

    if res.status >= 400 then
        return nil, "Backend returned error: " .. res.status
    end

    return {
        status = res.status,
        body = res.body,
        headers = res.headers or {}
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
