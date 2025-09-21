-- Redis工具模块
local redis = require "resty.redis"
local cjson = require "cjson"

local _M = {}

-- Redis连接配置
local REDIS_HOST = "192.168.56.2"
local REDIS_PORT = 6379
local REDIS_TIMEOUT = 1000 -- 1秒超时

-- 获取Redis连接
function _M.get_redis_connection()
    local red = redis:new()
    red:set_timeout(REDIS_TIMEOUT)
    
    local ok, err = red:connect(REDIS_HOST, REDIS_PORT)
    if not ok then
        ngx.log(ngx.ERR, "Failed to connect to Redis: ", err)
        return nil, err
    end
    
    return red
end

-- 关闭Redis连接
function _M.close_redis_connection(red)
    if red then
        local ok, err = red:close()
        if not ok then
            ngx.log(ngx.ERR, "Failed to close Redis connection: ", err)
        end
    end
end

-- 获取App配置
function _M.get_app_config(appid)
    ngx.log(ngx.DEBUG, "------------appid: ", appid)
    -- 确保appid是字符串类型
    if not appid or type(appid) ~= "string" then
        return nil, "Invalid appid: must be a string, got " .. type(appid)
    end
    
    local red, err = _M.get_redis_connection()
    if not red then
        return nil, err
    end
    
    local res, err = red:get("app:" .. appid)
    _M.close_redis_connection(red)
    
    if not res or res == ngx.null then
        return nil, "App not found"
    end
    
    local ok, app_config = pcall(cjson.decode, res)
    if not ok then
        return nil, "Failed to parse app config"
    end
    
    return app_config
end

-- 获取API配置
function _M.get_api_config(api_id)
    local red, err = _M.get_redis_connection()
    if not red then
        return nil, err
    end
    
    local res, err = red:get("api:" .. api_id)
    _M.close_redis_connection(red)
    
    if not res or res == ngx.null then
        return nil, "API not found"
    end
    
    local ok, api_config = pcall(cjson.decode, res)
    if not ok then
        return nil, "Failed to parse API config"
    end
    
    return api_config
end

-- 获取App订阅的API列表
function _M.get_app_subscriptions(appid)
    local red, err = _M.get_redis_connection()
    if not red then
        return nil, err
    end
    
    local res, err = red:get("app_subscription:" .. appid)
    _M.close_redis_connection(red)
    
    if not res or res == ngx.null then
        return nil, "App subscriptions not found"
    end
    
    local ok, subscriptions = pcall(cjson.decode, res)
    if not ok then
        return nil, "Failed to parse app subscriptions"
    end
    
    return subscriptions
end

-- 检查nonce是否已使用
function _M.is_nonce_used(appid, nonce)
    local red, err = _M.get_redis_connection()
    if not red then
        return nil, err
    end
    
    local res, err = red:get("nonce:" .. appid .. ":" .. nonce)
    _M.close_redis_connection(red)
    
    if not res then
        return nil, err
    end
    
    return res ~= ngx.null
end

-- 设置nonce已使用
function _M.set_nonce_used(appid, nonce, ttl)
    local red, err = _M.get_redis_connection()
    if not red then
        return nil, err
    end
    
    local ok, err = red:setex("nonce:" .. appid .. ":" .. nonce, ttl or 300, ngx.time())
    _M.close_redis_connection(red)
    
    if not ok then
        return nil, err
    end
    
    return true
end

-- 检查键是否存在
function _M.exists(key)
    local red, err = _M.get_redis_connection()
    if not red then
        return nil, err
    end
    
    local res, err = red:exists(key)
    _M.close_redis_connection(red)
    
    if not res then
        return nil, err
    end
    
    return res > 0
end

-- 设置键值对
function _M.set(key, value, ex, ttl)
    local red, err = _M.get_redis_connection()
    if not red then
        return nil, err
    end
    
    local ok, err
    if ex == "EX" then
        ok, err = red:setex(key, ttl, value)
    else
        ok, err = red:set(key, value)
    end
    
    _M.close_redis_connection(red)
    
    if not ok then
        return nil, err
    end
    
    return true
end

-- 根据路径查找API
function _M.find_api_by_path(path, method)
    local red, err = _M.get_redis_connection()
    if not red then
        return nil, err
    end
    
    -- 获取所有API键
    local keys, err = red:keys("api:*")
    if not keys then
        _M.close_redis_connection(red)
        return nil, err
    end
    
    for _, key in ipairs(keys) do
        local res, err = red:get(key)
        if res and res ~= ngx.null then
            local ok, api_config = pcall(cjson.decode, res)
            if ok and api_config.path == path and api_config.method == method then
                _M.close_redis_connection(red)
                return api_config
            end
        end
    end
    
    _M.close_redis_connection(red)
    return nil, "API not found"
end

-- 记录请求日志
function _M.log_request(appid, api_id, status, error_msg)
    local log_data = {
        timestamp = ngx.time(),
        appid = appid,
        api_id = api_id,
        status = status,
        error = error_msg,
        remote_addr = ngx.var.remote_addr,
        user_agent = ngx.var.http_user_agent
    }
    
    local red, err = _M.get_redis_connection()
    if not red then
        ngx.log(ngx.ERR, "Failed to connect to Redis for logging: ", err)
        return
    end
    
    local log_key = "request_log:" .. ngx.time() .. ":" .. appid
    local ok, err = red:setex(log_key, 86400, cjson.encode(log_data)) -- 保存24小时
    _M.close_redis_connection(red)
    
    if not ok then
        ngx.log(ngx.ERR, "Failed to log request: ", err)
    end
end

return _M
