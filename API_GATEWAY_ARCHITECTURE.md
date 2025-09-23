# API网关架构设计

## 系统架构

```
客户端 -> OpenResty API网关 -> Express后端服务
         |                    |
         v                    v
      Redis(无缓存)            Redis存储
```

## Redis数据结构设计

### 1. App配置 (app:{appid})
```json
{
  "appid": "app_001",
  "name": "测试应用",
  "status": "active",
  "sm2_private_key": "54703123510a202f561e320b398f631f0fa15bcac999adc84ddb0b7ae6594545",
  "sm2_public_key": "049e76887a7fc4d77518c7133e7027c1ed53b5c0e2b9d9e0395981a39e3520dc7c8a10edfae7705f110df8435ee31f74b60466b67cb8382e32b2032ec8553f7215",
  "gateway_sm2_private_key": "e397c95eb118119f24e620e238f112f0329b9d3a379f1c790b605a0ef38286b8",
  "gateway_sm2_public_key": "04af469f52c78ebffc80a4db22746a226bb8eb7722fa1524a0c5c1386ef9cd2af05c1d2e15dccbc5960cf013eb82452d4a702e4c5766eef74cdad62174b158357c",
  "sm4_key": "bf2cd6b46a9da3efdac9549f46cf202d",
  "sm4_iv": "8c35c753852dcbe4706a2d78c0d9f56c",
  "ip_whitelist": [
    "127.0.0.1",
    "192.168.1.100",
    "192.168.1.101"
  ],
  "nonce_window": 300,
  "created_at": "2025-09-22T14:28:27.868Z",
  "updated_at": "2025-09-22T14:28:27.869Z"
}
```

### 2. API配置 (api:path:{api_path})
```json
{
  "api_id": "api_001",
  "name": "用户信息查询",
  "path": "/api/user/info",
  "method": "GET",
  "backend_uri": "/api/user/info",
  "backend_ip_list": [
    "127.0.0.1:3000",
    "192.168.110.48:3000"
  ],
  "status": "active",
  "rate_limit": 1000,        # 每秒请求限制
  "rate_burst": 2000,        # 突发请求限制
  "timeout": 30,
  "created_at": "2025-09-22T14:28:27.939Z",
  "updated_at": "2025-09-22T14:28:27.939Z"
}
```

### 3. App订阅关系 (app_subscription:{appid})
```json
{
  "appid": "app_001",
  "subscribed_apis": [
    "/api/user/info",
    "/api/user/list",
    "/api/user/create",
    "/api/user/update",
    "/api/user/delete",
    "/api/system/status",
    "/health"
  ],
  "subscription_status": {
    "/api/user/info": "active",
    "/api/user/list": "active",
    "/api/user/create": "active",
    "/api/user/update": "active",
    "/api/user/delete": "active",
    "/api/system/status": "active",
    "/health": "active"
  },
  "created_at": "2025-09-22T14:28:27.949Z",
  "updated_at": "2025-09-22T14:28:27.949Z"
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
  X-Signature: sm2_signature
  X-Nonce: 1234567890
  X-Timestamp: 1640995200
  Content-Type: application/json
Body: sm4_encrypted_data_base64Encoded

请求头：
{
  'X-App-ID': 'app_001',
  'X-Signature': '3044022010ff65543cdf52ad715e6286dc703a563f156722f7a03451f86736ea99d3a6810220652852a5b37cfc7680a80f16d1d5418016721bcebf3fe5d6cabbb67db89d485f',
  'X-Nonce': '25341693981758551376',
  'X-Timestamp': '1758551376',
  'Content-Type': 'application/octet-stream'
}
```

### 2. 网关处理流程
1. 流控检查
2. 验证App ID存在且状态为active
3. 验证IP白名单
4. 验证防重放参数(nonce)
5. 解密请求体
6. 验证签名
7. 转发到后端服务
8. 加密响应体
9. 对响应体签名
10. 返回给客户端

### 3. 网关响应头
```
{
  server: 'openresty/1.27.1.2',
  date: 'Mon, 22 Sep 2025 14:29:37 GMT',
  'content-type': 'application/octet-stream',
  connection: 'keep-alive',
  'x-response-signature': '30450220582f74601334d534109c7b042709e252c59e5c65a49f4034ea037a99be257b2502210088a285d454c8cdfd4758e778a2da36bdb76cc589e1716de3fa2f2a23d1968821',
  'content-length': '728',
  'x-encrypted': 'true'
}
```

### 4. 签名算法
```
待签名数据 = method + uri + query_string + body明文 + nonce + timestamp
签名 = SM2((待签名数据，即body明文), private_key) 包含sm3杂凑和ASN.1 DER编码
```

### 5. 加密算法
```
待加密数据 = body明文
加密 = base64_encode(sm4-cbc(body, key, iv))
```

## 安全特性

1. **国密算法**: SM2签名、SM3哈希、SM4对称加密
2. **防重放攻击**: 基于nonce和timestamp的防重放机制
3. **IP白名单**: 限制访问来源
4. **签名验证**: 确保请求完整性和来源可信(后端服务响应状态码为200时网关才加签)
5. **加密传输**: 请求和响应经过SM4加密(后端服务响应状态码为200时网关才加密报文)

## 管理功能

1. **App管理**: 创建、更新、禁用App
2. **API管理**: 注册、更新、禁用API
3. **订阅管理**: App订阅API
4. **监控统计**: 请求统计、错误日志
5. **配置热更新**: 无需重启网关
