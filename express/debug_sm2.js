// SM2签名验签调试脚本
const sm2 = require('sm-crypto').sm2;
const Redis = require('ioredis');

// Redis连接
const client = new Redis({
  host: '192.168.110.45',
  port: 6379,
  retryDelayOnFailover: 100,
  enableReadyCheck: false,
  maxRetriesPerRequest: null,
});

client.on('error', (err) => {
  console.error('Redis Client Error:', err);
});

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
  
  // 构造PEM格式的公钥
  const publicKeyPem = '-----BEGIN PUBLIC KEY-----\n' +
    Buffer.from(publicKeyDer, 'hex').toString('base64').match(/.{1,64}/g).join('\n') +
    '\n-----END PUBLIC KEY-----';
  
  return {
    privateKeyPem,
    publicKeyPem
  };
}

// 生成测试密钥对
function generateTestKeys() {
  const keyPair = sm2.generateKeyPairHex();
  // 同时生成PEM格式的密钥
  const pemKeys = hexToPem(keyPair.privateKey, keyPair.publicKey);
  return {
    privateKeyHex: keyPair.privateKey,
    publicKeyHex: keyPair.publicKey,
    privateKeyPem: pemKeys.privateKeyPem,
    publicKeyPem: pemKeys.publicKeyPem
  };
}

// 测试SM2签名和验签
async function testSm2SignVerify() {
  console.log('=== SM2签名验签测试 ===');
  
  // 生成测试密钥对
  const keys = generateTestKeys();
  console.log('生成的PEM格式私钥:');
  console.log(keys.privateKeyPem);
  console.log('\n生成的PEM格式公钥:');
  console.log(keys.publicKeyPem);
  
  // 测试数据
  const testData = 'Hello, SM2!';
  console.log('\n测试数据:', testData);
  
  // 使用十六进制私钥签名
  const signature = sm2.doSignature(testData, keys.privateKeyHex);
  console.log('\n使用十六进制私钥生成的签名:', signature);
  
  // 使用十六进制公钥验签
  const isValid1 = sm2.doVerifySignature(testData, signature, keys.publicKeyHex);
  console.log('\n使用十六进制公钥验签结果:', isValid1 ? '成功' : '失败');
  
  // 测试从Redis获取的密钥
  console.log('\n=== 测试Redis中的密钥 ===');
  const appData = await client.get('app:app_001');
  if (appData) {
    const appConfig = JSON.parse(appData);
    console.log('从Redis获取的App配置:');
    console.log('- SM2私钥(PEM):', appConfig.sm2_private_key_pem ? appConfig.sm2_private_key_pem.substring(0, 50) + '...' : '未找到');
    console.log('- SM2公钥(PEM):', appConfig.sm2_public_key_pem ? appConfig.sm2_public_key_pem.substring(0, 50) + '...' : '未找到');
    
    // 注意：sm-crypto库的doSignature和doVerifySignature方法不直接支持PEM格式
    // 所以我们需要从PEM格式转换回十六进制格式进行测试
    if (appConfig.sm2_private_key_pem && appConfig.sm2_public_key_pem) {
      console.log('\n注意：sm-crypto库不直接支持PEM格式的密钥进行签名和验签');
      console.log('在实际使用中，我们需要使用十六进制格式的密钥');
    }
  } else {
    console.log('未找到App配置');
  }
  
  console.log('\n=== 测试完成 ===');
  client.quit();
}

// 运行测试
testSm2SignVerify().catch(console.error);