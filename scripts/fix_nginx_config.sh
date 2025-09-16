#!/bin/bash

# 修复Nginx配置脚本
# 用于修复Nginx配置问题

# 配置
OPENRESTY_HOME="/opt/zy/software/openresty"
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

# 停止现有服务
stop_services() {
    log_info "Stopping existing services..."
    
    # 停止网关
    if pgrep -f "nginx.*$OPENRESTY_HOME" > /dev/null; then
        "$OPENRESTY_HOME/bin/openresty" -s quit -c "$OPENRESTY_HOME/nginx/conf/nginx.conf" 2>/dev/null
        sleep 2
    fi
    
    # 停止后端
    if [ -f "/opt/zy/software/express/backend.pid" ]; then
        local backend_pid=$(cat "/opt/zy/software/express/backend.pid")
        if ps -p $backend_pid > /dev/null 2>&1; then
            kill -TERM $backend_pid
            sleep 2
        fi
    fi
    
    log_info "Services stopped"
}

# 修复Nginx配置
fix_nginx_config() {
    log_info "Fixing Nginx configuration..."
    
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

    log_info "Nginx configuration fixed"
}

# 测试配置
test_config() {
    log_info "Testing Nginx configuration..."
    
    if "$OPENRESTY_HOME/bin/openresty" -t -c "$OPENRESTY_HOME/nginx/conf/nginx.conf"; then
        log_info "Nginx configuration test passed"
        return 0
    else
        log_error "Nginx configuration test failed"
        return 1
    fi
}

# 启动服务
start_services() {
    log_info "Starting services..."
    
    # 启动后端
    cd "/opt/zy/software/express"
    nohup node index.js > "/opt/zy/software/express/backend.log" 2>&1 &
    echo $! > "/opt/zy/software/express/backend.pid"
    sleep 3
    
    # 启动网关
    "$OPENRESTY_HOME/bin/openresty" -c "$OPENRESTY_HOME/nginx/conf/nginx.conf"
    sleep 2
    
    log_info "Services started"
}

# 验证服务
verify_services() {
    log_info "Verifying services..."
    
    # 检查后端
    if curl -s http://localhost:3000/health &> /dev/null; then
        log_info "Backend service: OK"
    else
        log_error "Backend service: FAILED"
        return 1
    fi
    
    # 检查网关
    if curl -s http://localhost:8082/health &> /dev/null; then
        log_info "Gateway service: OK"
    else
        log_error "Gateway service: FAILED"
        return 1
    fi
    
    log_info "All services verified successfully"
}

# 主函数
main() {
    log_info "Fixing Nginx configuration..."
    
    stop_services
    fix_nginx_config
    
    if test_config; then
        start_services
        verify_services
        log_info "Nginx configuration fixed successfully!"
    else
        log_error "Configuration fix failed"
        exit 1
    fi
}

# 运行主函数
main "$@"
