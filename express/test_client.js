// API网关测试客户端
const sm2 = require('sm-crypto').sm2;
const sm3 = require('sm-crypto').sm3;
const sm4 = require('sm-crypto').sm4;
const axios = require('axios');

// 测试配置
const CONFIG = {
  gateway_url: 'http://localhost:8082',
  appid: 'app_001',
  sm2_private_key: 'your_sm2_private_key_here',
  sm2_public_key: 'your_sm2_public_key_here',
  // 添加PEM格式的密钥
  sm2_private_key_pem: 'your_sm2_private_key_pem_here',
  sm2_public_key_pem: 'your_sm2_public_key_pem_here',
  gateway_sm2_public_key_pem: 'your_gateway_sm2_public_key_pem_here',
  sm4_key: '1234567890abcdef', // 16字节密钥
  sm4_iv: 'abcdef1234567890'   // 16字节IV
};

// 转换函数：将16字节字符串转换为32字符的十六进制字符串
function convertToHex(keyOrIv) {
    if (keyOrIv.length === 16) {
        return Buffer.from(keyOrIv, 'utf-8').toString('hex');
    } else if (keyOrIv.length === 32) {
        return keyOrIv; // 已经是十六进制格式
    } else {
        // 其他情况，先调整长度再转换
        const fixed = keyOrIv.length > 16 ? keyOrIv.substring(0, 16) : keyOrIv.padEnd(16, '\0');
        return Buffer.from(fixed, 'utf-8').toString('hex');
    }
}

// 生成测试用的SM2密钥对
function generateTestKeys() {
  const keyPair = sm2.generateKeyPairHex();
  // 同时生成PEM格式的密钥
  const pemKeys = hexToPem(keyPair.privateKey, keyPair.publicKey);
  console.log('=== 生成测试密钥对 ===');
  console.log('SM2 私钥:', keyPair.privateKey);
  console.log('SM2 公钥:', keyPair.publicKey);
  console.log('SM2 私钥 (PEM):', pemKeys.privateKeyPem);
  console.log('SM2 公钥 (PEM):', pemKeys.publicKeyPem);
  console.log('SM4 密钥:', CONFIG.sm4_key);
  console.log('SM4 IV:', CONFIG.sm4_iv);
  console.log('========================\n');
  
  return {
    ...keyPair,
    privateKeyPem: pemKeys.privateKeyPem,
    publicKeyPem: pemKeys.publicKeyPem
  };
}

// --- 添加PEM格式转换函数 ---
function hexToPem(privateKeyHex, publicKeyHex) {
  // 构造SM2私钥的DER格式
  // SEQUENCE (3 elem)
  //   INTEGER 1
  //   OCTET STRING (32 bytes)
  //   [0] (1 elem) OBJECT IDENTIFIER 1.2.156.10197.1.301 sm2
  //   [1] (1 elem) BIT STRING (65 bytes)
  
  // 构造私钥部分
  const version = '020101'; // INTEGER 1
  const privateKeyOctet = '0420' + privateKeyHex; // OCTET STRING with 32 bytes private key
  const algorithmId = 'a00b06092a811ccf5501822d'; // [0] OBJECT IDENTIFIER sm2
  const publicKeyContext = 'a144034200' + publicKeyHex; // [1] BIT STRING with public key
  
  // 构造完整的私钥DER
  const privateKeySequence = version + privateKeyOctet + algorithmId + publicKeyContext;
  const privateKeyLength = (privateKeySequence.length / 2).toString(16).padStart(2, '0');
  const privateKeyDer = '30' + privateKeyLength + privateKeySequence;
  
  // 构造PEM格式的私钥
  const privateKeyPem = '-----BEGIN PRIVATE KEY-----\n' +
    Buffer.from(privateKeyDer, 'hex').toString('base64').match(/.{1,64}/g).join('\n') +
    '\n-----END PRIVATE KEY-----';
  
  // 构造公钥部分
  // SEQUENCE (2 elem)
  //   SEQUENCE (2 elem)
  //     OBJECT IDENTIFIER 1.2.156.10197.1.301 sm2
  //     NULL
  //   BIT STRING (65 bytes)
  
  const publicKeyAlgorithm = '301306072a811ccf5501822d06082a811ccf5501822d'; // SEQUENCE of algorithm
  const publicKeyBitString = '034200' + publicKeyHex; // BIT STRING with public key
  
  // 构造完整的公钥DER
  const publicKeySequence = publicKeyAlgorithm + publicKeyBitString;
  const publicKeyLength = (publicKeySequence.length / 2).toString(16).padStart(4, '0');
  const publicKeyDer = '30' + publicKeyLength + publicKeySequence;
  
  // 构造PEM格式的公钥
  const publicKeyPem = '-----BEGIN PUBLIC KEY-----\n' +
    Buffer.from(publicKeyDer, 'hex').toString('base64').match(/.{1,64}/g).join('\n') +
    '\n-----END PUBLIC KEY-----';
  
  return {
    privateKeyPem,
    publicKeyPem
  };
}

