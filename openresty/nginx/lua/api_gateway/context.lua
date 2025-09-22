-- API网关上下文模块，用于在不同Lua模块间共享数据
local _M = {}

-- 共享的App配置信息（已移除，不再缓存）
-- _M.app_config = nil
-- _M.app_config_version = nil

-- 设置App配置（已移除，不再缓存）
-- function _M.set_app_config(config)
--     _M.app_config = config
--     _M.app_config_version = ngx.time()
-- end

-- 获取App配置（已移除，不再缓存）
-- function _M.get_app_config()
--     return _M.app_config
-- end

-- 清除App配置（已移除，不再缓存）
-- function _M.clear_app_config()
--     _M.app_config = nil
--     _M.app_config_version = nil
-- end

-- 检查App配置是否需要更新（已移除，不再缓存）
-- function _M.is_app_config_stale()
--     if not _M.app_config or not _M.app_config_version then
--         return true
--     end
--     
--     local current_time = ngx.time()
--     if current_time - _M.app_config_version > 30 then
--         return true
--     end
--     
--     return false
-- end

return _M