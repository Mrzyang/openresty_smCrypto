// 导入 express 和 morgan
const express = require('express');
const morgan = require('morgan');
const cors = require('cors');
const helmet = require('helmet');
const Redis = require('ioredis');
const smCrypto = require('sm-crypto');
const sm2 = smCrypto.sm2;
const sm3 = smCrypto.sm3;
const sm4 = smCrypto.sm4;
const fs = require('fs');
const path = require('path');

// 创建 Express 应用
const app = express();

// 创建日志目录
const logDir = path.join(__dirname, 'logs');
if (!fs.existsSync(logDir)) {
  fs.mkdirSync(logDir, { recursive: true });
}

// 创建日志写入流
const accessLogStream = fs.createWriteStream(path.join(logDir, 'access.log'), { flags: 'a' });
const requestLogStream = fs.createWriteStream(path.join(logDir, 'requests.log'), { flags: 'a' });

// 自定义日志格式函数
const logRequestResponse = (req, res, next) => {
  // 捕获请求信息
  const startTime = new Date();
  const requestData = {
    timestamp: startTime.toISOString(),
    method: req.method,
    url: req.url,
    headers: req.headers,
    body: req.body,
    query: req.query,
    params: req.params,
    ip: req.ip || req.connection.remoteAddress
  };

  // 保存原始的res.end函数
  const originalEnd = res.end;
  
  // 重写res.end函数以捕获响应
  res.end = function(chunk, encoding) {
    const endTime = new Date();
    const duration = endTime - startTime;
    
    // 处理响应体，确保正确显示内容而不是Buffer对象
    let responseBody = chunk;
    if (chunk && chunk instanceof Buffer) {
      // 如果是Buffer，尝试转换为字符串
      try {
        responseBody = chunk.toString('utf8');
        // 如果是JSON字符串，尝试解析为对象以便更好地格式化
        if (responseBody.trim().startsWith('{') || responseBody.trim().startsWith('[')) {
          responseBody = JSON.parse(responseBody);
        }
      } catch (e) {
        // 如果解析失败，保持原始字符串
        responseBody = chunk.toString('utf8');
      }
    } else if (typeof chunk === 'string') {
      // 如果已经是字符串，检查是否为JSON
      try {
        if (chunk.trim().startsWith('{') || chunk.trim().startsWith('[')) {
          responseBody = JSON.parse(chunk);
        }
      } catch (e) {
        // 保持原始字符串
      }
    }
    
    // 获取响应信息
    const responseData = {
      timestamp: endTime.toISOString(),
      statusCode: res.statusCode,
      statusMessage: res.statusMessage,
      headers: res.getHeaders(),
      body: responseBody,
      duration: duration + 'ms'
    };
    
    // 记录请求和响应信息到日志文件
    const logEntry = {
      request: requestData,
      response: responseData
    };
    
    // 写入日志文件
    requestLogStream.write(JSON.stringify(logEntry, null, 2) + '\n');
    
    // 调用原始的res.end函数
    originalEnd.call(this, chunk, encoding);
  };
  
  next();
};

// Redis客户端
const redisClient = new Redis({
  host: '192.168.56.2',
  port: 6379,
  retryDelayOnFailover: 100,
  enableReadyCheck: false,
  maxRetriesPerRequest: null,
});

redisClient.on('error', (err) => {
  console.error('Redis Client Error:', err);
});

redisClient.on('connect', () => {
  console.log('Connected to Redis');
});

// 中间件
app.use(helmet());
app.use(cors());
app.use(morgan('combined', { stream: accessLogStream }));
app.use(logRequestResponse); // 添加请求响应日志记录中间件
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

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
        console.error('解密失败:', error);
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
        console.error('签名验证失败:', error);
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
        console.error('加密失败:', error);
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
  console.error('Error:', err);
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
