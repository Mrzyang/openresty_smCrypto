const fs = require('fs');
const path = require('path');
const util = require('util');

// 创建日志目录
const logDir = path.join(__dirname, 'logs');
if (!fs.existsSync(logDir)) {
  fs.mkdirSync(logDir, { recursive: true });
}

// 创建访问日志和错误日志的写入流
const accessLogStream = fs.createWriteStream(path.join(logDir, 'access.log'), { flags: 'a' });
const errorLogStream = fs.createWriteStream(path.join(logDir, 'error.log'), { flags: 'a' });

// 获取当前时间戳
const getCurrentTimestamp = () => {
  return new Date().toISOString();
};

// 格式化请求信息
const formatRequestInfo = (req) => {
  const startTime = Date.now();
  
  return {
    timestamp: getCurrentTimestamp(),
    method: req.method,
    url: req.url,
    headers: req.headers,
    query: req.query,
    params: req.params,
    body: req.body,
    bodySize: req.body ? Buffer.byteLength(JSON.stringify(req.body)) : 0,
    bodyType: typeof req.body,
    isBuffer: Buffer.isBuffer(req.body),
    startTime
  };
};

// 格式化响应信息
const formatResponseInfo = (req, res, responseInfo) => {
  const endTime = Date.now();
  const duration = endTime - responseInfo.startTime;
  
  return {
    timestamp: getCurrentTimestamp(),
    method: req.method,
    url: req.url,
    statusCode: res.statusCode,
    statusMessage: res.statusMessage,
    headers: res.getHeaders(),
    body: responseInfo.body,
    bodySize: responseInfo.body ? Buffer.byteLength(JSON.stringify(responseInfo.body)) : 0,
    bodyType: typeof responseInfo.body,
    duration: duration + 'ms',
    startTime: responseInfo.startTime,
    endTime: endTime
  };
};

// 记录访问日志
const logAccess = (message) => {
  const logMessage = `[${getCurrentTimestamp()}] ACCESS: ${message}\n`;
  console.log(logMessage.trim());
  accessLogStream.write(logMessage);
};

// 记录错误日志
const logError = (message) => {
  const logMessage = `[${getCurrentTimestamp()}] ERROR: ${message}\n`;
  console.error(logMessage.trim());
  errorLogStream.write(logMessage);
};

// 记录请求信息（美化JSON格式）
const logRequest = (reqInfo) => {
  const logEntry = {
    event: 'REQUEST',
    timestamp: reqInfo.timestamp,
    request: {
      method: reqInfo.method,
      url: reqInfo.url,
      headers: reqInfo.headers,
      query: reqInfo.query,
      params: reqInfo.params,
      body: reqInfo.body,
      bodySize: reqInfo.bodySize + ' bytes',
      bodyType: reqInfo.bodyType,
      isBuffer: reqInfo.isBuffer
    }
  };
  
  const formattedLog = JSON.stringify(logEntry, null, 2);
  console.log(formattedLog);
  accessLogStream.write(formattedLog + '\n');
};

// 记录响应信息（美化JSON格式）
const logResponse = (resInfo) => {
  const logEntry = {
    event: 'RESPONSE',
    timestamp: resInfo.timestamp,
    response: {
      method: resInfo.method,
      url: resInfo.url,
      statusCode: resInfo.statusCode,
      statusMessage: resInfo.statusMessage,
      headers: resInfo.headers,
      body: resInfo.body,
      bodySize: resInfo.bodySize + ' bytes',
      bodyType: resInfo.bodyType,
      duration: resInfo.duration
    }
  };
  
  const formattedLog = JSON.stringify(logEntry, null, 2);
  console.log(formattedLog);
  accessLogStream.write(formattedLog + '\n');
};

// 创建日志中间件
const requestLogger = (req, res, next) => {
  // 格式化请求信息
  const reqInfo = formatRequestInfo(req);
  logRequest(reqInfo);
  
  // 保存原始的res.end方法
  const originalEnd = res.end;
  
  // 保存响应体
  let responseBody = null;
  
  // 重写res.end方法以捕获响应体
  res.end = function(chunk, encoding) {
    // 尝试解析响应体
    if (chunk) {
      try {
        if (Buffer.isBuffer(chunk)) {
          responseBody = chunk.toString();
        } else if (typeof chunk === 'string') {
          responseBody = chunk;
        } else {
          responseBody = JSON.stringify(chunk);
        }
        
        // 尝试解析JSON响应体
        try {
          responseBody = JSON.parse(responseBody);
        } catch (e) {
          // 如果不是JSON格式，保持原样
        }
      } catch (e) {
        responseBody = '[无法解析的响应体]';
      }
    }
    
    // 格式化响应信息
    const resInfo = formatResponseInfo(req, res, {
      ...reqInfo,
      body: responseBody
    });
    
    // 记录响应信息
    logResponse(resInfo);
    
    // 调用原始的res.end方法
    originalEnd.call(this, chunk, encoding);
  };
  
  next();
};

module.exports = {
  logAccess,
  logError,
  logRequest,
  logResponse,
  requestLogger
};