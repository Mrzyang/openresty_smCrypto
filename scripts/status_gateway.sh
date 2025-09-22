#!/bin/bash

# API网关状态检查脚本
# 用于检查API网关服务状态

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
    OPENRESTY_HOME="/opt/zy/software/openresty"
    EXPRESS_HOME="/opt/zy/software/express"
    GATEWAY_PORT="8082"
    BACKEND_PORT="3000"
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

# 检查后端服务状态
check_backend() {
    if [ -f "$EXPRESS_HOME/backend.pid" ]; then
        local backend_pid=$(cat "$EXPRESS_HOME/backend.pid")
        if ps -p $backend_pid > /dev/null 2>&1; then
            echo -e "Backend: ${GREEN}Running${NC} (PID: $backend_pid)"
            
            # 检查端口
            if netstat -tlnp 2>/dev/null | grep -q ":$BACKEND_PORT "; then
                echo -e "  Port $BACKEND_PORT: ${GREEN}Listening${NC}"
            else
                echo -e "  Port $BACKEND_PORT: ${RED}Not Listening${NC}"
            fi
            
            # 检查健康状态
            if curl -s http://localhost:$BACKEND_PORT/health &> /dev/null; then
                echo -e "  Health Check: ${GREEN}OK${NC}"
            else
                echo -e "  Health Check: ${RED}Failed${NC}"
            fi
            
            return 0
        else
            echo -e "Backend: ${RED}Not Running${NC} (stale PID file)"
            return 1
        fi
    else
        echo -e "Backend: ${RED}Not Running${NC} (no PID file)"
        return 1
    fi
}

# 检查网关服务状态
check_gateway() {
    if netstat -tlnp 2>/dev/null | grep -q ":$GATEWAY_PORT "; then
        echo -e "Gateway: ${GREEN}Running${NC} (Port: $GATEWAY_PORT)"
        
        # 检查健康状态
        if curl -s http://localhost:$GATEWAY_PORT/health &> /dev/null; then
            echo -e "  Health Check: ${GREEN}OK${NC}"
        else
            echo -e "  Health Check: ${RED}Failed${NC}"
        fi
        
        return 0
    else
        echo -e "Gateway: ${RED}Not Running${NC}"
        return 1
    fi
}

# 检查Redis连接
check_redis() {
    if command -v redis-cli &> /dev/null; then
        if redis-cli -h $REDIS_HOST -p $REDIS_PORT ping &> /dev/null; then
            echo -e "Redis: ${GREEN}Connected${NC} ($REDIS_HOST:$REDIS_PORT)"
            return 0
        else
            echo -e "Redis: ${RED}Disconnected${NC} ($REDIS_HOST:$REDIS_PORT)"
            return 1
        fi
    else
        echo -e "Redis: ${YELLOW}redis-cli not available${NC}"
        return 0
    fi
}

# 检查系统资源
check_system_resources() {
    echo -e "System Resources:"
    
    # 内存使用
    local memory_usage=$(free -h | awk '/^Mem:/{print $3 "/" $2}')
    echo -e "  Memory: ${BLUE}$memory_usage${NC}"
    
    # 磁盘使用
    local disk_usage=$(df -h / | awk 'NR==2{print $3 "/" $2 " (" $5 ")"}')
    echo -e "  Disk: ${BLUE}$disk_usage${NC}"
    
    # 负载
    local load_avg=$(uptime | awk -F'load average:' '{print $2}')
    echo -e "  Load: ${BLUE}$load_avg${NC}"
}

# 检查日志文件
check_logs() {
    echo -e "Log Files:"
    
    # 后端日志
    if [ -f "$EXPRESS_HOME/backend.log" ]; then
        local backend_log_size=$(du -h "$EXPRESS_HOME/backend.log" | cut -f1)
        echo -e "  Backend Log: ${BLUE}$backend_log_size${NC} ($EXPRESS_HOME/backend.log)"
    else
        echo -e "  Backend Log: ${YELLOW}Not found${NC}"
    fi
    
    # 网关日志
    if [ -f "$OPENRESTY_HOME/nginx/logs/api_gateway_access.log" ]; then
        local gateway_access_size=$(du -h "$OPENRESTY_HOME/nginx/logs/api_gateway_access.log" | cut -f1)
        echo -e "  Gateway Access Log: ${BLUE}$gateway_access_size${NC}"
    else
        echo -e "  Gateway Access Log: ${YELLOW}Not found${NC}"
    fi
    
    if [ -f "$OPENRESTY_HOME/nginx/logs/api_gateway_error.log" ]; then
        local gateway_error_size=$(du -h "$OPENRESTY_HOME/nginx/logs/api_gateway_error.log" | cut -f1)
        echo -e "  Gateway Error Log: ${BLUE}$gateway_error_size${NC}"
    else
        echo -e "  Gateway Error Log: ${YELLOW}Not found${NC}"
    fi
}

# 显示最近错误
show_recent_errors() {
    echo -e "Recent Errors:"
    
    # 后端错误
    if [ -f "$EXPRESS_HOME/backend.log" ]; then
        local backend_errors=$(grep -i error "$EXPRESS_HOME/backend.log" | tail -3)
        if [ -n "$backend_errors" ]; then
            echo -e "  Backend Errors:"
            echo "$backend_errors" | sed 's/^/    /'
        else
            echo -e "  Backend Errors: ${GREEN}None${NC}"
        fi
    fi
    
    # 网关错误
    if [ -f "$OPENRESTY_HOME/nginx/logs/api_gateway_error.log" ]; then
        local gateway_errors=$(grep -i error "$OPENRESTY_HOME/nginx/logs/api_gateway_error.log" | tail -3)
        if [ -n "$gateway_errors" ]; then
            echo -e "  Gateway Errors:"
            echo "$gateway_errors" | sed 's/^/    /'
        else
            echo -e "  Gateway Errors: ${GREEN}None${NC}"
        fi
    fi
}

# 主函数
main() {
    echo "API Gateway Status Report"
    echo "========================="
    echo "Timestamp: $(date)"
    echo ""
    
    # 检查服务状态
    echo "Service Status:"
    echo "---------------"
    local backend_ok=0
    local gateway_ok=0
    local redis_ok=0
    
    if check_backend; then
        backend_ok=1
    fi
    echo ""
    
    if check_gateway; then
        gateway_ok=1
    fi
    echo ""
    
    if check_redis; then
        redis_ok=1
    fi
    echo ""
    
    # 检查系统资源
    check_system_resources
    echo ""
    
    # 检查日志文件
    check_logs
    echo ""
    
    # 显示最近错误
    show_recent_errors
    echo ""
    
    # 总结
    echo "Summary:"
    echo "--------"
    if [ $backend_ok -eq 1 ] && [ $gateway_ok -eq 1 ] && [ $redis_ok -eq 1 ]; then
        echo -e "Overall Status: ${GREEN}All services running normally${NC}"
        exit 0
    else
        echo -e "Overall Status: ${RED}Some services have issues${NC}"
        exit 1
    fi
}

# 运行主函数
main "$@"
