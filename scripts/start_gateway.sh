#!/bin/bash

# API网关启动脚本
# 用于启动基于已编译OpenResty的API网关

# 配置
OPENRESTY_HOME="/opt/zy/software/openresty"
EXPRESS_HOME="/opt/zy/software/express"
REDIS_HOST="192.168.110.45"
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

# 创建Nginx配置
create_nginx_config() {
    log_info "Creating Nginx configuration..."
    
    # 创建配置目录
    mkdir -p "$OPENRESTY_HOME/nginx/conf/conf.d"
    mkdir -p "$OPENRESTY_HOME/nginx/lua/api_gateway"
    mkdir -p "$OPENRESTY_HOME/nginx/logs"
    
    # 复制网关Lua代码
    if [ -d "openresty/nginx/lua/api_gateway" ]; then
        cp -r openresty/nginx/lua/api_gateway/* "$OPENRESTY_HOME/nginx/lua/api_gateway/"
    fi
    
    # 创建API网关配置
    cat > "$OPENRESTY_HOME/nginx/conf/conf.d/api_gateway.conf" << EOF
# API网关配置文件
upstream backend_services {
    server 127.0.0.1:$BACKEND_PORT;
    keepalive 32;
}

server {
    listen $GATEWAY_PORT;
    server_name localhost;
    
    location /health {
        access_log off;
        content_by_lua_block {
            local gateway = require "api_gateway.gateway"
            gateway.health_check()
        }
    }
    
    location /admin/app {
        access_log off;
        content_by_lua_block {
            local gateway = require "api_gateway.gateway"
            gateway.get_app_info()
        }
    }
    
    location /admin/api {
        access_log off;
        content_by_lua_block {
            local gateway = require "api_gateway.gateway"
            gateway.get_api_info()
        }
    }
    
    location /admin/subscriptions {
        access_log off;
        content_by_lua_block {
            local gateway = require "api_gateway.gateway"
            gateway.get_app_subscriptions()
        }
    }
    
    location /proxy {
        internal;
        proxy_pass http://backend_services;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
        proxy_buffering off;
    }
    
    location /api/ {
        client_max_body_size 10m;
        lua_need_request_body on;
        content_by_lua_block {
            local gateway = require "api_gateway.gateway"
            gateway.handle_request()
        }
        error_page 400 401 403 404 408 409 500 502 503 504 /error;
    }
    
    location = /error {
        internal;
        content_by_lua_block {
            local status = ngx.status
            local error_msg = "Internal Server Error"
            if status == 400 then error_msg = "Bad Request"
            elseif status == 401 then error_msg = "Unauthorized"
            elseif status == 403 then error_msg = "Forbidden"
            elseif status == 404 then error_msg = "Not Found"
            elseif status == 408 then error_msg = "Request Timeout"
            elseif status == 409 then error_msg = "Conflict"
            elseif status == 500 then error_msg = "Internal Server Error"
            elseif status == 502 then error_msg = "Bad Gateway"
            elseif status == 503 then error_msg = "Service Unavailable"
            elseif status == 504 then error_msg = "Gateway Timeout"
            end
            ngx.header.content_type = "application/json; charset=utf-8"
            ngx.say('{"code":' .. status .. ',"message":"' .. error_msg .. '","timestamp":' .. ngx.time() .. '}')
        }
    }
}

log_format api_gateway '\$remote_addr - \$remote_user [\$time_local] '
                      '"\$request" \$status \$body_bytes_sent '
                      '"\$http_referer" "\$http_user_agent" '
                      'rt=\$request_time uct="\$upstream_connect_time" '
                      'uht="\$upstream_header_time" urt="\$upstream_response_time" '
                      'appid="\$http_x_app_id" nonce="\$http_x_nonce"';

access_log $OPENRESTY_HOME/nginx/logs/api_gateway_access.log api_gateway;
error_log $OPENRESTY_HOME/nginx/logs/api_gateway_error.log;
EOF

    # 创建主配置文件
    cat > "$OPENRESTY_HOME/nginx/conf/nginx.conf" << EOF
user $(whoami);
worker_processes auto;
pid $OPENRESTY_HOME/nginx/logs/nginx.pid;

events {
    worker_connections 1024;
    use epoll;
    multi_accept on;
}

http {
    include mime.types;
    default_type application/octet-stream;
    
    # Lua配置
    lua_package_path "$OPENRESTY_HOME/nginx/lua/?.lua;$OPENRESTY_HOME/nginx/lua/api_gateway/?.lua;;";
    lua_shared_dict nonce_cache 10m;
    lua_shared_dict rate_limit 10m;
    
    log_format main '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                    '\$status \$body_bytes_sent "\$http_referer" '
                    '"\$http_user_agent" "\$http_x_forwarded_for"';
    
    access_log $OPENRESTY_HOME/nginx/logs/access.log main;
    error_log $OPENRESTY_HOME/nginx/logs/error.log;
    
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    
    include $OPENRESTY_HOME/nginx/conf/conf.d/*.conf;
}
EOF

    log_info "Nginx configuration created"
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
    create_nginx_config
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
