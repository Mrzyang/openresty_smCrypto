-- API网关主入口
local request_validator = require "api_gateway.request_validator"
local response_handler = require "api_gateway.response_handler"
local redis_utils = require "api_gateway.redis_utils"
local cjson = require "cjson"

local _M = {}

-- 主处理函数
function _M.handle_request()
    -- 1. 验证请求
    local is_valid, result, app_config = request_validator.validate_request()
    
    if not is_valid then
        -- 处理验证失败
        local error_code = 400
        local appid = "unknown"
        local api_id = "unknown"
        
        if app_config then
            appid = app_config.appid or "unknown"
        end
        
        -- 根据错误类型设置不同的状态码
        if string.find(result, "not found") then
            error_code = 404
        elseif string.find(result, "disabled") then
            error_code = 403
        elseif string.find(result, "signature") then
            error_code = 401
        elseif string.find(result, "whitelist") then
            error_code = 403
        elseif string.find(result, "Nonce already used") then
            error_code = 409
        elseif string.find(result, "Timestamp out of window") then
            error_code = 408
        end
        
        local error_response = response_handler.handle_error_response(error_code, result, appid, api_id)
        ngx.say(error_response)
        return
    end
    
    -- 2. 处理响应
    local response_body = response_handler.process_response(result, result.api_config, result.headers.appid)
    ngx.say(response_body)
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
    app_config.sm2_private_key = nil
    app_config.sm2_public_key = nil
    app_config.sm4_key = nil
    app_config.sm4_iv = nil
    
    ngx.status = 200
    ngx.say(cjson.encode(app_config))
end

-- 管理接口 - 获取API信息
function _M.get_api_info()
    local api_id = ngx.var.arg_api_id
    if not api_id then
        ngx.status = 400
        ngx.say('{"error":"Missing api_id parameter"}')
        return
    end
    
    local api_config, err = redis_utils.get_api_config(api_id)
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
