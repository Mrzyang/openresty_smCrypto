#!/bin/bash

# 修复测试问题脚本
# 用于修复API网关测试问题

# 配置
EXPRESS_HOME="/opt/zy/software/express"
OPENRESTY_HOME="/opt/zy/software/openresty"
GATEWAY_URL="http://localhost:8082"
BACKEND_URL="http://localhost:3000"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 检查服务状态
check_services() {
    log_info "Checking service status..."
    
    # 检查后端服务
    if curl -s "$BACKEND_URL/health" &> /dev/null; then
        log_info "Backend service: Running"
    else
        log_error "Backend service: Not running"
        return 1
    fi
    
    # 检查网关服务
    if curl -s "$GATEWAY_URL/health" &> /dev/null; then
        log_info "Gateway service: Running"
    else
        log_error "Gateway service: Not running"
        return 1
    fi
    
    return 0
}

# 安装axios依赖
install_axios() {
    log_info "Installing axios dependency..."
    
    cd "$EXPRESS_HOME"
    
    if ! npm list axios &> /dev/null; then
        log_info "Installing axios..."
        npm install axios
        
        if [ $? -eq 0 ]; then
            log_info "Axios installed successfully"
        else
            log_error "Failed to install axios"
            return 1
        fi
    else
        log_info "Axios already installed"
    fi
    
    return 0
}

# 测试网关连接
test_gateway_connection() {
    log_info "Testing gateway connection..."
    
    # 测试健康检查
    local health_response=$(curl -s "$GATEWAY_URL/health")
    if [ $? -eq 0 ]; then
        log_info "Health check: OK"
        echo "Response: $health_response"
    else
        log_error "Health check: FAILED"
        return 1
    fi
    
    # 测试管理API
    local app_response=$(curl -s "$GATEWAY_URL/admin/app?appid=app_001")
    if [ $? -eq 0 ]; then
        log_info "Admin API: OK"
        echo "App info: $app_response"
    else
        log_error "Admin API: FAILED"
        return 1
    fi
    
    return 0
}

# 测试API调用
test_api_call() {
    log_info "Testing API call..."
    
    # 测试不带签名的API调用（应该返回错误）
    local response=$(curl -s -w "HTTPSTATUS:%{http_code}" "$GATEWAY_URL/api/user/info" 2>/dev/null)
    local http_code=$(echo "$response" | grep -o "HTTPSTATUS:[0-9]*" | cut -d: -f2)
    local body=$(echo "$response" | sed 's/HTTPSTATUS:[0-9]*$//')
    
    if [ "$http_code" = "400" ]; then
        log_info "API call test: OK (expected error for missing headers)"
        echo "Response: $body"
    else
        log_warn "API call test: Unexpected response (HTTP $http_code)"
        echo "Response: $body"
    fi
    
    return 0
}

# 运行Node.js测试客户端
run_node_test() {
    log_info "Running Node.js test client..."
    
    cd "$EXPRESS_HOME"
    
    if [ -f "test_client.js" ]; then
        log_info "Running test client..."
        timeout 30 node test_client.js test 2>&1 | head -50
    else
        log_error "Test client not found"
        return 1
    fi
    
    return 0
}

# 检查端口占用
check_ports() {
    log_info "Checking port usage..."
    
    echo "Port 3000:"
    netstat -tlnp 2>/dev/null | grep ":3000 " || echo "  Not listening"
    
    echo "Port 8082:"
    netstat -tlnp 2>/dev/null | grep ":8082 " || echo "  Not listening"
    
    echo ""
}

# 显示日志
show_logs() {
    log_info "Recent logs:"
    
    echo "Backend logs (last 10 lines):"
    if [ -f "$EXPRESS_HOME/backend.log" ]; then
        tail -10 "$EXPRESS_HOME/backend.log"
    else
        echo "  No backend log found"
    fi
    
    echo ""
    echo "Gateway error logs (last 10 lines):"
    if [ -f "$OPENRESTY_HOME/nginx/logs/api_gateway_error.log" ]; then
        tail -10 "$OPENRESTY_HOME/nginx/logs/api_gateway_error.log"
    else
        echo "  No gateway error log found"
    fi
    
    echo ""
}

# 主函数
main() {
    log_info "Starting test issue fix..."
    echo "=============================="
    
    # 检查服务状态
    if ! check_services; then
        log_error "Services are not running properly"
        log_info "Please start the services first:"
        log_info "  ./start_gateway.sh"
        exit 1
    fi
    
    echo ""
    
    # 安装axios依赖
    install_axios
    
    echo ""
    
    # 检查端口
    check_ports
    
    # 测试网关连接
    test_gateway_connection
    
    echo ""
    
    # 测试API调用
    test_api_call
    
    echo ""
    
    # 显示日志
    show_logs
    
    echo ""
    
    # 运行Node.js测试
    log_info "Running Node.js test client..."
    run_node_test
    
    echo ""
    log_info "Test issue fix completed!"
    log_info "If issues persist, check the logs above for more details."
}

# 运行主函数
main "$@"
