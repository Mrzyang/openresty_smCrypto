-- API网关上下文模块，用于在不同Lua模块间共享数据
local _M = {}

-- 共享的App配置信息
_M.app_config = nil

-- 设置App配置
function _M.set_app_config(config)
    _M.app_config = config
end

-- 获取App配置
function _M.get_app_config()
    return _M.app_config
end

-- 清除App配置
function _M.clear_app_config()
    _M.app_config = nil
end

return _M