// 构建签名数据
function buildSignatureData(method, uri, queryString, body, nonce, timestamp) {
  const parts = [method, uri, queryString || '', body || '', nonce, timestamp.toString()];
  return parts.join('&');
}

// 生成签名 (支持PEM格式私钥)
function generateSignature(data, privateKeyPem) {
  // 注意：当前sm-crypto库的doSignature方法不直接支持PEM格式私钥
  // 在实际使用中，我们仍然需要使用十六进制格式的私钥进行签名
  // 但在网关端，我们只支持PEM格式的密钥
  console.warn('注意：当前sm-crypto库的doSignature方法不直接支持PEM格式私钥');
  return null;
}

// 加密请求体
function encryptRequestBody(body, key, iv) {
  if (!body || body === '') {
    return '';
  }
  
  console.log('加密参数:');
  console.log('  密钥:', key);
  console.log('  IV:', iv);
  console.log('  密钥长度:', key.length);
  console.log('  IV长度:', iv.length);
  console.log('  原始请求体:', body);
  
  try {
    // 使用转换函数将16字节字符串转换为32字符的十六进制字符串
    const hexKey = convertToHex(key);
    const hexIv = convertToHex(iv);
    
    console.log('  转换后密钥 (hex):', hexKey);
    console.log('  转换后IV (hex):', hexIv);
    console.log('  转换后密钥长度:', hexKey.length);
    console.log('  转换后IV长度:', hexIv.length);
    
    // 使用十六进制格式的密钥和IV进行加密
    const encrypted = sm4.encrypt(body, hexKey, { mode: 'cbc', iv: hexIv });
    const result = Buffer.from(encrypted, 'hex').toString('base64');
    console.log('  加密结果 (base64):', result);
    return result;
  } catch (error) {
    console.error('加密过程中发生错误:', error.message);
    throw error;
  }
}

// 解密响应体
function decryptResponseBody(encryptedBody, key, iv) {
  if (!encryptedBody || encryptedBody === '') {
    return '';
  }
  if (typeof encryptedBody !== 'string') {
    try {
      return JSON.stringify(encryptedBody);
    } catch (e) {
      return String(encryptedBody);
    }
  }
  
  console.log('解密参数:');
  console.log('  密钥:', key);
  console.log('  IV:', iv);
  console.log('  密钥长度:', key.length);
  console.log('  IV长度:', iv.length);
  console.log('  加密数据 (base64):', encryptedBody);
  
  try {
    // 使用转换函数将16字节字符串转换为32字符的十六进制字符串
    const hexKey = convertToHex(key);
    const hexIv = convertToHex(iv);
    
    console.log('  转换后密钥 (hex):', hexKey);
    console.log('  转换后IV (hex):', hexIv);
    console.log('  转换后密钥长度:', hexKey.length);
    console.log('  转换后IV长度:', hexIv.length);
    
    const encryptedBuffer = Buffer.from(encryptedBody, 'base64');
    console.log('  解码后的缓冲区长度:', encryptedBuffer.length);
    
    // 使用十六进制格式的密钥和IV进行解密
    const result = sm4.decrypt(encryptedBuffer.toString('hex'), hexKey, { mode: 'cbc', iv: hexIv });
    console.log('  解密结果:', result);
    return result;
  } catch (error) {
    console.error('解密过程中发生错误:', error.message);
    throw error;
  }
}

// 验证响应签名 (支持PEM格式公钥)
function verifyResponseSignature(body, signature, publicKeyPem) {
  if (!signature || !body) {
    return false;
  }
  
  // 注意：当前sm-crypto库的doVerifySignature方法不直接支持PEM格式公钥
  // 在实际使用中，我们仍然需要使用十六进制格式的公钥进行验签
  // 但在网关端，我们只支持PEM格式的密钥
  console.warn('注意：当前sm-crypto库的doVerifySignature方法不直接支持PEM格式公钥');
  return false;
}

