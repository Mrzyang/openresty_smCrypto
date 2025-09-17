// 捕获请求体的简单服务器
const express = require('express');
const app = express();

// 中间件：记录请求体
app.use((req, res, next) => {
  let body = '';
  req.on('data', chunk => {
    body += chunk.toString();
  });
  req.on('end', () => {
    req.body = body;
    console.log('=== 收到请求 ===');
    console.log('方法:', req.method);
    console.log('路径:', req.path);
    console.log('请求头:', req.headers);
    console.log('请求体:', req.body);
    console.log('请求体类型:', typeof req.body);
    console.log('请求体长度:', req.body.length);
    
    // 检查是否为base64
    if (req.body) {
      try {
        const buffer = Buffer.from(req.body, 'base64');
        console.log('Base64解码成功，长度:', buffer.length);
      } catch (e) {
        console.log('Base64解码失败:', e.message);
      }
    }
    
    next();
  });
});

// 健康检查
app.get('/health', (req, res) => {
  res.json({ status: 'healthy' });
});

// 用户信息
app.get('/api/user/info', (req, res) => {
  res.json({ name: 'Test User', email: 'test@example.com' });
});

// 创建用户
app.post('/api/user/create', (req, res) => {
  console.log('收到创建用户请求，解密后的数据应该是:', req.body);
  res.json({ message: 'User created successfully' });
});

// 启动服务器
const PORT = 3000;
app.listen(PORT, '127.0.0.1', () => {
  console.log(`服务器运行在 http://127.0.0.1:${PORT}`);
});