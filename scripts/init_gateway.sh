#!/bin/bash

# API网关初始化脚本
# 读取.env文件中的配置信息，修改相关配置文件，并初始化Redis数据

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 检查并加载.env文件
load_env() {
    if [ ! -f "$PROJECT_DIR/.env" ]; then
        log_error ".env file not found in project root: $PROJECT_DIR/.env"
        exit 1
    fi
    
    # 加载.env文件
    set -a
    source "$PROJECT_DIR/.env"
    set +a
    
    log_info "Loaded configuration from .env file"
}

# 验证必要配置
validate_config() {
    local missing_vars=()
    
    # 检查必要变量
    [[ -z "$OPENRESTY_HOME" ]] && missing_vars+=("OPENRESTY_HOME")
    [[ -z "$EXPRESS_HOME" ]] && missing_vars+=("EXPRESS_HOME")
    [[ -z "$REDIS_HOST" ]] && missing_vars+=("REDIS_HOST")
    [[ -z "$REDIS_PORT" ]] && missing_vars+=("REDIS_PORT")
    [[ -z "$GATEWAY_PORT" ]] && missing_vars+=("GATEWAY_PORT")
    [[ -z "$BACKEND_PORT" ]] && missing_vars+=("BACKEND_PORT")
    [[ -z "$GATEWAY_ACCESS_LOG" ]] && missing_vars+=("GATEWAY_ACCESS_LOG")
    [[ -z "$GATEWAY_ERROR_LOG" ]] && missing_vars+=("GATEWAY_ERROR_LOG")
    [[ -z "$LUA_PACKAGE_PATH" ]] && missing_vars+=("LUA_PACKAGE_PATH")
    [[ -z "$LUA_PACKAGE_CPATH" ]] && missing_vars+=("LUA_PACKAGE_CPATH")
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        log_error "Missing required configuration variables: ${missing_vars[*]}"
        exit 1
    fi
    
    log_info "Configuration validation passed"
}

# 修改api_gateway.conf文件
update_api_gateway_conf() {
    local conf_file="$OPENRESTY_HOME/nginx/conf/conf.d/api_gateway.conf"
    
    if [ ! -f "$conf_file" ]; then
        log_error "API gateway config file not found: $conf_file"
        exit 1
    fi
    
    log_info "Updating API gateway configuration..."
    
    # 备份原文件
    cp "$conf_file" "${conf_file}.bak"
    
    # 更新Lua包路径
    sed -i "s|lua_package_path.*|lua_package_path \"$LUA_PACKAGE_PATH\";|" "$conf_file"
    sed -i "s|lua_package_cpath.*|lua_package_cpath \"$LUA_PACKAGE_CPATH\";|" "$conf_file"
    
    # 更新监听端口
    sed -i "s|listen [0-9]*;|listen $GATEWAY_PORT;|" "$conf_file"
    
    # 更新日志路径
    sed -i "s|access_log .*api_gateway_access.log|access_log $GATEWAY_ACCESS_LOG|" "$conf_file"
    sed -i "s|error_log .*api_gateway_error.log|error_log $GATEWAY_ERROR_LOG|g" "$conf_file"
    
    log_info "API gateway configuration updated successfully"
}

# 修改redis_utils.lua文件
update_redis_utils() {
    local redis_file="$OPENRESTY_HOME/nginx/lua/api_gateway/redis_utils.lua"
    
    if [ ! -f "$redis_file" ]; then
        log_error "Redis utils file not found: $redis_file"
        exit 1
    fi
    
    log_info "Updating Redis configuration..."
    
    # 备份原文件
    cp "$redis_file" "${redis_file}.bak"
    
    # 更新Redis主机和端口
    sed -i "s|local REDIS_HOST = .*|local REDIS_HOST = \"$REDIS_HOST\"|" "$redis_file"
    sed -i "s|local REDIS_PORT = .*|local REDIS_PORT = $REDIS_PORT|" "$redis_file"
    
    log_info "Redis configuration updated successfully"
}

