// 完整SM2签名验签流程调试脚本
const sm2 = require('sm-crypto').sm2;
const axios = require('axios');

// 测试配置
const CONFIG = {
  gateway_url: 'http://localhost:8082',
  appid: 'app_001'
};

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

// 构建签名数据
function buildSignatureData(method, uri, queryString, body, nonce, timestamp) {
  const parts = [method, uri, queryString || '', body || '', nonce, timestamp.toString()];
  return parts.join('&');
}

// 生成nonce
function generateNonce() {
  // 生成 20 位纯数字：10 位随机数 + 10 位秒级时间戳，满足网关 10-20 位要求
  const random10 = Math.floor(Math.random() * 1e10).toString().padStart(10, '0');
  const ts10 = Math.floor(Date.now() / 1000).toString().padStart(10, '0');
  return random10 + ts10;
}

// 测试SM2签名和网关验签
async function testFullSm2Process() {
  console.log('=== 完整SM2签名验签流程测试 ===');
  
  try {
    // 从Redis获取App配置
    const appConfig = await getAppConfigFromRedis('app_001');
    if (!appConfig) {
      console.error('无法获取App配置');
      return;
    }
    
    console.log('成功获取App配置');
    console.log('- App ID:', appConfig.appid);
    console.log('- SM2私钥(HEX):', appConfig.sm2_private_key ? appConfig.sm2_private_key.substring(0, 30) + '...' : '未找到');
    console.log('- SM2公钥(PEM):', appConfig.sm2_public_key_pem ? appConfig.sm2_public_key_pem.substring(0, 50) + '...' : '未找到');
    
    // 准备测试数据
    const method = 'POST';
    const path = '/debug/sm2_verify';
    const body = 'test data for SM2 signature';
    const nonce = generateNonce();
    const timestamp = Math.floor(Date.now() / 1000);
    
    // 构建签名数据
    const signatureData = buildSignatureData(method, path, '', body, nonce, timestamp);
    console.log('\n签名数据:', signatureData);
    
    // 使用十六进制私钥生成签名
    if (!appConfig.sm2_private_key) {
      console.error('未找到十六进制格式的私钥');
      return;
    }
    
    const signature = sm2.doSignature(signatureData, appConfig.sm2_private_key);
    console.log('\n生成的签名:', signature);
    
    // 验证本地签名
    const isValidLocal = sm2.doVerifySignature(signatureData, signature, appConfig.sm2_public_key);
    console.log('\n本地验签结果:', isValidLocal ? '成功' : '失败');
    
    // 发送到网关进行验签测试
    console.log('\n=== 发送到网关进行验签测试 ===');
    const url = `${CONFIG.gateway_url}${path}?signature=${encodeURIComponent(signature)}`;
    console.log('请求URL:', url);
    
    const headers = {
      'X-App-ID': CONFIG.appid,
      'X-Signature': signature, // 这里发送原始签名，让网关自己处理base64解码
      'X-Nonce': nonce,
      'X-Timestamp': timestamp.toString(),
      'Content-Type': 'application/octet-stream'
    };
    
    console.log('请求头:', headers);
    
    try {
      const response = await axios({
        method: 'POST',
        url: url,
        headers: headers,
        data: body,
        timeout: 10000
      });
      
      console.log('\n网关响应:');
      console.log('- 状态码:', response.status);
      console.log('- 响应体:', response.data);
      
    } catch (error) {
      console.error('\n网关请求失败:');
      if (error.response) {
        console.error('- 状态码:', error.response.status);
        console.error('- 响应体:', error.response.data);
      } else {
        console.error('- 错误信息:', error.message);
      }
    }
    
  } catch (error) {
    console.error('测试过程中发生错误:', error.message);
    console.error(error.stack);
  }
}

// 运行测试
testFullSm2Process().catch(console.error);