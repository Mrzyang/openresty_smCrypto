#!/bin/bash

# API网关启动脚本
# 用于启动基于已编译OpenResty的API网关

# 配置
OPENRESTY_HOME="/opt/zy/software/openresty"
EXPRESS_HOME="/opt/zy/software/express"
REDIS_HOST="192.168.56.2"
REDIS_PORT="6379"
GATEWAY_PORT="8082"
BACKEND_PORT="3000"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 检查目录是否存在
check_directories() {
    if [ ! -d "$OPENRESTY_HOME" ]; then
        log_error "OpenResty directory not found: $OPENRESTY_HOME"
        exit 1
    fi
    
    if [ ! -d "$EXPRESS_HOME" ]; then
        log_error "Express directory not found: $EXPRESS_HOME"
        exit 1
    fi
    
    if [ ! -f "$OPENRESTY_HOME/bin/openresty" ]; then
        log_error "OpenResty binary not found: $OPENRESTY_HOME/bin/openresty"
        exit 1
    fi
    
    if [ ! -f "$EXPRESS_HOME/index.js" ]; then
        log_error "Express app not found: $EXPRESS_HOME/index.js"
        exit 1
    fi
}

# 检查端口是否被占用
check_ports() {
    if netstat -tlnp 2>/dev/null | grep -q ":$GATEWAY_PORT "; then
        log_error "Port $GATEWAY_PORT is already in use"
        exit 1
    fi
    
    if netstat -tlnp 2>/dev/null | grep -q ":$BACKEND_PORT "; then
        log_error "Port $BACKEND_PORT is already in use"
        exit 1
    fi
}

# 检查Redis连接
check_redis() {
    if command -v redis-cli &> /dev/null; then
        if ! redis-cli -h $REDIS_HOST -p $REDIS_PORT ping &> /dev/null; then
            log_error "Cannot connect to Redis at $REDIS_HOST:$REDIS_PORT"
            log_info "Please ensure Redis is running and accessible"
            exit 1
        fi
        log_info "Redis connection: OK"
    else
        log_warn "redis-cli not found, skipping Redis check"
    fi
}

# 安装依赖
install_dependencies() {
    log_info "Installing dependencies..."
    
    cd "$EXPRESS_HOME"
    
    # 检查Node.js依赖
    if [ ! -d "node_modules" ]; then
        log_info "Installing Node.js dependencies..."
        npm install
        
        if [ $? -ne 0 ]; then
            log_error "Failed to install dependencies"
            exit 1
        fi
    else
        log_info "Dependencies already installed"
    fi
}

# 启动后端服务
start_backend() {
    log_info "Starting backend service..."
    
    cd "$EXPRESS_HOME"
    
    # 启动后端服务
    nohup node index.js > "$EXPRESS_HOME/backend.log" 2>&1 &
    echo $! > "$EXPRESS_HOME/backend.pid"
    
    # 等待服务启动
    sleep 3
    
    if ps -p $(cat "$EXPRESS_HOME/backend.pid") > /dev/null 2>&1; then
        log_info "Backend service started (PID: $(cat $EXPRESS_HOME/backend.pid))"
    else
        log_error "Failed to start backend service"
        exit 1
    fi
}

# 启动网关服务
start_gateway() {
    log_info "Starting gateway service..."
    
    # 检查配置
    if ! "$OPENRESTY_HOME/bin/openresty" -t -c "$OPENRESTY_HOME/nginx/conf/nginx.conf"; then
        log_error "Nginx configuration error"
        exit 1
    fi
    
    # 启动网关
    "$OPENRESTY_HOME/bin/openresty" -c "$OPENRESTY_HOME/nginx/conf/nginx.conf"
    
    sleep 2
    
    if netstat -tlnp 2>/dev/null | grep -q ":$GATEWAY_PORT "; then
        log_info "Gateway service started on port $GATEWAY_PORT"
    else
        log_error "Failed to start gateway service"
        exit 1
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
            echo -e "Backend: ${GREEN}Running${NC} (PID: $backend_pid)"
        else
            echo -e "Backend: ${RED}Not Running${NC}"
        fi
    else
        echo -e "Backend: ${RED}Not Running${NC}"
    fi
    
    # 检查网关服务
    if netstat -tlnp 2>/dev/null | grep -q ":$GATEWAY_PORT "; then
        echo -e "Gateway: ${GREEN}Running${NC} (Port: $GATEWAY_PORT)"
    else
        echo -e "Gateway: ${RED}Not Running${NC}"
    fi
    
    # 检查健康状态
    if curl -s http://localhost:$GATEWAY_PORT/health &> /dev/null; then
        echo -e "Health Check: ${GREEN}OK${NC}"
    else
        echo -e "Health Check: ${RED}Failed${NC}"
    fi
    
    echo "=================="
}

# 主函数
main() {
    log_info "Starting API Gateway..."
    
    check_directories
    check_ports
    check_redis
    install_dependencies
    start_backend
    start_gateway
    show_status
    
    log_info "API Gateway started successfully!"
    log_info "Gateway URL: http://localhost:$GATEWAY_PORT"
    log_info "Backend URL: http://localhost:$BACKEND_PORT"
    log_info "Health Check: http://localhost:$GATEWAY_PORT/health"
}

# 运行主函数
main "$@"
