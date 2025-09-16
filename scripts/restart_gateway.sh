#!/bin/bash

# API网关重启脚本
# 用于重启API网关服务

# 配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 主函数
main() {
    log_info "Restarting API Gateway..."
    
    # 停止服务
    log_info "Stopping services..."
    "$SCRIPT_DIR/stop_gateway.sh"
    
    # 等待一下
    sleep 2
    
    # 启动服务
    log_info "Starting services..."
    "$SCRIPT_DIR/start_gateway.sh"
    
    log_info "API Gateway restarted successfully!"
}

# 运行主函数
main "$@"
