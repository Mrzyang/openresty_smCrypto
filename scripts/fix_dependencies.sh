#!/bin/bash

# 修复依赖脚本
# 专门用于解决Node.js依赖问题

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

# 检查环境
check_environment() {
    log_info "Checking environment..."
    
    # 检查Node.js
    if ! command -v node &> /dev/null; then
        log_error "Node.js not found"
        log_info "Installing Node.js..."
        
        # 安装Node.js
        curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
        sudo apt-get install -y nodejs
        
        if [ $? -eq 0 ]; then
            log_info "Node.js installed successfully"
        else
            log_error "Failed to install Node.js"
            exit 1
        fi
    else
        log_info "Node.js: $(node --version)"
    fi
    
    # 检查npm
    if ! command -v npm &> /dev/null; then
        log_error "npm not found"
        exit 1
    else
        log_info "npm: $(npm --version)"
    fi
}

# 清理现有依赖
clean_dependencies() {
    log_info "Cleaning existing dependencies..."
    
    cd "$EXPRESS_HOME"
    
    if [ -d "node_modules" ]; then
        rm -rf node_modules
        log_info "Removed node_modules"
    fi
    
    if [ -f "package-lock.json" ]; then
        rm -f package-lock.json
        log_info "Removed package-lock.json"
    fi
}

# 安装依赖
install_dependencies() {
    log_info "Installing dependencies..."
    
    cd "$EXPRESS_HOME"
    
    # 更新npm
    npm install -g npm@latest
    
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
    
    # 测试关键模块
    local test_script="
    try {
        require('express');
        console.log('✓ express: OK');
        
        require('ioredis');
        console.log('✓ ioredis: OK');
        
        require('sm-crypto');
        console.log('✓ sm-crypto: OK');
        
        require('cors');
        console.log('✓ cors: OK');
        
        require('helmet');
        console.log('✓ helmet: OK');
        
        console.log('All modules loaded successfully!');
    } catch (error) {
        console.error('Module loading failed:', error.message);
        process.exit(1);
    }
    "
    
    echo "$test_script" | node
    
    if [ $? -eq 0 ]; then
        log_info "All modules verified successfully"
    else
        log_error "Module verification failed"
        exit 1
    fi
}

# 测试Redis连接
test_redis_connection() {
    log_info "Testing Redis connection..."
    
    cd "$EXPRESS_HOME"
    
    local test_script="
    const Redis = require('ioredis');
    
    const client = new Redis({
        host: '192.168.110.45',
        port: 6379,
        retryDelayOnFailover: 100,
        enableReadyCheck: false,
        maxRetriesPerRequest: null,
    });
    
    client.ping()
        .then(() => {
            console.log('✓ Redis connection: OK');
            client.quit();
        })
        .catch((err) => {
            console.error('✗ Redis connection failed:', err.message);
            process.exit(1);
        });
    "
    
    echo "$test_script" | node
    
    if [ $? -eq 0 ]; then
        log_info "Redis connection test passed"
    else
        log_error "Redis connection test failed"
        exit 1
    fi
}

# 显示已安装的模块
show_installed_modules() {
    log_info "Installed modules:"
    
    cd "$EXPRESS_HOME"
    npm list --depth=0 2>/dev/null | grep -E "├|└" | sed 's/^/  /'
}

# 主函数
main() {
    log_info "Starting dependency fix..."
    
    check_environment
    clean_dependencies
    install_dependencies
    verify_installation
    test_redis_connection
    show_installed_modules
    
    log_info "Dependency fix completed successfully!"
    log_info "You can now run: ./init_redis_data.sh"
}

# 运行主函数
main "$@"
