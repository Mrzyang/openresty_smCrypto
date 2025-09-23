const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const Redis = require('ioredis');
const smCrypto = require('sm-crypto');
const sm2 = smCrypto.sm2;
const sm3 = smCrypto.sm3;
const sm4 = smCrypto.sm4;
const fs = require('fs');
const path = require('path');
const { requestLogger, logError } = require('./logger');

// 创建 Express 应用
const app = express();

// 从环境变量获取Redis配置，如果没有则使用默认值
const REDIS_HOST = process.env.REDIS_HOST || '192.168.110.48';
const REDIS_PORT = process.env.REDIS_PORT || '6379';
// Redis客户端
const redisClient = new Redis({
  host: REDIS_HOST,
  port: REDIS_PORT,
  retryDelayOnFailover: 100,
  enableReadyCheck: false,
  maxRetriesPerRequest: null,
});

redisClient.on('error', (err) => {
  logError(`Redis Client Error: ${err}`);
});

redisClient.on('connect', () => {
  console.log('Connected to Redis');
});

// 中间件
app.use(helmet());
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// 添加请求日志中间件
app.use(requestLogger);

// 健康检查
app.get('/health', (req, res) => {
  res.json({ 
    status: 'healthy', 
    timestamp: new Date().toISOString(),
    service: 'api-gateway-backend'
  });
});

// 示例API - 用户信息
app.get('/api/user/info', (req, res) => {
  res.json({
    code: 0,
    message: 'success',
    data: {
      userId: '12345',
      username: 'testuser',
      email: 'test@example.com',
      createdAt: '2024-01-01T00:00:00Z'
    },
    timestamp: new Date().toISOString()
  });
});

app.get('/api/user/list', (req, res) => {
  res.json({
    code: 0,
    message: 'success',
    data: {
      users: [
        { id: 1, name: 'User 1', email: 'user1@example.com' },
        { id: 2, name: 'User 2', email: 'user2@example.com' },
        { id: 3, name: 'User 3', email: 'user3@example.com' }
      ],
      total: 3,
      page: 1,
      pageSize: 10
    },
    timestamp: new Date().toISOString()
  });
});

// 示例API - 创建用户
app.post('/api/user/create', (req, res) => {
  const { name, email } = req.body;
  console.log(req.body)
  console.log('Received user creation request:', JSON.stringify(req.body));
  if (!name || !email) {
    return res.status(400).json({
      code: 400,
      message: 'Missing required fields: name and email',
      timestamp: new Date().toISOString()
    });
  }
  
  res.json({
    code: 0,
    message: 'User created successfully',
    data: {
      id: Date.now(),
      name,
      email,
      createdAt: new Date().toISOString()
    },
    timestamp: new Date().toISOString()
  });
});

// 示例API - 更新用户
app.put('/api/user/update', (req, res) => {
  const { id, name, email } = req.body;
  console.log('Received user update request:', JSON.stringify(req.body));
  
  // 验证必需字段
  if (!id) {
    return res.status(400).json({
      code: 400,
      message: 'Missing required field: id',
      timestamp: new Date().toISOString()
    });
  }
  
  // 检查至少提供一个可更新的字段
  if (!name && !email) {
    return res.status(400).json({
      code: 400,
      message: 'At least one of name or email must be provided',
      timestamp: new Date().toISOString()
    });
  }
  
  res.json({
    code: 0,
    message: 'User updated successfully',
    data: {
      id,
      name: name || 'Unchanged',
      email: email || 'Unchanged',
      updatedAt: new Date().toISOString()
    },
    timestamp: new Date().toISOString()
  });
});

// 示例API - 删除用户
app.delete('/api/user/delete', (req, res) => {
  const { id } = req.body;
  console.log('Received user deletion request:', JSON.stringify(req.body));
  
  // 验证必需字段
  if (!id) {
    return res.status(400).json({
      code: 400,
      message: 'Missing required field: id',
      timestamp: new Date().toISOString()
    });
  }
  
  res.json({
    code: 0,
    message: 'User deleted successfully',
    data: {
      id,
      deletedAt: new Date().toISOString()
    },
    timestamp: new Date().toISOString()
  });
});

// 示例API - 系统状态
app.get('/api/system/status', (req, res) => {
  res.json({
    code: 0,
    message: 'success',
    data: {
      status: 'running',
      uptime: process.uptime(),
      memory: process.memoryUsage(),
      version: process.version,
      platform: process.platform
    },
    timestamp: new Date().toISOString()
  });
});

app.get('/api/test/hello', (req, res) => {
    return res.send('hello');
});

app.get('/api/test/headerWithHashed', (req, res) => {
    let data = 'hello';
    // --- SM3 哈希摘要 ---
    const sm3Digest = sm3(data);
    // 将16进制字符串转换为字节数组（Buffer）再转base64
    const hashed_base64 = Buffer.from(sm3Digest, 'hex').toString('base64');
    res.setHeader('hashed', hashed_base64);
    return res.send(data);
});

