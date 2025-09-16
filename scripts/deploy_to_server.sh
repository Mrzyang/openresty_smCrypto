#!/bin/bash

# 部署脚本 - 将代码部署到Debian12服务器
# 在Windows上运行，将文件上传到服务器

# 配置
SERVER_USER="root"  # 修改为你的服务器用户名
SERVER_HOST="192.168.110.45"  # 修改为你的服务器IP
SERVER_OPENRESTY_PATH="/opt/zy/software/openresty"
SERVER_EXPRESS_PATH="/opt/zy/software/express"
SERVER_SCRIPTS_PATH="/opt/zy/software/scripts"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 检查必要工具
check_tools() {
    if ! command -v scp &> /dev/null; then
        log_error "scp not found, please install OpenSSH client"
        exit 1
    fi
    
    if ! command -v ssh &> /dev/null; then
        log_error "ssh not found, please install OpenSSH client"
        exit 1
    fi
}

# 创建服务器目录
create_server_dirs() {
    log_info "Creating server directories..."
    
    ssh $SERVER_USER@$SERVER_HOST "mkdir -p $SERVER_OPENRESTY_PATH $SERVER_EXPRESS_PATH $SERVER_SCRIPTS_PATH"
    
    if [ $? -eq 0 ]; then
        log_info "Server directories created"
    else
        log_error "Failed to create server directories"
        exit 1
    fi
}

# 上传OpenResty文件
upload_openresty() {
    log_info "Uploading OpenResty files..."
    
    if [ ! -d "openresty" ]; then
        log_error "OpenResty directory not found"
        exit 1
    fi
    
    scp -r openresty/* $SERVER_USER@$SERVER_HOST:$SERVER_OPENRESTY_PATH/
    
    if [ $? -eq 0 ]; then
        log_info "OpenResty files uploaded"
    else
        log_error "Failed to upload OpenResty files"
        exit 1
    fi
}

# 上传Express文件
upload_express() {
    log_info "Uploading Express files..."
    
    if [ ! -d "express" ]; then
        log_error "Express directory not found"
        exit 1
    fi
    
    scp -r express/* $SERVER_USER@$SERVER_HOST:$SERVER_EXPRESS_PATH/
    
    if [ $? -eq 0 ]; then
        log_info "Express files uploaded"
    else
        log_error "Failed to upload Express files"
        exit 1
    fi
}

# 上传脚本文件
upload_scripts() {
    log_info "Uploading script files..."
    
    if [ ! -d "scripts" ]; then
        log_error "Scripts directory not found"
        exit 1
    fi
    
    scp -r scripts/* $SERVER_USER@$SERVER_HOST:$SERVER_SCRIPTS_PATH/
    
    if [ $? -eq 0 ]; then
        log_info "Script files uploaded"
    else
        log_error "Failed to upload script files"
        exit 1
    fi
}

# 设置权限
set_permissions() {
    log_info "Setting permissions..."
    
    ssh $SERVER_USER@$SERVER_HOST "chmod +x $SERVER_SCRIPTS_PATH/*.sh"
    
    if [ $? -eq 0 ]; then
        log_info "Permissions set"
    else
        log_error "Failed to set permissions"
        exit 1
    fi
}

# 安装依赖
install_dependencies() {
    log_info "Installing dependencies..."
    
    ssh $SERVER_USER@$SERVER_HOST "cd $SERVER_EXPRESS_PATH && npm install"
    
    if [ $? -eq 0 ]; then
        log_info "Dependencies installed"
    else
        log_error "Failed to install dependencies"
        exit 1
    fi
}

# 显示部署完成信息
show_completion() {
    log_info "Deployment completed!"
    echo "========================"
    echo "Next steps on the server:"
    echo "1. Initialize Redis data:"
    echo "   cd $SERVER_SCRIPTS_PATH"
    echo "   ./init_redis_data.sh"
    echo ""
    echo "2. Start the services:"
    echo "   ./start_gateway.sh"
    echo ""
    echo "3. Check status:"
    echo "   ./status_gateway.sh"
    echo ""
    echo "4. Test the services:"
    echo "   ./test_gateway.sh"
    echo "========================"
}

# 主函数
main() {
    log_info "Starting deployment to server..."
    
    check_tools
    create_server_dirs
    upload_openresty
    upload_express
    upload_scripts
    set_permissions
    install_dependencies
    show_completion
    
    log_info "Deployment completed successfully!"
}

# 运行主函数
main "$@"
