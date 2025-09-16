# API网关架构设计

## 系统架构

```
客户端 -> OpenResty API网关 -> Express后端服务
         |                    |
         v                    v
      Redis缓存            Redis存储
```

## Redis数据结构设计

### 1. App配置 (app:{appid})
```json
{
  "appid": "app_001",
  "name": "测试应用",
  "status": "active", // active, disabled
  "sm2_private_key": "-----BEGIN PRIVATE KEY-----...",
  "sm2_public_key": "-----BEGIN PUBLIC KEY-----...",
  "sm4_key": "1234567890abcdef",
  "sm4_iv": "abcdef1234567890",
  "ip_whitelist": ["192.168.1.100", "192.168.1.101"],
  "nonce_window": 300, // 防重放时间窗口(秒)
  "created_at": "2024-01-01T00:00:00Z",
  "updated_at": "2024-01-01T00:00:00Z"
}
```

### 2. API配置 (api:{api_id})
```json
{
  "api_id": "api_001",
  "name": "用户信息查询",
  "path": "/api/user/info",
  "method": "GET",
  "backend_url": "http://127.0.0.1:3000/api/user/info",
  "status": "active", // active, disabled
  "rate_limit": 1000, // 每分钟请求数限制
  "timeout": 30, // 超时时间(秒)
  "created_at": "2024-01-01T00:00:00Z",
  "updated_at": "2024-01-01T00:00:00Z"
}
```

### 3. App订阅关系 (app_subscription:{appid})
```json
{
  "appid": "app_001",
  "subscribed_apis": ["api_001", "api_002"],
  "subscription_status": {
    "api_001": "active",
    "api_002": "active"
  },
  "created_at": "2024-01-01T00:00:00Z",
  "updated_at": "2024-01-01T00:00:00Z"
}
```

### 4. 防重放缓存 (nonce:{appid}:{nonce})
```
Key: nonce:app_001:1234567890
Value: timestamp (Unix时间戳)
TTL: 300秒 (5分钟)
```

## 请求流程

### 1. 客户端请求
```
POST /api/user/info
Headers:
  X-App-ID: app_001
  X-Signature: base64_encoded_signature
  X-Nonce: 1234567890
  X-Timestamp: 1640995200
  Content-Type: application/json
Body: sm4_encrypted_data
```

### 2. 网关处理流程
1. 验证App ID存在且状态为active
2. 验证IP白名单
3. 验证防重放参数(nonce)
4. 验证签名
5. 解密请求体
6. 转发到后端服务
7. 加密响应体
8. 对响应体签名
9. 返回给客户端

### 3. 签名算法
```
待签名数据 = method + uri + query_string + body + nonce + timestamp
签名 = SM2(SM3(待签名数据), private_key)
```

## 安全特性

1. **国密算法**: SM2签名、SM3哈希、SM4对称加密
2. **防重放攻击**: 基于nonce和timestamp的防重放机制
3. **IP白名单**: 限制访问来源
4. **签名验证**: 确保请求完整性和来源可信
5. **加密传输**: 请求和响应都经过SM4加密

## 管理功能

1. **App管理**: 创建、更新、禁用App
2. **API管理**: 注册、更新、禁用API
3. **订阅管理**: App订阅API
4. **监控统计**: 请求统计、错误日志
5. **配置热更新**: 无需重启网关