// 生成nonce
function generateNonce() {
  // 生成 20 位纯数字：10 位随机数 + 10 位秒级时间戳，满足网关 10-20 位要求
  const random10 = Math.floor(Math.random() * 1e10).toString().padStart(10, '0');
  const ts10 = Math.floor(Date.now() / 1000).toString().padStart(10, '0');
  return random10 + ts10;
}

// 发送API请求
async function sendApiRequest(method, path, body = '', queryString = '') {
  try {
    const nonce = generateNonce();
    const timestamp = Math.floor(Date.now() / 1000);
    
    // 构建签名数据
    const signatureData = buildSignatureData(method, path, queryString, body, nonce, timestamp);
    
    // 生成签名 (使用十六进制格式的私钥，因为sm-crypto库不直接支持PEM格式)
    const signature = sm2.doSignature(signatureData, CONFIG.sm2_private_key);
    
    // 加密请求体
    const encryptedBody = encryptRequestBody(body, CONFIG.sm4_key, CONFIG.sm4_iv);
    
    // 构建请求头
    const headers = {
      'X-App-ID': CONFIG.appid,
      'X-Signature': signature,
      'X-Nonce': nonce,
      'X-Timestamp': timestamp.toString(),
      'Content-Type': 'application/octet-stream'
    };
    
    // 构建完整URL
    let url = `${CONFIG.gateway_url}${path}`;
    if (queryString) {
      url += `?${queryString}`;
    }
    
    console.log(`=== 发送 ${method} 请求到 ${url} ===`);
    console.log('请求头:', headers);
    console.log('原始请求体:', body);
    console.log('加密后请求体:', encryptedBody);
    console.log('签名数据:', signatureData);
    console.log('签名:', signature);
    console.log('=====================================\n');
    
    // 确保Content-Type正确设置
    headers['Content-Type'] = 'application/octet-stream';
    
    // 发送请求
    const response = await axios({
      method: method.toLowerCase(),
      url: url,
      headers: headers,
      data: encryptedBody,
      timeout: 30000,
      transformRequest: [(data, headers) => {
        // 确保发送的是原始数据，而不是JSON字符串
        return data;
      }]
    });
    
    console.log(`=== 收到响应 ===`);
    console.log('状态码:', response.status);
    console.log('响应头:', response.headers);
    console.log('加密响应体:', response.data);
    
    // 解密响应体
    let decryptedBody;
    const xEncrypted = response.headers && (response.headers['x-encrypted'] === 'true' || response.headers['X-Encrypted'] === 'true');
    if (xEncrypted) {
      decryptedBody = decryptResponseBody(response.data, CONFIG.sm4_key, CONFIG.sm4_iv);
    } else {
      decryptedBody = typeof response.data === 'string' ? response.data : JSON.stringify(response.data);
    }
    console.log('解密后响应体:', decryptedBody);
    
    // 验证响应签名
    const responseSignature = response.headers['x-signature'];
    if (responseSignature && xEncrypted === true) {
      // 使用PEM格式的公钥进行验签
      const publicKey = CONFIG.gateway_sm2_public_key_pem || CONFIG.sm2_public_key_pem;
      const isValidSignature = verifyResponseSignature(decryptedBody, responseSignature, publicKey);
      console.log('响应签名验证:', isValidSignature ? '成功' : '失败');
    }
    
    console.log('==================\n');
    
    return {
      status: response.status,
      headers: response.headers,
      data: decryptedBody,
      encryptedData: response.data
    };
    
  } catch (error) {
    console.error('请求失败:', error.message);
    if (error.response) {
      console.error('错误状态码:', error.response.status);
      console.error('错误响应头:', error.response.headers);
      console.error('错误响应体:', error.response.data);
    } else if (error.request) {
      console.error('请求已发送但无响应:', error.request);
    } else {
      console.error('请求配置错误:', error.message);
    }
    throw error;
  }
}

// 从Redis获取App配置
async function getAppConfigFromRedis(appid) {
  const Redis = require('ioredis');
  const redisClient = new Redis({
    host: '192.168.110.45',
    port: 6379,
    retryDelayOnFailover: 100,
    enableReadyCheck: false,
    maxRetriesPerRequest: null,
  });
  
  try {
    const appData = await redisClient.get(`app:${appid}`);
    if (appData) {
      const appConfig = JSON.parse(appData);
      return appConfig;
    }
  } catch (error) {
    console.error('获取App配置失败:', error.message);
  } finally {
    redisClient.quit();
  }
  
  return null;
}

