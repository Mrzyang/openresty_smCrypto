// 分析密钥格式差异
const sm2 = require('sm-crypto').sm2;
const fs = require('fs');

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

// --- 添加PEM格式转换函数 ---
function hexToPem(privateKeyHex, publicKeyHex) {
  console.log('原始十六进制私钥:', privateKeyHex);
  console.log('原始十六进制公钥:', publicKeyHex);
  
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
  
  console.log('私钥DER长度:', privateKeyDer.length / 2);
  console.log('私钥DER:', privateKeyDer);
  
  // 构造PEM格式的私钥
  const privateKeyPem = '-----BEGIN PRIVATE KEY-----\n' +
    Buffer.from(privateKeyDer, 'hex').toString('base64').match(/.{1,64}/g).join('\n') +
    '\n-----END PRIVATE KEY-----';
  
  console.log('生成的私钥PEM:');
  console.log(privateKeyPem);
  
  // 构造公钥部分 (修正为正确的格式)
  // SEQUENCE (2 elem)
  //   SEQUENCE (2 elem)
  //     OBJECT IDENTIFIER 1.2.156.10197.1.301 sm2
  //     NULL
  //   BIT STRING (65 bytes)
  
  // 修正公钥格式，添加NULL参数
  const publicKeyAlgorithm = '300d06072a811ccf5501822d0500'; // SEQUENCE with OID and NULL
  const publicKeyBitString = '034200' + publicKeyHex; // BIT STRING with public key
  
  // 构造完整的公钥DER
  const publicKeySequence = publicKeyAlgorithm + publicKeyBitString;
  const publicKeyLength = (publicKeySequence.length / 2).toString(16).padStart(2, '0');
  const publicKeyDer = '30' + publicKeyLength + publicKeySequence;
  
  console.log('公钥DER长度:', publicKeyDer.length / 2);
  console.log('公钥DER:', publicKeyDer);
  
  // 构造PEM格式的公钥
  const publicKeyPem = '-----BEGIN PUBLIC KEY-----\n' +
    Buffer.from(publicKeyDer, 'hex').toString('base64').match(/.{1,64}/g).join('\n') +
    '\n-----END PUBLIC KEY-----';
  
  console.log('生成的公钥PEM:');
  console.log(publicKeyPem);
  
  return {
    privateKeyPem,
    publicKeyPem
  };
}

// 生成测试密钥对
function generateTestKeys() {
  const keyPair = sm2.generateKeyPairHex();
  console.log('生成的十六进制密钥对:');
  console.log('私钥:', keyPair.privateKey);
  console.log('公钥:', keyPair.publicKey);
  
  // 同时生成PEM格式的密钥
  const pemKeys = hexToPem(keyPair.privateKey, keyPair.publicKey);
  return {
    privateKeyHex: keyPair.privateKey,
    publicKeyHex: keyPair.publicKey,
    privateKeyPem: pemKeys.privateKeyPem,
    publicKeyPem: pemKeys.publicKeyPem
  };
}

// 测试签名和验签
function testSignVerify(keys) {
  const testData = 'Hello, SM2!';
  console.log('\n测试数据:', testData);
  
  // 使用十六进制私钥签名
  const signature = sm2.doSignature(testData, keys.privateKeyHex);
  console.log('\n使用十六进制私钥生成的签名:', signature);
  
  // 使用十六进制公钥验签
  const isValid1 = sm2.doVerifySignature(testData, signature, keys.publicKeyHex);
  console.log('\n使用十六进制公钥验签结果:', isValid1 ? '成功' : '失败');
  
  // 使用PEM格式公钥验签（这通常会失败，因为sm-crypto不直接支持PEM格式）
  try {
    // 这里只是演示，实际上sm-crypto不支持直接使用PEM格式验签
    console.log('\n注意：sm-crypto库不直接支持PEM格式的密钥进行签名和验签');
  } catch (error) {
    console.log('\n使用PEM格式公钥验签失败（预期）:', error.message);
  }
}

// 主函数
async function main() {
  console.log('=== 分析密钥格式差异 ===');
  
  // 生成测试密钥对
  const keys = generateTestKeys();
  
  // 测试签名和验签
  testSignVerify(keys);
  
  // 从Redis获取实际的密钥
  console.log('\n=== 从Redis获取实际密钥 ===');
  const appConfig = await getAppConfigFromRedis('app_001');
  if (appConfig) {
    console.log('从Redis获取的App配置:');
    console.log('- App ID:', appConfig.appid);
    console.log('- SM2私钥(PEM):', appConfig.sm2_private_key_pem ? appConfig.sm2_private_key_pem.substring(0, 50) + '...' : '未找到');
    console.log('- SM2公钥(PEM):', appConfig.sm2_public_key_pem ? appConfig.sm2_public_key_pem.substring(0, 50) + '...' : '未找到');
  } else {
    console.log('未找到App配置');
  }
  
  console.log('\n=== 分析完成 ===');
}

// 运行主函数
main().catch(console.error);