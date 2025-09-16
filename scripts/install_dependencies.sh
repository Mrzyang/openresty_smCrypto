#!/bin/bash

# 安装依赖脚本
# 用于安装Node.js依赖

# 配置
EXPRESS_HOME="/opt/zy/software/express"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 检查Node.js
check_nodejs() {
    if ! command -v node &> /dev/null; then
        log_error "Node.js not found"
        log_info "Please install Node.js first:"
        log_info "  curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -"
        log_info "  sudo apt-get install -y nodejs"
        exit 1
    fi
    
    local node_version=$(node --version)
    log_info "Node.js version: $node_version"
}

# 检查npm
check_npm() {
    if ! command -v npm &> /dev/null; then
        log_error "npm not found"
        exit 1
    fi
    
    local npm_version=$(npm --version)
    log_info "npm version: $npm_version"
}

# 检查Express目录
check_express_dir() {
    if [ ! -d "$EXPRESS_HOME" ]; then
        log_error "Express directory not found: $EXPRESS_HOME"
        exit 1
    fi
    
    if [ ! -f "$EXPRESS_HOME/package.json" ]; then
        log_error "package.json not found in $EXPRESS_HOME"
        exit 1
    fi
    
    log_info "Express directory: OK"
}

# 安装依赖
install_dependencies() {
    log_info "Installing Node.js dependencies..."
    
    cd "$EXPRESS_HOME"
    
    # 清理node_modules（可选）
    if [ "$1" = "--clean" ]; then
        log_info "Cleaning existing node_modules..."
        rm -rf node_modules package-lock.json
    fi
    
    # 安装依赖
    npm install
    
    if [ $? -eq 0 ]; then
        log_info "Dependencies installed successfully"
    else
        log_error "Failed to install dependencies"
        exit 1
    fi
}

# 验证安装
verify_installation() {
    log_info "Verifying installation..."
    
    cd "$EXPRESS_HOME"
    
    # 检查关键模块
    local modules=("express" "ioredis" "sm-crypto" "cors" "helmet")
    
    for module in "${modules[@]}"; do
        if node -e "require('$module'); console.log('$module: OK')" 2>/dev/null; then
            log_info "$module: OK"
        else
            log_error "$module: FAILED"
            return 1
        fi
    done
    
    log_info "All modules verified successfully"
}

# 显示已安装的模块
show_installed_modules() {
    log_info "Installed modules:"
    
    cd "$EXPRESS_HOME"
    npm list --depth=0 2>/dev/null | grep -E "├|└" | sed 's/^/  /'
}

# 显示帮助
show_help() {
    echo "Install Dependencies Script"
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --clean    Clean existing node_modules before install"
    echo "  --help     Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0              # Install dependencies"
    echo "  $0 --clean      # Clean install dependencies"
}

# 主函数
main() {
    local clean_install=false
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --clean)
                clean_install=true
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
    
    log_info "Starting dependency installation..."
    
    check_nodejs
    check_npm
    check_express_dir
    
    if [ "$clean_install" = true ]; then
        install_dependencies --clean
    else
        install_dependencies
    fi
    
    verify_installation
    show_installed_modules
    
    log_info "Dependency installation completed!"
}

# 运行主函数
main "$@"
