#!/bin/bash

# 测试密钥轮换功能的脚本

echo "=== 测试密钥轮换功能 ==="

# 切换到express目录
cd /opt/zy/software/express

# 显示当前密钥
echo "1. 显示当前密钥配置:"
node test_key_rotation.js show app_001

# 发送测试请求
echo "2. 发送测试请求（使用当前密钥）:"
node test_client.js single POST /api/user/create '{"name":"Before Rotation","email":"before@example.com"}'

# 更新密钥
echo "3. 更新密钥配置:"
node test_key_rotation.js update app_001

# 等待30秒让网关同步新密钥
echo "4. 等待30秒让网关同步新密钥..."
sleep 30

# 再次发送测试请求
echo "5. 发送测试请求（使用新密钥）:"
node test_client.js single POST /api/user/create '{"name":"After Rotation","email":"after@example.com"}'

echo "=== 密钥轮换测试完成 ==="