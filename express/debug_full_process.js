// 完整流程调试脚本，模拟从Node.js客户端到OpenResty的整个过程
const sm2 = require('sm-crypto').sm2;
const sm4 = require('sm-crypto').sm4;
const axios = require('axios');

// 测试配置
const CONFIG = {
  gateway_url: 'http://localhost:8082',
  appid: 'app_001',
  sm2_private_key: '11c5d8a788c705515494f4ed06e82e4ad70a6e7ef44b9c540ee9bc56a322b0da',
  sm2_public_key: '0459e8c074bb5b0407026cba0dd8bf61bd25fe4283608f6e7c75055124f4ee01f5008afe6e2a9e257861e541113b78e11a82821d03a8e52307876470005db1cf98',
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

// 构建签名数据
function buildSignatureData(method, uri, queryString, body, nonce, timestamp) {
  const parts = [method, uri, queryString || '', body || '', nonce, timestamp.toString()];
  return parts.join('&');
}

// 生成签名
function generateSignature(data, privateKey) {
  return sm2.doSignature(data, privateKey);
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

// 模拟OpenResty解密
function openrestyDecrypt(ciphertext, key, iv) {
  console.log('\n=== 模拟OpenResty解密 ===');
  console.log('  密钥:', key);
  console.log('  IV:', iv);
  console.log('  密钥长度:', key.length);
  console.log('  IV长度:', iv.length);
  console.log('  加密数据 (base64):', ciphertext);
  
  try {
    // 解码base64密文，直接得到二进制数据
    const cipher_bytes = Buffer.from(ciphertext, 'base64');
    console.log('  解码后的缓冲区长度:', cipher_bytes.length);
    console.log('  解码后的缓冲区 (hex):', cipher_bytes.toString('hex'));
    
    // 确保密钥和IV都是16字节长度
    const fixed_key = key.length === 16 ? key : (key.length > 16 ? key.substring(0, 16) : key.padEnd(16, '\0'));
    const fixed_iv = iv.length === 16 ? iv : (iv.length > 16 ? iv.substring(0, 16) : iv.padEnd(16, '\0'));
    
    console.log('  固定后密钥:', fixed_key);
    console.log('  固定后IV:', fixed_iv);
    
    // 转换为十六进制
    const hexKey = convertToHex(fixed_key);
    const hexIv = convertToHex(fixed_iv);
    
    console.log('  转换后密钥 (hex):', hexKey);
    console.log('  转换后IV (hex):', hexIv);
    
    // 使用十六进制格式的密钥和IV进行解密
    const result = sm4.decrypt(cipher_bytes.toString('hex'), hexKey, { mode: 'cbc', iv: hexIv });
    console.log('  解密结果:', result);
    return result;
  } catch (error) {
    console.error('OpenResty解密过程中发生错误:', error.message);
    throw error;
  }
}

// 生成nonce
function generateNonce() {
  // 生成 20 位纯数字：10 位随机数 + 10 位秒级时间戳，满足网关 10-20 位要求
  const random10 = Math.floor(Math.random() * 1e10).toString().padStart(10, '0');
  const ts10 = Math.floor(Date.now() / 1000).toString().padStart(10, '0');
  return random10 + ts10;
}

// 模拟发送API请求的过程
async function simulateApiRequest(method, path, body = '', queryString = '') {
  try {
    const nonce = generateNonce();
    const timestamp = Math.floor(Date.now() / 1000);
    
    // 构建签名数据
    const signatureData = buildSignatureData(method, path, queryString, body, nonce, timestamp);
    
    // 生成签名
    const signature = generateSignature(signatureData, CONFIG.sm2_private_key);
    
    // 加密请求体
    const encryptedBody = encryptRequestBody(body, CONFIG.sm4_key, CONFIG.sm4_iv);
    
    // 构建请求头
    const headers = {
      'X-App-ID': CONFIG.appid,
      'X-Signature': signature,
      'X-Nonce': nonce,
      'X-Timestamp': timestamp.toString(),
      'Content-Type': 'application/json'
    };
    
    // 构建完整URL
    let url = `${CONFIG.gateway_url}${path}`;
    if (queryString) {
      url += `?${queryString}`;
    }
    
    console.log(`\n=== 模拟发送 ${method} 请求到 ${url} ===`);
    console.log('请求头:', JSON.stringify(headers, null, 2));
    console.log('原始请求体:', body);
    console.log('加密后请求体:', encryptedBody);
    console.log('签名数据:', signatureData);
    console.log('签名:', signature);
    
    // 检查加密数据
    console.log('\n=== 检查加密数据 ===');
    console.log('加密数据类型:', typeof encryptedBody);
    console.log('加密数据长度:', encryptedBody.length);
    console.log('加密数据内容:', encryptedBody);
    
    // 尝试解密验证
    const decryptedBody = openrestyDecrypt(encryptedBody, CONFIG.sm4_key, CONFIG.sm4_iv);
    console.log('解密结果匹配:', decryptedBody === body ? '成功' : '失败');
    
    // 模拟OpenResty接收请求
    console.log('\n=== 模拟OpenResty接收请求 ===');
    console.log('接收到的请求体类型:', typeof encryptedBody);
    console.log('接收到的请求体长度:', encryptedBody.length);
    
    // 检查是否有隐藏字符或编码问题
    const buffer = Buffer.from(encryptedBody, 'utf-8');
    console.log('请求体Buffer长度:', buffer.length);
    console.log('请求体Buffer (hex):', buffer.toString('hex'));
    
    // 检查base64有效性
    try {
      const decoded = Buffer.from(encryptedBody, 'base64');
      console.log('Base64解码成功，解码后长度:', decoded.length);
      console.log('Base64解码后 (hex):', decoded.toString('hex'));
    } catch (e) {
      console.error('Base64解码失败:', e.message);
    }
    
    console.log('=====================================\n');
    
  } catch (error) {
    console.error('模拟请求失败:', error.message);
    if (error.stack) {
      console.error('错误堆栈:', error.stack);
    }
  }
}

// 测试数据
const testData = '{"name":"Test User","email":"test@example.com"}';

// 运行测试
async function runTest() {
  console.log('开始完整流程调试...\n');
  
  await simulateApiRequest('POST', '/api/user/create', testData);
}

runTest();