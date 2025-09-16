#!/bin/bash

# API网关测试脚本
# 用于测试API网关功能

# 配置
GATEWAY_URL="http://localhost:8082"
BACKEND_URL="http://localhost:3000"
REDIS_HOST="192.168.110.45"
REDIS_PORT="6379"

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

# 检查服务状态
check_services() {
    log_test "Checking service status..."
    
    # 检查后端服务
    if curl -s "$BACKEND_URL/health" &> /dev/null; then
        log_info "Backend service: OK"
    else
        log_error "Backend service: FAILED"
        return 1
    fi
    
    # 检查网关服务
    if curl -s "$GATEWAY_URL/health" &> /dev/null; then
        log_info "Gateway service: OK"
    else
        log_error "Gateway service: FAILED"
        return 1
    fi
    
    # 检查Redis连接
    if command -v redis-cli &> /dev/null; then
        if redis-cli -h $REDIS_HOST -p $REDIS_PORT ping &> /dev/null; then
            log_info "Redis connection: OK"
        else
            log_error "Redis connection: FAILED"
            return 1
        fi
    else
        log_warn "redis-cli not found, skipping Redis check"
    fi
}

# 测试健康检查
test_health_check() {
    log_test "Testing health check endpoints..."
    
    # 测试后端健康检查
    echo "Backend health check:"
    curl -s "$BACKEND_URL/health" | jq . 2>/dev/null || curl -s "$BACKEND_URL/health"
    echo ""
    
    # 测试网关健康检查
    echo "Gateway health check:"
    curl -s "$GATEWAY_URL/health" | jq . 2>/dev/null || curl -s "$GATEWAY_URL/health"
    echo ""
}

# 测试管理接口
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
    
    # 测试获取订阅信息
    echo "Testing subscription info API:"
    curl -s "$GATEWAY_URL/admin/subscriptions?appid=app_001" | jq . 2>/dev/null || curl -s "$GATEWAY_URL/admin/subscriptions?appid=app_001"
    echo ""
}

# 测试API调用（需要签名）
test_api_calls() {
    log_test "Testing API calls through gateway..."
    
    # 检查是否有测试客户端
    if [ -f "/opt/zy/software/express/test_client.js" ]; then
        log_info "Running test client..."
        cd /opt/zy/software/express
        node test_client.js test
    else
        log_warn "Test client not found, skipping API call tests"
        log_info "You can run the test client manually:"
        log_info "  cd /opt/zy/software/express"
        log_info "  node test_client.js test"
    fi
}

# 测试错误处理
test_error_handling() {
    log_test "Testing error handling..."
    
    # 测试不存在的API
    echo "Testing non-existent API:"
    curl -s "$GATEWAY_URL/api/nonexistent" | jq . 2>/dev/null || curl -s "$GATEWAY_URL/api/nonexistent"
    echo ""
    
    # 测试无效的请求头
    echo "Testing invalid headers:"
    curl -s -H "X-App-ID: invalid" "$GATEWAY_URL/api/user/info" | jq . 2>/dev/null || curl -s -H "X-App-ID: invalid" "$GATEWAY_URL/api/user/info"
    echo ""
}

# 性能测试
performance_test() {
    log_test "Running performance test..."
    
    if command -v ab &> /dev/null; then
        echo "Running Apache Bench test (100 requests, 10 concurrent):"
        ab -n 100 -c 10 "$GATEWAY_URL/health" 2>/dev/null | grep -E "(Requests per second|Time per request|Failed requests)"
    else
        log_warn "Apache Bench not found, skipping performance test"
        log_info "Install with: sudo apt install apache2-utils"
    fi
}

# 显示系统信息
show_system_info() {
    log_test "System Information:"
    echo "===================="
    echo "Gateway URL: $GATEWAY_URL"
    echo "Backend URL: $BACKEND_URL"
    echo "Redis: $REDIS_HOST:$REDIS_PORT"
    echo "OpenResty: /opt/zy/software/openresty"
    echo "Express: /opt/zy/software/express"
    echo "===================="
}

# 显示帮助
show_help() {
    echo "API Gateway Test Script"
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --health-only     Only test health check endpoints"
    echo "  --admin-only      Only test admin APIs"
    echo "  --api-only        Only test API calls"
    echo "  --error-only      Only test error handling"
    echo "  --perf-only       Only run performance test"
    echo "  --info-only       Only show system information"
    echo "  --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                    # Run all tests"
    echo "  $0 --health-only      # Only test health checks"
    echo "  $0 --api-only         # Only test API calls"
}

# 主函数
main() {
    local health_only=false
    local admin_only=false
    local api_only=false
    local error_only=false
    local perf_only=false
    local info_only=false
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --health-only)
                health_only=true
                shift
                ;;
            --admin-only)
                admin_only=true
                shift
                ;;
            --api-only)
                api_only=true
                shift
                ;;
            --error-only)
                error_only=true
                shift
                ;;
            --perf-only)
                perf_only=true
                shift
                ;;
            --info-only)
                info_only=true
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
    
    log_info "Starting API Gateway tests..."
    echo "================================"
    
    if [ "$info_only" = true ]; then
        show_system_info
        exit 0
    fi
    
    # 检查服务状态
    if ! check_services; then
        log_error "Service check failed, please start the services first"
        exit 1
    fi
    
    echo ""
    
    # 运行测试
    if [ "$health_only" = true ] || [ "$health_only" = false ] && [ "$admin_only" = false ] && [ "$api_only" = false ] && [ "$error_only" = false ] && [ "$perf_only" = false ]; then
        test_health_check
        echo ""
    fi
    
    if [ "$admin_only" = true ] || [ "$admin_only" = false ] && [ "$health_only" = false ] && [ "$api_only" = false ] && [ "$error_only" = false ] && [ "$perf_only" = false ]; then
        test_admin_apis
        echo ""
    fi
    
    if [ "$api_only" = true ] || [ "$api_only" = false ] && [ "$health_only" = false ] && [ "$admin_only" = false ] && [ "$error_only" = false ] && [ "$perf_only" = false ]; then
        test_api_calls
        echo ""
    fi
    
    if [ "$error_only" = true ] || [ "$error_only" = false ] && [ "$health_only" = false ] && [ "$admin_only" = false ] && [ "$api_only" = false ] && [ "$perf_only" = false ]; then
        test_error_handling
        echo ""
    fi
    
    if [ "$perf_only" = true ] || [ "$perf_only" = false ] && [ "$health_only" = false ] && [ "$admin_only" = false ] && [ "$api_only" = false ] && [ "$error_only" = false ]; then
        performance_test
        echo ""
    fi
    
    log_info "API Gateway tests completed!"
}

# 运行主函数
main "$@"
