-- 流量控制模块
local limit_req = require "resty.limit.req"
local redis_utils = require "redis_utils"

local _M = {}

-- 根据API配置创建限流器
function _M.create_rate_limiter(api_config)
    -- 使用API路径作为限流器的标识
    local lim, err = limit_req.new("api_rate_limit", api_config.rate_limit, api_config.rate_burst)
    if not lim then
        ngx.log(ngx.ERR, "failed to create rate limiter: ", err)
        return nil, err
    end
    
    return lim
end

-- 检查请求是否被限流
function _M.check_rate_limit(api_config, appid)
    -- 创建限流器
    local lim, err = _M.create_rate_limiter(api_config)
    if not lim then
        return false, err
    end
    
    -- 使用appid作为限流键
    local key = appid .. ":" .. api_config.path
    local delay, err = lim:incoming(key, true)
    
    if not delay then
        if err == "rejected" then
            ngx.log(ngx.WARN, "请求被限流: ", key)
            return false, "Rate limit exceeded"
        end
        ngx.log(ngx.ERR, "限流检查失败: ", err)
        return false, "Internal server error"
    end
    
    -- 如果需要延迟，则执行延迟
    if delay >= 0.001 then
        ngx.sleep(delay)
    end
    
    return true
end

return _M