# 修改gmCryptor Lua文件中的OPENRESTY_HOME
update_gm_cryptor_files() {
    local gm_c_file="$PROJECT_DIR/openresty/lualib/gmCryptor-c.lua"
    local gm_go_file="$PROJECT_DIR/openresty/lualib/gmCryptor-go.lua"
    
    log_info "Updating gmCryptor Lua files..."
    
    # 更新gmCryptor-c.lua
    if [ -f "$gm_c_file" ]; then
        # 备份原文件
        cp "$gm_c_file" "${gm_c_file}.bak"
        
        # 更新OPENRESTY_HOME变量
        sed -i "s|local OPENRESTY_HOME = .*|local OPENRESTY_HOME = '$OPENRESTY_HOME'|" "$gm_c_file"
        
        log_info "Updated gmCryptor-c.lua with OPENRESTY_HOME: $OPENRESTY_HOME"
    else
        log_warn "gmCryptor-c.lua not found: $gm_c_file"
    fi
    
    # 更新gmCryptor-go.lua
    if [ -f "$gm_go_file" ]; then
        # 备份原文件
        cp "$gm_go_file" "${gm_go_file}.bak"
        
        # 更新OPENRESTY_HOME变量
        sed -i "s|local OPENRESTY_HOME = .*|local OPENRESTY_HOME = '$OPENRESTY_HOME'|" "$gm_go_file"
        
        log_info "Updated gmCryptor-go.lua with OPENRESTY_HOME: $OPENRESTY_HOME"
    else
        log_warn "gmCryptor-go.lua not found: $gm_go_file"
    fi
    
    log_info "gmCryptor Lua files updated successfully"
}

# 初始化Redis数据
init_redis_data() {
    log_info "Initializing Redis data..."
    
    if [ ! -f "$SCRIPT_DIR/init_redis_data.sh" ]; then
        log_error "init_redis_data.sh not found: $SCRIPT_DIR/init_redis_data.sh"
        exit 1
    fi
    
    # 执行Redis数据初始化脚本
    "$SCRIPT_DIR/init_redis_data.sh"
    
    if [ $? -eq 0 ]; then
        log_info "Redis data initialized successfully"
    else
        log_error "Failed to initialize Redis data"
        exit 1
    fi
}

# 显示当前配置
show_config() {
    echo ""
    log_info "Current Configuration:"
    echo "======================"
    echo "OPENRESTY_HOME: $OPENRESTY_HOME"
    echo "EXPRESS_HOME: $EXPRESS_HOME"
    echo "REDIS_HOST: $REDIS_HOST"
    echo "REDIS_PORT: $REDIS_PORT"
    echo "GATEWAY_PORT: $GATEWAY_PORT"
    echo "BACKEND_PORT: $BACKEND_PORT"
    echo "GATEWAY_ACCESS_LOG: $GATEWAY_ACCESS_LOG"
    echo "GATEWAY_ERROR_LOG: $GATEWAY_ERROR_LOG"
    echo "======================"
    echo ""
}

# 显示帮助信息
show_help() {
    echo "API Gateway Initialization Script"
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --config-only    Only update configuration files, do not initialize Redis data"
    echo "  --redis-only     Only initialize Redis data, do not update configuration files"
    echo "  --show-config    Show current configuration"
    echo "  --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0               # Update configuration and initialize Redis data"
    echo "  $0 --config-only # Only update configuration files"
    echo "  $0 --redis-only  # Only initialize Redis data"
}

# 主函数
main() {
    local config_only=false
    local redis_only=false
    local show_config_flag=false
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --config-only)
                config_only=true
                shift
                ;;
            --redis-only)
                redis_only=true
                shift
                ;;
            --show-config)
                show_config_flag=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    log_info "Starting API Gateway initialization..."
    
    # 加载配置
    load_env
    validate_config
    
    # 显示配置
    if [ "$show_config_flag" = true ]; then
        show_config
        exit 0
    fi
    
    # 更新配置文件
    if [ "$redis_only" = false ]; then
        update_api_gateway_conf
        update_redis_utils
        update_gm_cryptor_files
    fi
    
    # 初始化Redis数据
    if [ "$config_only" = false ]; then
        init_redis_data
    fi
    
    log_info "API Gateway initialization completed successfully!"
    log_info "Configuration files have been updated with values from .env"
    log_info "- API gateway configuration updated"
    log_info "- Redis configuration updated"
    log_info "- gmCryptor Lua files updated with OPENRESTY_HOME"
    log_info "Redis data has been initialized"
}

# 运行主函数
main "$@"