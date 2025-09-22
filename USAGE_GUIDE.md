# API网关使用指南

## 系统配置

- **OpenResty路径**: `/opt/zy/software/openresty`
- **Express路径**: `/opt/zy/software/express`
- **网关端口**: 8082
- **后端端口**: 3000
- **Redis**: 192.168.17.1:6379

## 快速开始

### 1. 上传代码到服务器

将以下文件上传到Debian12服务器：

```
/opt/zy/software/openresty/     # OpenResty编译好的文件
/opt/zy/software/express/       # Express后端代码
scripts/                        # 管理脚本
```

### 2. 设置执行权限

```bash
chmod +x scripts/*.sh
```

### 3. 修复依赖（如果遇到模块问题）

```bash
./scripts/fix_dependencies.sh
```

### 4. 初始化Redis数据

```bash
./scripts/init_redis_data.sh
```

### 5. 启动服务

```bash
./scripts/start_gateway.sh
```

### 6. 检查状态

```bash
./scripts/status_gateway.sh
```

### 7. 测试服务

```bash
./scripts/test_gateway.sh
```

## 管理命令

### 启动服务
```bash
./scripts/start_gateway.sh
```

### 停止服务
```bash
./scripts/stop_gateway.sh
```

### 重启服务
```bash
./scripts/restart_gateway.sh
```

### 查看状态
```bash
./scripts/status_gateway.sh
```

### 测试功能
```bash
./scripts/test_gateway.sh
```

### 修复依赖
```bash
./scripts/fix_dependencies.sh
```

### 初始化Redis数据
```bash
./scripts/init_redis_data.sh
```

## 服务访问

### 网关服务
- **URL**: http://localhost:8082
- **健康检查**: http://localhost:8082/health
- **管理接口**: 
  - http://localhost:8082/admin/app
  - http://localhost:8082/admin/api
  - http://localhost:8082/admin/subscriptions

### 后端服务
- **URL**: http://localhost:3000
- **健康检查**: http://localhost:3000/health

## API调用示例

### 1. 生成测试密钥

```bash
cd /opt/zy/software/express
node test_client.js
```

### 2. 运行完整测试

```bash
cd /opt/zy/software/express
node test_client.js test
```

### 3. 测试单个API

```bash
cd /opt/zy/software/express
node test_client.js single GET /api/user/info
```

## 请求格式

### 请求头
```
X-App-ID: app_001
X-Signature: base64_encoded_signature
X-Nonce: 1234567890
X-Timestamp: 1640995200
Content-Type: application/json
```

### 签名算法
```
待签名数据 = method + uri + query_string + body + nonce + timestamp
签名 = SM2(SM3(待签名数据), private_key)
```

## 日志文件

### 后端日志
- **位置**: `/opt/zy/software/express/backend.log`
- **查看**: `tail -f /opt/zy/software/express/backend.log`

### 网关日志
- **访问日志**: `/opt/zy/software/openresty/nginx/logs/api_gateway_access.log`
- **错误日志**: `/opt/zy/software/openresty/nginx/logs/api_gateway_error.log`
- **查看**: `tail -f /opt/zy/software/openresty/nginx/logs/api_gateway_access.log`

## 故障排除

### 1. 端口被占用
```bash
# 查看端口占用
netstat -tlnp | grep -E "(8082|3000)"

# 杀死占用进程
kill -9 <PID>
```

### 2. Redis连接失败
```bash
# 检查Redis服务
redis-cli -h 192.168.17.1 -p 6379 ping

# 检查网络连接
telnet 192.168.17.1 6379
```

### 3. 服务启动失败
```bash
# 查看详细错误
./scripts/status_gateway.sh

# 查看日志
tail -f /opt/zy/software/express/backend.log
tail -f /opt/zy/software/openresty/nginx/logs/api_gateway_error.log
```

### 4. 配置文件错误
```bash
# 检查Nginx配置
/opt/zy/software/openresty/bin/openresty -t

# 检查Node.js配置
cd /opt/zy/software/express
node -c index.js
```

## 性能监控

### 系统资源
```bash
# 查看内存使用
free -h

# 查看CPU使用
top

# 查看磁盘使用
df -h
```

### 服务监控
```bash
# 查看进程状态
ps aux | grep -E "(nginx|node)"

# 查看网络连接
netstat -tlnp | grep -E "(8082|3000)"
```

## 安全建议

1. **防火墙配置**: 只开放必要的端口
2. **密钥管理**: 定期轮换SM2和SM4密钥
3. **访问控制**: 配置IP白名单
4. **监控告警**: 设置异常请求告警
5. **日志审计**: 定期分析访问日志

## 扩展配置

### 添加新的API

1. 在Express后端添加API路由
2. 在Redis中添加API配置
3. 在App订阅中添加API

### 修改端口

1. 修改脚本中的端口配置
2. 重新启动服务

### 添加新的App

1. 在Redis中添加App配置
2. 配置SM2密钥和SM4密钥
3. 设置IP白名单

## 维护任务

### 日常维护
- 检查服务状态
- 查看错误日志
- 监控系统资源

### 定期维护
- 清理日志文件
- 更新系统包
- 备份重要数据

## 联系支持

如有问题，请检查：
1. 服务状态：`./scripts/status_gateway.sh`
2. 错误日志：查看相关日志文件
3. 系统资源：检查内存和磁盘使用
4. 网络连接：检查Redis和端口连通性
