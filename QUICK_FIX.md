# 快速修复指南

## 问题1：缺少Redis模块

如果遇到 `Error: Cannot find module 'redis'` 错误，请按以下步骤修复：

### 1. 运行依赖修复脚本

```bash
cd /opt/zy/software/scripts
./fix_dependencies.sh
```

### 2. 如果修复脚本失败，手动修复

```bash
# 进入Express目录
cd /opt/zy/software/express

# 清理现有依赖
rm -rf node_modules package-lock.json

# 重新安装依赖
npm install

# 验证安装
node -e "require('ioredis'); console.log('ioredis: OK')"
```

### 3. 重新初始化Redis数据

```bash
cd /opt/zy/software/scripts
./init_redis_data.sh
```

### 4. 启动服务

```bash
./start_gateway.sh
```

## 主要变更

1. **使用ioredis替代redis模块**
   - 性能更好
   - 功能更丰富
   - 更好的错误处理

2. **更新了package.json**
   - 移除了 `redis` 依赖
   - 添加了 `ioredis` 依赖

3. **更新了代码**
   - `express/index.js` 使用 ioredis
   - `express/init_redis_data.js` 使用 ioredis

## 验证修复

运行以下命令验证修复是否成功：

```bash
# 检查依赖
cd /opt/zy/software/express
npm list

# 测试Redis连接
node -e "
const Redis = require('ioredis');
const client = new Redis({host: '192.168.56.2', port: 6379});
client.ping().then(() => {
  console.log('Redis connection: OK');
  client.quit();
}).catch(err => {
  console.error('Redis connection failed:', err.message);
});
"

# 运行初始化脚本
cd /opt/zy/software/scripts
./init_redis_data.sh
```

## 如果仍有问题

1. **检查Node.js版本**
   ```bash
   node --version
   npm --version
   ```

2. **检查网络连接**
   ```bash
   ping 192.168.56.2
   telnet 192.168.56.2 6379
   ```

3. **查看详细错误**
   ```bash
   cd /opt/zy/software/express
   node init_redis_data.js
   ```

4. **清理并重新安装**
   ```bash
   cd /opt/zy/software/express
   rm -rf node_modules package-lock.json
   npm cache clean --force
   npm install
   ```

## 问题2：Nginx配置错误

如果遇到 `nginx: [emerg] "lua_package_path" directive is not allowed here` 错误，请按以下步骤修复：

### 1. 运行Nginx配置修复脚本

```bash
cd /opt/zy/software/scripts
./fix_nginx_config.sh
```

### 2. 如果修复脚本失败，手动修复

```bash
# 停止服务
cd /opt/zy/software/scripts
./stop_gateway.sh

# 重新启动
./start_gateway.sh
```

### 3. 验证修复

```bash
# 检查配置
/opt/zy/software/openresty/bin/openresty -t

# 检查服务状态
./status_gateway.sh

# 测试服务
curl http://localhost:8082/health
```

## 问题3：端口被占用

如果遇到端口被占用的错误：

### 1. 查看端口占用

```bash
netstat -tlnp | grep -E "(8082|3000)"
```

### 2. 杀死占用进程

```bash
# 杀死8082端口进程
sudo lsof -ti:8082 | xargs kill -9

# 杀死3000端口进程
sudo lsof -ti:3000 | xargs kill -9
```

### 3. 重新启动服务

```bash
cd /opt/zy/software/scripts
./start_gateway.sh
```

## 问题4：测试客户端连接失败

如果测试客户端无法连接到网关：

### 1. 运行测试问题修复脚本

```bash
cd /opt/zy/software/scripts
./fix_test_issues.sh
```

### 2. 检查连接

```bash
# 测试连接
./test_connection.sh

# 检查端口
netstat -tlnp | grep -E "(8082|3000)"
```

### 3. 手动测试

```bash
# 测试后端
curl http://localhost:3000/health

# 测试网关
curl http://localhost:8082/health

# 测试管理API
curl "http://localhost:8082/admin/app?appid=app_001"
```

### 4. 安装缺失依赖

```bash
cd /opt/zy/software/express
npm install axios
```
