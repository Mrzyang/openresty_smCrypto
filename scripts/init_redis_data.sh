#!/bin/bash

# Redis数据初始化脚本
# 用于初始化API网关所需的Redis数据

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# 检查并加载.env文件
if [ -f "$PROJECT_DIR/.env" ]; then
    set -a
    source "$PROJECT_DIR/.env"
    set +a
    echo "[INFO] Loaded configuration from .env file"
else
    echo "[WARN] .env file not found, using default configuration"
    
    # 默认配置
    EXPRESS_HOME="/opt/zy/software/express"
    REDIS_HOST="192.168.56.2"
    REDIS_PORT="6379"
fi

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 检查Redis连接
check_redis() {
    if ! command -v redis-cli &> /dev/null; then
        log_error "redis-cli not found"
        log_info "Please install redis-tools: sudo apt install redis-tools"
        exit 1
    fi
    
    if ! redis-cli -h $REDIS_HOST -p $REDIS_PORT ping &> /dev/null; then
        log_error "Cannot connect to Redis at $REDIS_HOST:$REDIS_PORT"
        log_info "Please ensure Redis is running and accessible"
        exit 1
    fi
    
    log_info "Redis connection: OK"
}

# 检查Node.js环境
check_nodejs() {
    if ! command -v node &> /dev/null; then
        log_error "Node.js not found"
        log_info "Please install Node.js first"
        exit 1
    fi
    
    if [ ! -f "$EXPRESS_HOME/init_redis_data.js" ]; then
        log_error "init_redis_data.js not found in $EXPRESS_HOME"
        exit 1
    fi
    
    log_info "Node.js environment: OK"
}

# 清理现有数据
clear_existing_data() {
    log_info "Clearing existing data..."
    
    # 获取所有相关键
    local keys=$(redis-cli -h $REDIS_HOST -p $REDIS_PORT keys "app:*" 2>/dev/null)
    local api_keys=$(redis-cli -h $REDIS_HOST -p $REDIS_PORT keys "api:*" 2>/dev/null)
    local sub_keys=$(redis-cli -h $REDIS_HOST -p $REDIS_PORT keys "app_subscription:*" 2>/dev/null)
    local nonce_keys=$(redis-cli -h $REDIS_HOST -p $REDIS_PORT keys "nonce:*" 2>/dev/null)
    local log_keys=$(redis-cli -h $REDIS_HOST -p $REDIS_PORT keys "request_log:*" 2>/dev/null)
    
    local all_keys="$keys $api_keys $sub_keys $nonce_keys $log_keys"
    
    if [ -n "$all_keys" ]; then
        echo "$all_keys" | xargs redis-cli -h $REDIS_HOST -p $REDIS_PORT del &>/dev/null
        log_info "Cleared existing data"
    else
        log_info "No existing data to clear"
    fi
}

# 初始化数据
init_data() {
    log_info "Initializing Redis data..."
    
    cd "$EXPRESS_HOME"
    
    if [ ! -d "node_modules" ]; then
        log_info "Installing Node.js dependencies..."
        npm install
    fi
    
    # 运行初始化脚本
    node init_redis_data.js
    
    if [ $? -eq 0 ]; then
        log_info "Redis data initialized successfully"
    else
        log_error "Failed to initialize Redis data"
        exit 1
    fi
}

# 验证数据
verify_data() {
    log_info "Verifying initialized data..."
    
    # 检查App数据
    local app_count=$(redis-cli -h $REDIS_HOST -p $REDIS_PORT keys "app:*" | wc -l)
    log_info "App configurations: $app_count"
    
    # 检查API数据
    local api_count=$(redis-cli -h $REDIS_HOST -p $REDIS_PORT keys "api:*" | wc -l)
    log_info "API configurations: $api_count"
    
    # 检查订阅数据
    local sub_count=$(redis-cli -h $REDIS_HOST -p $REDIS_PORT keys "app_subscription:*" | wc -l)
    log_info "Subscription configurations: $sub_count"
    
    # 显示App信息
    echo ""
    log_info "App Information:"
    redis-cli -h $REDIS_HOST -p $REDIS_PORT keys "app:*" | while read key; do
        local app_data=$(redis-cli -h $REDIS_HOST -p $REDIS_PORT get "$key")
        local app_name=$(echo "$app_data" | grep -o '"name":"[^"]*"' | cut -d'"' -f4)
        local app_status=$(echo "$app_data" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
        echo "  $key: $app_name ($app_status)"
    done
    
    # 显示API信息
    echo ""
    log_info "API Information:"
    redis-cli -h $REDIS_HOST -p $REDIS_PORT keys "api:*" | while read key; do
        local api_data=$(redis-cli -h $REDIS_HOST -p $REDIS_PORT get "$key")
        local api_name=$(echo "$api_data" | grep -o '"name":"[^"]*"' | cut -d'"' -f4)
        local api_path=$(echo "$api_data" | grep -o '"path":"[^"]*"' | cut -d'"' -f4)
        local api_method=$(echo "$api_data" | grep -o '"method":"[^"]*"' | cut -d'"' -f4)
        echo "  $key: $api_name ($api_method $api_path)"
    done
}

# 显示帮助
show_help() {
    echo "Redis Data Initialization Script"
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --clear-only    Only clear existing data, do not initialize"
    echo "  --verify-only   Only verify existing data, do not initialize"
    echo "  --help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                    # Clear and initialize data"
    echo "  $0 --clear-only       # Only clear existing data"
    echo "  $0 --verify-only      # Only verify existing data"
}

# 主函数
main() {
    local clear_only=false
    local verify_only=false
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --clear-only)
                clear_only=true
                shift
                ;;
            --verify-only)
                verify_only=true
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
    
    log_info "Starting Redis data initialization..."
    
    check_redis
    check_nodejs
    
    if [ "$verify_only" = true ]; then
        verify_data
    else
        clear_existing_data
        
        if [ "$clear_only" = false ]; then
            init_data
            verify_data
        fi
    fi
    
    log_info "Redis data initialization completed!"
}

# 运行主函数
main "$@"