// 测试POST请求 - 接收加密数据并解密
app.post('/api/secure/data', (req, res) => {
    try {
        const { encryptedData, iv } = req.body;
        
        // 记录接收到的加密数据
        console.log('接收到加密数据:', encryptedData);
        console.log('接收到IV:', iv);
        
        // 假设我们有一个测试密钥
        const key = '0123456789abcdef';
        
        // 解密数据
        let decryptedData = null;
        if (encryptedData) {
            // 解码Base64
            const encryptedBuffer = Buffer.from(encryptedData, 'base64');
            // 使用SM4解密
            decryptedData = sm4.decrypt(encryptedBuffer.toString('hex'), key, { mode: 'cbc', iv });
        }
        
        return res.json({
            success: true,
            message: '数据已接收并解密',
            decryptedData
        });
    } catch (error) {
        logError(`解密失败: ${error.message}`);
        return res.status(400).json({
            success: false,
            message: '解密失败',
            error: error.message
        });
    }
});

// 测试签名验证
app.post('/api/verify/signature', (req, res) => {
    try {
        const { data, signature, publicKey } = req.body;
        
        // 记录接收到的数据
        console.log('接收到数据:', data);
        console.log('接收到签名:', signature);
        
        // 验证签名
        let isValid = false;
        if (data && signature && publicKey) {
            isValid = sm2.doVerifySignature(data, signature, publicKey);
        }
        
        return res.json({
            success: true,
            isValid
        });
    } catch (error) {
        logError(`签名验证失败: ${error.message}`);
        return res.status(400).json({
            success: false,
            message: '签名验证失败',
            error: error.message
        });
    }
});

// 测试加密响应
app.post('/api/encrypt/response', (req, res) => {
    try {
        const { data, key, iv } = req.body;
        
        // 记录接收到的数据
        console.log('接收到待加密数据:', data);
        
        // 加密响应数据
        let encryptedData = null;
        if (data && key && iv) {
            // 使用SM4加密
            const encryptedHex = sm4.encrypt(data, key, { mode: 'cbc', iv });
            // 转换为Base64
            encryptedData = Buffer.from(encryptedHex, 'hex').toString('base64');
        }
        
        return res.json({
            success: true,
            encryptedData
        });
    } catch (error) {
        logError(`加密失败: ${error.message}`);
        return res.status(400).json({
            success: false,
            message: '加密失败',
            error: error.message
        });
    }
});

// 测试流量控制
let requestCounter = {};
app.get('/api/test/rate-limit', (req, res) => {
    const appId = req.headers['x-app-id'] || 'unknown';
    
    // 简单的计数器实现
    if (!requestCounter[appId]) {
        requestCounter[appId] = 0;
    }
    requestCounter[appId]++;
    
    return res.json({
        success: true,
        appId,
        requestCount: requestCounter[appId],
        timestamp: new Date().toISOString()
    });
});

// 测试防重放
const usedNonces = new Set();
app.post('/api/test/replay-protection', (req, res) => {
    const { nonce, timestamp } = req.body;
    const appId = req.headers['x-app-id'] || 'unknown';
    
    // 检查nonce是否已使用
    const nonceKey = `${appId}:${nonce}`;
    if (usedNonces.has(nonceKey)) {
        return res.status(403).json({
            success: false,
            message: '检测到重放攻击'
        });
    }
    
    // 检查时间戳是否在有效期内
    const currentTime = Math.floor(Date.now() / 1000);
    const timestampNum = parseInt(timestamp, 10);
    if (isNaN(timestampNum) || Math.abs(currentTime - timestampNum) > 300) {
        return res.status(403).json({
            success: false,
            message: '时间戳无效或已过期'
        });
    }
    
    // 记录已使用的nonce
    usedNonces.add(nonceKey);
    
    // 设置nonce过期（示例中使用1小时）
    setTimeout(() => {
        usedNonces.delete(nonceKey);
    }, 3600 * 1000);
    
    return res.json({
        success: true,
        message: '请求有效',
        appId,
        nonce,
        timestamp
    });
});

// 错误处理中间件
app.use((err, req, res, next) => {
  logError(`Error: ${err.message}\nStack: ${err.stack}`);
  res.status(500).json({
    code: 500,
    message: 'Internal Server Error',
    timestamp: new Date().toISOString()
  });
});

// 404处理
app.use((req, res) => {
  res.status(404).json({
    code: 404,
    message: 'API not found===============================',
    timestamp: new Date().toISOString()
  });
});

// 设定端口
const PORT = process.env.PORT || 3000;

// 启动服务器并监听端口
app.listen(PORT, () => {
    console.log(`Backend server is running on http://localhost:${PORT}`);
    console.log(`Health check: http://localhost:${PORT}/health`);
});