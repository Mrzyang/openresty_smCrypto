#!/bin/bash

# API网关停止脚本
# 用于停止API网关服务

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

# 停止后端服务
stop_backend() {
    log_info "Stopping backend service..."
    
    if [ -f "$EXPRESS_HOME/backend.pid" ]; then
        local backend_pid=$(cat "$EXPRESS_HOME/backend.pid")
        if ps -p $backend_pid > /dev/null 2>&1; then
            kill -TERM $backend_pid
            
            # 等待进程停止
            local count=0
            while ps -p $backend_pid > /dev/null 2>&1 && [ $count -lt 10 ]; do
                sleep 1
                count=$((count + 1))
            done
            
            if ps -p $backend_pid > /dev/null 2>&1; then
                log_warn "Graceful stop failed, forcing kill"
                kill -9 $backend_pid
            fi
            
            log_info "Backend service stopped"
        else
            log_warn "Backend service is not running"
        fi
        
        rm -f "$EXPRESS_HOME/backend.pid"
    else
        log_warn "Backend PID file not found"
    fi
}

# 停止网关服务
stop_gateway() {
    log_info "Stopping gateway service..."
    
    # 查找nginx进程
    local nginx_pids=$(pgrep -f "nginx.*$OPENRESTY_HOME")
    
    if [ -n "$nginx_pids" ]; then
        # 优雅停止
        "$OPENRESTY_HOME/bin/openresty" -s quit -c "$OPENRESTY_HOME/nginx/conf/nginx.conf" 2>/dev/null
        
        # 等待进程停止
        sleep 3
        
        # 检查是否还有进程
        nginx_pids=$(pgrep -f "nginx.*$OPENRESTY_HOME")
        if [ -n "$nginx_pids" ]; then
            log_warn "Graceful stop failed, forcing kill"
            kill -9 $nginx_pids
        fi
        
        log_info "Gateway service stopped"
    else
        log_warn "Gateway service is not running"
    fi
}

# 清理端口占用
cleanup_ports() {
    log_info "Cleaning up port usage..."
    
    # 清理后端端口
    local backend_pids=$(lsof -ti:$BACKEND_PORT 2>/dev/null)
    if [ -n "$backend_pids" ]; then
        log_warn "Killing processes on port $BACKEND_PORT: $backend_pids"
        kill -9 $backend_pids
    fi
    
    # 清理网关端口
    local gateway_pids=$(lsof -ti:$GATEWAY_PORT 2>/dev/null)
    if [ -n "$gateway_pids" ]; then
        log_warn "Killing processes on port $GATEWAY_PORT: $gateway_pids"
        kill -9 $gateway_pids
    fi
}

# 显示状态
show_status() {
    log_info "Service Status:"
    echo "=================="
    
    # 检查后端服务
    if [ -f "$EXPRESS_HOME/backend.pid" ]; then
        local backend_pid=$(cat "$EXPRESS_HOME/backend.pid")
        if ps -p $backend_pid > /dev/null 2>&1; then
            echo -e "Backend: ${YELLOW}Still Running${NC} (PID: $backend_pid)"
        else
            echo -e "Backend: ${GREEN}Stopped${NC}"
        fi
    else
        echo -e "Backend: ${GREEN}Stopped${NC}"
    fi
    
    # 检查网关服务
    if netstat -tlnp 2>/dev/null | grep -q ":$GATEWAY_PORT "; then
        echo -e "Gateway: ${YELLOW}Still Running${NC} (Port: $GATEWAY_PORT)"
    else
        echo -e "Gateway: ${GREEN}Stopped${NC}"
    fi
    
    echo "=================="
}

# 主函数
main() {
    log_info "Stopping API Gateway..."
    
    stop_backend
    stop_gateway
    cleanup_ports
    show_status
    
    log_info "API Gateway stopped successfully!"
}

# 运行主函数
main "$@"