// 测试函数
async function runTests() {
  console.log('开始API网关测试...\n');
  
  try {
    // 生成测试密钥
    const keyPair = generateTestKeys();
    CONFIG.sm2_private_key = keyPair.privateKey;
    CONFIG.sm2_public_key = keyPair.publicKey;
    CONFIG.sm2_private_key_pem = keyPair.privateKeyPem;
    CONFIG.sm2_public_key_pem = keyPair.publicKeyPem;
    
    // 从Redis获取App配置，包括网关签名公钥
    const appConfig = await getAppConfigFromRedis('app_001');
    if (appConfig) {
      if (appConfig.gateway_sm2_public_key) {
        CONFIG.gateway_sm2_public_key = appConfig.gateway_sm2_public_key;
        console.log('获取到网关签名公钥(HEX)');
      }
      if (appConfig.gateway_sm2_public_key_pem) {
        CONFIG.gateway_sm2_public_key_pem = appConfig.gateway_sm2_public_key_pem;
        console.log('获取到网关签名公钥(PEM)');
      }
    }
    
    // 测试1: 健康检查
    console.log('测试1: 健康检查');
    await sendApiRequest('GET', '/health');
    
    // 测试2: 获取用户信息
    console.log('测试2: 获取用户信息');
    await sendApiRequest('GET', '/api/user/info');
    
    // 测试3: 获取用户列表
    console.log('测试3: 获取用户列表');
    await sendApiRequest('GET', '/api/user/list');
    
    // 测试4: 创建用户
    console.log('测试4: 创建用户');
    const createUserData = JSON.stringify({
      name: 'Test User',
      email: 'test@example.com'
    });
    await sendApiRequest('POST', '/api/user/create', createUserData);
    
    // 测试5: 系统状态
    console.log('测试5: 系统状态');
    await sendApiRequest('GET', '/api/system/status');
    
    // 测试6: 带查询参数的请求
    console.log('测试6: 带查询参数的请求');
    await sendApiRequest('GET', '/api/user/list', '', 'page=1&size=10');
    
    console.log('所有测试完成！');
    
  } catch (error) {
    console.error('测试失败:', error.message);
  }
}

// 单独测试函数
async function testSingleApi(method, path, body = '') {
  try {
    const keyPair = generateTestKeys();
    CONFIG.sm2_private_key = keyPair.privateKey;
    CONFIG.sm2_public_key = keyPair.publicKey;
    CONFIG.sm2_private_key_pem = keyPair.privateKeyPem;
    CONFIG.sm2_public_key_pem = keyPair.publicKeyPem;
    
    // 从Redis获取App配置，包括网关签名公钥
    const appConfig = await getAppConfigFromRedis('app_001');
    if (appConfig) {
      if (appConfig.gateway_sm2_public_key) {
        CONFIG.gateway_sm2_public_key = appConfig.gateway_sm2_public_key;
      }
      if (appConfig.gateway_sm2_public_key_pem) {
        CONFIG.gateway_sm2_public_key_pem = appConfig.gateway_sm2_public_key_pem;
      }
    }
    
    await sendApiRequest(method, path, body);
  } catch (error) {
    console.error('测试失败:', error.message);
  }
}

// 命令行参数处理
const args = process.argv.slice(2);
if (args.length > 0) {
  const command = args[0];
  if (command === 'test') {
    runTests();
  } else if (command === 'single' && args.length >= 3) {
    const method = args[1];
    const path = args[2];
    const body = args[3] || '';
    testSingleApi(method, path, body);
  } else {
    console.log('用法:');
    console.log('  node test_client.js test                    # 运行所有测试');
    console.log('  node test_client.js single GET /api/user/info  # 测试单个API');
    console.log('  node test_client.js single POST /api/user/create \'{"name":"test"}\'  # 测试POST请求');
  }
} else {
  runTests();
}

module.exports = {
  sendApiRequest,
  generateTestKeys,
  buildSignatureData,
  generateSignature,
  encryptRequestBody,
  decryptResponseBody,
  verifyResponseSignature,
  getAppConfigFromRedis
};