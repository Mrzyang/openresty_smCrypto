# API网关部署指南

## 部署环境

- **操作系统**: Debian 12
- **Redis**: 192.168.56.2:6379
- **OpenResty**: 1.21.4.3
- **Node.js**: 18.x
- **后端服务**: 127.0.0.1:3000

## 部署步骤

### 1. 准备服务器

```bash
# 更新系统
sudo apt update && sudo apt upgrade -y

# 安装基础工具
sudo apt install -y wget curl git vim
```

### 2. 安装依赖

```bash
# 安装OpenResty
sudo ./scripts/install.sh

# 验证安装
/usr/local/openresty/bin/openresty -v
```

### 3. 部署代码

#### 上传文件到服务器

```bash
# 创建目录
sudo mkdir -p /opt/api-gateway-backend
sudo chown api-gateway:api-gateway /opt/api-gateway-backend

# 上传项目文件到 /opt/api-gateway-backend
# 包括以下文件：
# - index.js
# - package.json
# - test_client.js
# - init_redis_data.js
# - sm.js
```

#### 安装Node.js依赖

```bash
cd /opt/api-gateway-backend
sudo -u api-gateway npm install
```

### 4. 配置Redis

确保Redis服务运行在 `192.168.56.2:6379`：

```bash
# 检查Redis连接
redis-cli -h 192.168.56.2 -p 6379 ping
```

### 5. 初始化数据

```bash
# 初始化Redis数据
sudo ./scripts/backend_manager.sh init-data
```

### 6. 启动服务

```bash
# 启动后端服务
sudo ./scripts/backend_manager.sh start

# 启动网关服务
sudo ./scripts/gateway_manager.sh start

# 检查状态
sudo ./scripts/gateway_manager.sh status
```

### 7. 验证部署

```bash
# 测试健康检查
curl http://localhost/health

# 测试后端服务
curl http://localhost:3000/health

# 运行完整测试
cd /opt/api-gateway-backend
sudo -u api-gateway node test_client.js
```

## 服务管理

### 启动服务

```bash
# 启动所有服务
sudo systemctl start api-gateway-backend
sudo systemctl start openresty

# 设置开机自启
sudo systemctl enable api-gateway-backend
sudo systemctl enable openresty
```

### 停止服务

```bash
# 停止所有服务
sudo systemctl stop openresty
sudo systemctl stop api-gateway-backend
```

### 重启服务

```bash
# 重启所有服务
sudo systemctl restart api-gateway-backend
sudo systemctl restart openresty
```

### 查看状态

```bash
# 查看服务状态
sudo systemctl status openresty
sudo systemctl status api-gateway-backend

# 查看日志
sudo journalctl -u openresty -f
sudo journalctl -u api-gateway-backend -f
```

## 配置管理

### 网关配置

配置文件位置: `/usr/local/openresty/nginx/conf/conf.d/api_gateway.conf`

主要配置项：
- 监听端口: 80
- 后端服务: 127.0.0.1:3000
- Redis连接: 192.168.56.2:6379

### 后端配置

配置文件位置: `/opt/api-gateway-backend/index.js`

主要配置项：
- 监听端口: 3000
- Redis连接: 192.168.56.2:6379

### Redis配置

确保Redis配置允许外部连接：

```bash
# 编辑Redis配置
sudo vim /etc/redis/redis.conf

# 修改以下配置
bind 0.0.0.0
port 6379
protected-mode no
```

## 监控和维护

### 日志管理

```bash
# 查看网关日志
sudo ./scripts/gateway_manager.sh logs error 100

# 查看后端日志
sudo ./scripts/backend_manager.sh logs 100

# 清理旧日志
sudo find /usr/local/openresty/nginx/logs -name "*.log" -mtime +30 -delete
sudo find /var/log/api-gateway -name "*.log" -mtime +30 -delete
```

### 性能监控

