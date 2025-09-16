#!/bin/bash

# 连接测试脚本
# 用于测试API网关连接

# 配置
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
log_test() { echo -e "${BLUE}[TEST]${NC} $1"; }

# 测试后端连接
test_backend() {
    log_test "Testing backend connection..."
    
    local response=$(curl -s -w "HTTPSTATUS:%{http_code}" "$BACKEND_URL/health" 2>/dev/null)
    local http_code=$(echo "$response" | grep -o "HTTPSTATUS:[0-9]*" | cut -d: -f2)
    local body=$(echo "$response" | sed 's/HTTPSTATUS:[0-9]*$//')
    
    if [ "$http_code" = "200" ]; then
        log_info "Backend connection: OK"
        echo "Response: $body"
        return 0
    else
        log_error "Backend connection: FAILED (HTTP $http_code)"
        echo "Response: $body"
        return 1
    fi
}

# 测试网关连接
test_gateway() {
    log_test "Testing gateway connection..."
    
    local response=$(curl -s -w "HTTPSTATUS:%{http_code}" "$GATEWAY_URL/health" 2>/dev/null)
    local http_code=$(echo "$response" | grep -o "HTTPSTATUS:[0-9]*" | cut -d: -f2)
    local body=$(echo "$response" | sed 's/HTTPSTATUS:[0-9]*$//')
    
    if [ "$http_code" = "200" ]; then
        log_info "Gateway connection: OK"
        echo "Response: $body"
        return 0
    else
        log_error "Gateway connection: FAILED (HTTP $http_code)"
        echo "Response: $body"
        return 1
    fi
}

# 测试端口监听
test_ports() {
    log_test "Testing port listening..."
    
    if netstat -tlnp 2>/dev/null | grep -q ":3000 "; then
        log_info "Port 3000: Listening"
    else
        log_error "Port 3000: Not listening"
        return 1
    fi
    
    if netstat -tlnp 2>/dev/null | grep -q ":8082 "; then
        log_info "Port 8082: Listening"
    else
        log_error "Port 8082: Not listening"
        return 1
    fi
    
    return 0
}

# 测试管理API
test_admin_apis() {
    log_test "Testing admin APIs..."
    
    # 测试获取App信息
    echo "Testing app info API:"
    curl -s "$GATEWAY_URL/admin/app?appid=app_001" | jq . 2>/dev/null || curl -s "$GATEWAY_URL/admin/app?appid=app_001"
    echo ""
    
    # 测试获取API信息
    echo "Testing API info API:"
    curl -s "$GATEWAY_URL/admin/api?api_id=api_001" | jq . 2>/dev/null || curl -s "$GATEWAY_URL/admin/api?api_id=api_001"
    echo ""
}

# 测试API调用（带签名）
test_api_with_signature() {
    log_test "Testing API call with signature..."
    
    # 简单的测试请求
    local appid="app_001"
    local nonce="1234567890"
    local timestamp=$(date +%s)
    local method="GET"
    local uri="/api/user/info"
    local body=""
    
    # 构建签名数据
    local signature_data="${method}&${uri}&&${body}&${nonce}&${timestamp}"
    
    echo "Signature data: $signature_data"
    echo "Making request to: $GATEWAY_URL$uri"
    
    # 发送请求
    local response=$(curl -s -w "HTTPSTATUS:%{http_code}" \
        -H "X-App-ID: $appid" \
        -H "X-Signature: test_signature" \
        -H "X-Nonce: $nonce" \
        -H "X-Timestamp: $timestamp" \
        -H "Content-Type: application/json" \
        "$GATEWAY_URL$uri" 2>/dev/null)
    
    local http_code=$(echo "$response" | grep -o "HTTPSTATUS:[0-9]*" | cut -d: -f2)
    local body=$(echo "$response" | sed 's/HTTPSTATUS:[0-9]*$//')
    
    echo "Response (HTTP $http_code): $body"
    
    if [ "$http_code" = "400" ] || [ "$http_code" = "401" ]; then
        log_info "API call test: Expected error (signature validation)"
        return 0
    else
        log_warn "API call test: Unexpected response"
        return 1
    fi
}

# 显示网络信息
show_network_info() {
    log_test "Network information:"
    echo "Gateway URL: $GATEWAY_URL"
    echo "Backend URL: $BACKEND_URL"
    echo ""
    
    # 显示端口信息
    echo "Port 3000 processes:"
    netstat -tlnp 2>/dev/null | grep ":3000 " || echo "  No processes on port 3000"
    echo ""
    
    echo "Port 8082 processes:"
    netstat -tlnp 2>/dev/null | grep ":8082 " || echo "  No processes on port 8082"
    echo ""
}

# 主函数
main() {
    log_info "Starting connection tests..."
    echo "================================"
    
    local tests_passed=0
    local tests_total=0
    
    # 显示网络信息
    show_network_info
    
    # 运行测试
    tests_total=$((tests_total + 1))
    if test_ports; then
        tests_passed=$((tests_passed + 1))
    fi
    echo ""
    
    tests_total=$((tests_total + 1))
    if test_backend; then
        tests_passed=$((tests_passed + 1))
    fi
    echo ""
    
    tests_total=$((tests_total + 1))
    if test_gateway; then
        tests_passed=$((tests_passed + 1))
    fi
    echo ""
    
    test_admin_apis
    echo ""
    
    test_api_with_signature
    echo ""
    
    echo "================================"
    log_info "Test Results: $tests_passed/$tests_total tests passed"
    
    if [ $tests_passed -eq $tests_total ]; then
        log_info "All connection tests passed!"
        return 0
    else
        log_error "Some connection tests failed."
        return 1
    fi
}

# 运行主函数
main "$@"
