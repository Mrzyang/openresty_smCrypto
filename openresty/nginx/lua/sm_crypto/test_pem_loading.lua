-- 测试PEM格式密钥加载（从Redis获取真实密钥）
local pkey = require "resty.openssl.pkey"
local redis = require "resty.redis"
local cjson = require "cjson"

ngx.header.content_type = "text/plain; charset=utf-8"

-- Redis连接配置
local REDIS_HOST = "192.168.110.45"
local REDIS_PORT = 6379

-- 获取Redis连接
local function get_redis_connection()
    local red = redis:new()
    red:set_timeout(1000) -- 1秒超时
    
    local ok, err = red:connect(REDIS_HOST, REDIS_PORT)
    if not ok then
        ngx.log(ngx.ERR, "Failed to connect to Redis: ", err)
        return nil, err
    end
    
    return red
end

-- 获取App配置
local function get_app_config(appid)
    local red, err = get_redis_connection()
    if not red then
        return nil, err
    end
    
    local res, err = red:get("app:" .. appid)
    red:close()
    
    if not res or res == ngx.null then
        return nil, "App not found"
    end
    
    local ok, app_config = pcall(cjson.decode, res)
    if not ok then
        return nil, "Failed to parse app config"
    end
    
    return app_config
end

-- 获取App配置
local app_config, err = get_app_config("app_001")
if not app_config then
    ngx.say("获取App配置失败: ", err)
    return
end

ngx.say("成功获取App配置")
ngx.say("App ID: ", app_config.appid)
ngx.say("App名称: ", app_config.name)

-- 检查公钥是否存在
if not app_config.sm2_public_key_pem then
    ngx.say("错误: 未找到PEM格式的SM2公钥")
    return
end

-- 测试PEM格式公钥加载
ngx.say("\n测试PEM格式公钥加载")
ngx.say("公钥内容:")
ngx.say(app_config.sm2_public_key_pem)

-- 尝试加载公钥
local pub_key, err = pkey.new(app_config.sm2_public_key_pem, {
    format = "PEM",
    type = "pu"
})

if not pub_key then
    ngx.say("加载公钥失败: ", err)
    return
end

ngx.say("公钥加载成功!")

-- 检查私钥是否存在
if not app_config.sm2_private_key_pem then
    ngx.say("错误: 未找到PEM格式的SM2私钥")
    return
end

-- 测试PEM格式私钥加载
ngx.say("\n测试PEM格式私钥加载")
ngx.say("私钥内容:")
ngx.say(app_config.sm2_private_key_pem)

-- 尝试加载私钥
local priv_key, err = pkey.new(app_config.sm2_private_key_pem, {
    type = "pr",
    format = "PEM"
})

if not priv_key then
    ngx.say("加载私钥失败: ", err)
    return
end

ngx.say("私钥加载成功!")

-- 测试签名和验签
local test_data = "Hello, SM2 from Redis!"
ngx.say("\n测试数据: ", test_data)

-- 使用私钥签名
local sig, err = priv_key:sign(test_data, "sm3")
if not sig then
    ngx.say("签名失败: ", err)
    return
end

ngx.say("签名成功，签名长度: ", #sig)

-- 使用公钥验签
local is_valid, err = pub_key:verify(sig, test_data, "sm3")
if not is_valid then
    ngx.say("验签失败: ", err)
    return
end

ngx.say("验签成功!")

ngx.say("\n所有测试通过！PEM格式密钥可以正确加载和使用。")