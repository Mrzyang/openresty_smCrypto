-- SM2验签调试脚本
local pkey = require "resty.openssl.pkey"
local sm2 = require "resty.openssl.ec"
local digest = require "resty.openssl.digest"

-- 从Redis获取App配置中的公钥进行测试
local redis = require "resty.redis"
local cjson = require "cjson"

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

-- SM2验签函数
local function sm2_verify(data, signature, public_key)
    -- 仅支持PEM格式的公钥
    local key_format = "PEM"
    local key_type = "pu"
    
    -- 检查是否为PEM格式
    if not public_key:find("BEGIN PUBLIC KEY", 1, true) then
        ngx.log(ngx.ERR, "公钥不是PEM格式")
        return false, "Public key is not in PEM format"
    end
    
    ngx.log(ngx.DEBUG, "SM2验签 - 密钥格式: ", key_format, ", 密钥类型: ", key_type)
    ngx.log(ngx.DEBUG, "公钥内容: ", public_key)
    
    local pub_key, err = pkey.new(public_key, {
        format = key_format,
        type = key_type
    })
    if not pub_key then
        ngx.log(ngx.ERR, "加载公钥失败: ", err, ", 密钥格式: ", key_format, ", 密钥类型: ", key_type)
        return false, "Failed to load public key: " .. (err or "unknown error")
    end

    local sig_bytes = ngx.decode_base64(signature)
    if not sig_bytes then
        ngx.log(ngx.ERR, "Base64解码签名失败")
        return false, "Failed to decode signature"
    end

    local is_valid, err = pub_key:verify(sig_bytes, data, "sm3")
    if not is_valid then
        ngx.log(ngx.ERR, "签名验证失败: ", err)
        return false, "Signature verification failed: " .. (err or "unknown error")
    end

    return true
end

-- 主函数
local function main()
    ngx.header.content_type = "text/plain; charset=utf-8"
    
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
    
    ngx.say("公钥存在，长度: ", #app_config.sm2_public_key_pem)
    ngx.say("公钥开头: ", string.sub(app_config.sm2_public_key_pem, 1, 30))
    
    -- 测试数据
    local test_data = "Hello, SM2!"
    ngx.say("测试数据: ", test_data)
    
    -- 使用Node.js生成的签名进行测试（这里需要手动获取一个真实的签名）
    -- 在实际测试中，我们需要从测试客户端获取签名
    ngx.say("请使用测试客户端生成签名后，将签名数据传递给此脚本进行验证")
    
    -- 如果有签名参数，则进行验签测试
    local signature = ngx.var.arg_signature
    if signature then
        ngx.say("收到签名参数，开始验签测试...")
        local is_valid, err = sm2_verify(test_data, signature, app_config.sm2_public_key_pem)
        if is_valid then
            ngx.say("签名验证成功!")
        else
            ngx.say("签名验证失败: ", err)
        end
    else
        ngx.say("请提供签名参数进行测试，例如: ?signature=BASE64_ENCODED_SIGNATURE")
    end
end

-- 执行主函数
main()