```bash
# 查看系统资源
htop

# 查看网络连接
netstat -tlnp | grep -E "(80|3000|6379)"

# 查看进程状态
ps aux | grep -E "(nginx|node)"
```

### 备份和恢复

```bash
# 备份配置
sudo tar -czf api-gateway-config-$(date +%Y%m%d).tar.gz \
  /usr/local/openresty/nginx/conf \
  /opt/api-gateway-backend \
  /etc/systemd/system/api-gateway-backend.service

# 备份Redis数据
redis-cli -h 192.168.56.2 -p 6379 --rdb /backup/redis-$(date +%Y%m%d).rdb
```

## 故障排除

### 常见问题

1. **端口被占用**
   ```bash
   # 查看端口占用
   sudo netstat -tlnp | grep -E "(80|3000)"
   
   # 杀死占用进程
   sudo kill -9 <PID>
   ```

2. **权限问题**
   ```bash
   # 修复权限
   sudo chown -R api-gateway:api-gateway /opt/api-gateway-backend
   sudo chown -R api-gateway:api-gateway /var/log/api-gateway
   ```

3. **Redis连接失败**
   ```bash
   # 检查Redis服务
   sudo systemctl status redis
   
   # 检查网络连接
   telnet 192.168.56.2 6379
   ```

4. **配置文件错误**
   ```bash
   # 检查Nginx配置
   sudo /usr/local/openresty/bin/openresty -t
   
   # 检查后端配置
   cd /opt/api-gateway-backend
   node -c index.js
   ```

### 调试模式

```bash
# 启用调试日志
sudo vim /usr/local/openresty/nginx/conf/nginx.conf

# 在http块中添加
error_log /usr/local/openresty/nginx/logs/error.log debug;

# 重载配置
sudo ./scripts/gateway_manager.sh reload
```

## 安全加固

### 防火墙配置

```bash
# 安装ufw
sudo apt install ufw

# 配置防火墙规则
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 3000/tcp  # 后端服务（仅内网）
sudo ufw allow 6379/tcp  # Redis（仅内网）
sudo ufw enable
```

### SSL/TLS配置

```bash
# 安装证书
sudo mkdir -p /etc/ssl/api-gateway
sudo cp your-cert.pem /etc/ssl/api-gateway/
sudo cp your-key.pem /etc/ssl/api-gateway/

# 修改Nginx配置添加SSL
sudo vim /usr/local/openresty/nginx/conf/conf.d/api_gateway.conf
```

### 系统安全

```bash
# 更新系统
sudo apt update && sudo apt upgrade -y

# 配置自动安全更新
sudo apt install unattended-upgrades
sudo dpkg-reconfigure unattended-upgrades

# 禁用不必要的服务
sudo systemctl disable bluetooth
sudo systemctl disable cups
```

## 性能优化

### OpenResty优化

```bash
# 编辑Nginx配置
sudo vim /usr/local/openresty/nginx/conf/nginx.conf

# 优化worker进程
worker_processes auto;
worker_cpu_affinity auto;

# 优化连接
worker_connections 4096;
use epoll;
multi_accept on;
```

### 系统优化

```bash
# 优化内核参数
sudo vim /etc/sysctl.conf

# 添加以下配置
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_tw_reuse = 1

# 应用配置
sudo sysctl -p
```

## 扩展部署

### 负载均衡

```bash
# 安装HAProxy
sudo apt install haproxy

# 配置负载均衡
sudo vim /etc/haproxy/haproxy.cfg
```

### 高可用

```bash
# 配置Keepalived
sudo apt install keepalived

# 配置VIP
sudo vim /etc/keepalived/keepalived.conf
```

## 维护计划

### 日常维护

- 检查服务状态
- 查看错误日志
- 监控系统资源
- 备份重要数据

### 定期维护

- 更新系统包
- 轮换密钥
- 清理日志文件
- 性能调优

### 应急响应

- 服务故障处理
- 安全事件响应
- 数据恢复
- 系统重建
