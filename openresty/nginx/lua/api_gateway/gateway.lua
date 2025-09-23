-- API网关主入口
local request_validator = require "request_validator"
local response_handler = require "response_handler"
local redis_utils = require "redis_utils"
local rate_limiter = require "rate_limiter"
local context = require "context"
local cjson = require "cjson"
local http = require "resty.http"

local _M = {}

-- 主处理函数
function _M.handle_request()
    -- 获取请求信息
    local method = ngx.var.request_method
    local uri = ngx.var.uri
    local query_string = ngx.var.query_string
    
    -- 获取请求头
    local headers = ngx.req.get_headers()
    local appid = headers["X-App-ID"]
    ngx.log(ngx.DEBUG, "App ID: ", appid)

    --  根据客户端请求的uri获取到redis中api配置信息
    local api_config, err = redis_utils.get_api_config_by_path(uri)
    if not api_config then
        ngx.log(ngx.ERR, "无法从Redis获取API配置: ", err)
        ngx.status = 502
        ngx.say('{"error":"Failed to get API config"}')
        return
    end
    
    -- 检查流量控制
    local rate_allowed, rate_err = rate_limiter.check_rate_limit(api_config, appid)
    if not rate_allowed then
        ngx.status = 429
        ngx.say('{"error":"' .. rate_err .. '","code":429}')
        return
    end
    
    -- 读取请求体
    ngx.req.read_body()
    local body = ngx.req.get_body_data()
    
    ngx.log(ngx.DEBUG, "接收到请求: ", method, " ", uri)
    ngx.log(ngx.DEBUG, "请求体大小: ", body and #body or 0)
    if body then
        ngx.log(ngx.DEBUG, "请求体内容: ", body)
    end
    
    -- 检查必需的请求头
    if not appid then
        ngx.status = 400
        ngx.say('{"error":"Missing required header: X-App-ID"}')
        return
    end
    
    -- 1. 验证请求
    local is_valid, result = request_validator.validate_request(appid, method, uri, query_string, body, headers)
    
    if not is_valid then
        -- 处理验证失败
        local error_code = 400
        local api_id = "unknown"
        
        -- 根据错误类型设置不同的状态码
        if string.find(tostring(result), "not found") then
            error_code = 404
        elseif string.find(tostring(result), "disabled") then
            error_code = 403
        elseif string.find(tostring(result), "signature") then
            error_code = 401
        elseif string.find(tostring(result), "whitelist") then
            error_code = 403
        elseif string.find(tostring(result), "Nonce already used") then
            error_code = 409
        elseif string.find(tostring(result), "Timestamp out of window") then
            error_code = 408
        end
        
        local error_response = response_handler.handle_error_response(error_code, tostring(result), appid, api_id)
        ngx.status = error_code
        ngx.say(error_response)
        return
    end
    
    -- 获取解密后的请求体
    local forward_body = result.decrypted_body
    ngx.log(ngx.DEBUG, "解密后的请求体: ", forward_body)
    ngx.log(ngx.DEBUG, "解密后请求体大小: ", forward_body and #forward_body or 0)
    -- 添加更多调试信息
    if forward_body then
        ngx.log(ngx.DEBUG, "解密后请求体类型: ", type(forward_body))
        -- 只记录前100个字符，避免日志过大
        local display_body = forward_body
        if #forward_body > 100 then
            display_body = string.sub(forward_body, 1, 100) .. "...(truncated)"
        end
        ngx.log(ngx.DEBUG, "解密后请求体内容(前100字符): ", display_body)
    end
    ---------------------------------------

    -----------------------------------------
    -- 获取后端URI
    local backend_uri = api_config.backend_uri
    if not backend_uri then
        ngx.log(ngx.ERR, "API配置中缺少backend_uri")
        ngx.status = 502
        ngx.say('{"error":"Missing backend_uri in API config"}')
        return
    end
    
    -- 获取后端IP列表
    local backend_ip_list = api_config.backend_ip_list
    if not backend_ip_list or #backend_ip_list == 0 then
        ngx.log(ngx.ERR, "API配置中缺少backend_ip_list")
        ngx.status = 502
        ngx.say('{"error":"Missing backend_ip_list in API config"}')
        return
    end
    
    -- 选择第一个后端服务器（实际应用中可以实现更复杂的负载均衡策略）
    local backend_ip_port = backend_ip_list[1]
    local backend_host, backend_port = string.match(backend_ip_port, "([^:]+):(%d+)")
    if not backend_host or not backend_port then
        ngx.log(ngx.ERR, "无效的后端服务器地址格式: ", backend_ip_port)
        ngx.status = 502
        ngx.say('{"error":"Invalid backend server address format"}')
        return
    end
    
    -- 构造传递给后端的请求头
    local backend_headers = {}
    -- 设置正确的Content-Type
    backend_headers["Content-Type"] = "application/json"
    
    -- 获取要转发的请求体
    local proxy_body = forward_body
    if proxy_body == nil then
        proxy_body = ""
    end
    
    -- 确保proxy_body是字符串类型
    if type(proxy_body) ~= "string" then
        proxy_body = tostring(proxy_body)
    end
    
    -- 设置Content-Length为实际的请求体长度
    backend_headers["Content-Length"] = tostring(#proxy_body)
    
    -- 记录原始请求体内容用于调试
    ngx.log(ngx.DEBUG, "原始proxy_body内容: ", proxy_body)
    ngx.log(ngx.DEBUG, "原始proxy_body长度: ", #proxy_body)
    
    -- 使用lua-resty-http模块代理请求到后端服务
    local httpc = http.new()
    -- 增加超时时间，避免间歇性超时问题
    httpc:set_timeout(60000) -- 60秒超时
    
    -- 启用连接池以优化性能
    -- 连接池参数：最大空闲超时60秒，最大连接数32
    local keepalive_timeout = 60000  -- 60秒
    local keepalive_pool = 32
    
    -- 创建请求参数表，确保数据不会被修改
    local request_params = {
        method = method,
        body = proxy_body,
        headers = backend_headers
    }
    
    -- 显式复制请求体内容，确保不会被垃圾回收
    local body_copy = proxy_body
    request_params.body = body_copy
    
    ngx.log(ngx.DEBUG, "发送请求前再次确认body长度: ", #body_copy)
    ngx.log(ngx.DEBUG, "发送请求前再次确认body内容: ", body_copy)
    
    local res, err = httpc:request_uri("http://" .. backend_host .. ":" .. backend_port .. backend_uri, request_params)
    
    -- 将连接放回连接池以优化性能
    httpc:set_keepalive(keepalive_timeout, keepalive_pool)
    
    -- 显式清理
    body_copy = nil
    request_params = nil
    
    if not res then
        ngx.log(ngx.ERR, "后端服务请求失败: ", err)
        ngx.status = 502
        ngx.say('{"error":"Bad Gateway"}')
        return
    end
    
    ngx.log(ngx.DEBUG, "后端响应状态: ", res.status)
    ngx.log(ngx.DEBUG, "后端响应体大小: ", res.body and #res.body or 0)
    if res.body then
        -- 只记录前100个字符，避免日志过大
        local display_response = res.body
        if #res.body > 100 then
            display_response = string.sub(res.body, 1, 100) .. "...(truncated)"
        end
        ngx.log(ngx.DEBUG, "后端响应体内容(前100字符): ", display_response)
    end
    
    -- 检查后端响应
    if res.status >= 500 then
        ngx.status = res.status
        ngx.say('{"error":"Backend service error"}')
        return
    end
    
    -- 3. 处理后端响应
    -- 对于非200状态码的响应，不进行加密和签名
    if res.status == 200 then
        ngx.log(ngx.DEBUG, "开始处理成功响应")
        local encrypted_response_body = response_handler.handle_response(result.app_config, res.body)
        ngx.log(ngx.DEBUG, "后端响应体内容(前100字符): ", display_response)
        ngx.log(ngx.DEBUG, "网关加密后的响应体内容: ", encrypted_response_body)
        if encrypted_response_body then
            ngx.status = res.status
            ngx.header["Content-Length"] = #encrypted_response_body
            ngx.header["x-encrypted"] = "true"
            ngx.print(encrypted_response_body)
        else
            ngx.log(ngx.ERR, "响应处理失败")
            ngx.status = 500
            ngx.say('{"error":"Failed to process response"}')
        end
        ngx.log(ngx.DEBUG, "成功响应处理完成")
    else
        -- 对于错误响应，直接返回，不进行加密和签名
        ngx.status = res.status
        ngx.header["Content-Length"] = #(res.body or "")
        ngx.print(res.body or "")
    end
    
    ngx.log(ngx.DEBUG, "请求处理完成")
end

-- 健康检查
function _M.health_check()
    local red, err = redis_utils.get_redis_connection()
    if not red then
        ngx.status = 503
        ngx.say('{"status":"unhealthy","error":"Redis connection failed"}')
        return
    end
    
    redis_utils.close_redis_connection(red)
    
    ngx.status = 200
    ngx.say('{"status":"healthy","timestamp":' .. ngx.time() .. '}')
end

-- 管理接口 - 获取App信息
function _M.get_app_info()
    local appid = ngx.var.arg_appid
    if not appid then
        ngx.status = 400
        ngx.say('{"error":"Missing appid parameter"}')
        return
    end
    
    local app_config, err = redis_utils.get_app_config(appid)
    if not app_config then
        ngx.status = 404
        ngx.say('{"error":"App not found"}')
        return
    end
    
    -- 隐藏敏感信息
    app_config.sm2_public_key = nil
    app_config.gateway_sm2_private_key = nil
    app_config.sm4_key = nil
    app_config.sm4_iv = nil
    
    ngx.status = 200
    ngx.say(cjson.encode(app_config))
end

-- 管理接口 - 获取API信息
function _M.get_api_info()
    local uri = ngx.var.arg_uri
    if not uri then
        ngx.status = 400
        ngx.say('{"error":"Missing uri parameter"}')
        return
    end
    
    local api_config, err = redis_utils.get_api_config_by_path(uri)
    if not api_config then
        ngx.status = 404
        ngx.say('{"error":"API not found"}')
        return
    end
    
    ngx.status = 200
    ngx.say(cjson.encode(api_config))
end

-- 管理接口 - 获取App订阅信息
function _M.get_app_subscriptions()
    local appid = ngx.var.arg_appid
    if not appid then
        ngx.status = 400
        ngx.say('{"error":"Missing appid parameter"}')
        return
    end
    
    local subscriptions, err = redis_utils.get_app_subscriptions(appid)
    if not subscriptions then
        ngx.status = 404
        ngx.say('{"error":"App subscriptions not found"}')
        return
    end
    
    ngx.status = 200
    ngx.say(cjson.encode(subscriptions))
end

return _M