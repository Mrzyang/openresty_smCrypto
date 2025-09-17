// Redis数据初始化脚本
const Redis = require('ioredis');
const sm2 = require('sm-crypto').sm2;

// Redis连接
const client = new Redis({
  host: '192.168.110.45',  // 改回正确的地址
  port: 6379,
  retryDelayOnFailover: 100,
  enableReadyCheck: false,
  maxRetriesPerRequest: null,
});

client.on('error', (err) => {
  console.error('Redis Client Error:', err);
});

client.on('connect', () => {
  console.log('Connected to Redis');
});

// --- 添加PEM格式转换函数 ---
function hexToPem(privateKeyHex, publicKeyHex) {
  console.log('生成PEM格式密钥 - 输入十六进制私钥:', privateKeyHex);
  console.log('生成PEM格式密钥 - 输入十六进制公钥:', publicKeyHex);
  
  // 生成PKCS#8格式的私钥，这是OpenResty更兼容的格式
  // PrivateKeyInfo ::= SEQUENCE {
  //   version                   Version,
  //   privateKeyAlgorithm       PrivateKeyAlgorithmIdentifier,
  //   privateKey                PrivateKey,
  //   attributes            [0] Attributes OPTIONAL }
  
  // Version (INTEGER 0 for PKCS#8)
  const version = '020100';
  
  // PrivateKeyAlgorithmIdentifier (SM2 algorithm identifier)
  const algorithmIdentifier = '300d06072a811ccf5501822d0500';
  
  // PrivateKey (OCTET STRING containing the actual private key)
  const actualPrivateKey = '0420' + privateKeyHex;
  
  // 构造完整的私钥SEQUENCE
  const privateKeySequence = algorithmIdentifier + actualPrivateKey;
  const privateKeyLength = (privateKeySequence.length / 2).toString(16).padStart(2, '0');
  const privateKeyWrapper = '04' + privateKeyLength + privateKeySequence;
  
  // 构造完整的PrivateKeyInfo
  const privateKeyInfo = version + algorithmIdentifier + privateKeyWrapper;
  const privateKeyInfoLength = (privateKeyInfo.length / 2).toString(16).padStart(2, '0');
  const privateKeyInfoDer = '30' + privateKeyInfoLength + privateKeyInfo;
  
  // 构造PEM格式的私钥
  const privateKeyPem = '-----BEGIN PRIVATE KEY-----\n' +
    Buffer.from(privateKeyInfoDer, 'hex').toString('base64').match(/.{1,64}/g).join('\n') +
    '\n-----END PRIVATE KEY-----';
  
  console.log('生成的私钥PEM:');
  console.log(privateKeyPem);
  
  // 生成公钥格式 (SubjectPublicKeyInfo)
  // SubjectPublicKeyInfo ::= SEQUENCE {
  //   algorithm            AlgorithmIdentifier,
  //   subjectPublicKey     BIT STRING }
  
  // AlgorithmIdentifier (SM2 algorithm identifier with NULL parameter)
  const pubAlgorithmIdentifier = '300d06072a811ccf5501822d0500';
  
  // subjectPublicKey (BIT STRING containing the public key)
  // BIT STRING需要一个前导字节表示忽略的位数（通常为0）
  const publicKeyData = '00' + publicKeyHex; // 添加前导0x00
  const publicKeyLength = (publicKeyData.length / 2).toString(16).padStart(2, '0');
  const publicKeyBitString = '03' + publicKeyLength + publicKeyData;
  
  // 构造完整的SubjectPublicKeyInfo
  const subjectPublicKeyInfo = pubAlgorithmIdentifier + publicKeyBitString;
  const subjectPublicKeyInfoLength = (subjectPublicKeyInfo.length / 2).toString(16).padStart(2, '0');
  const subjectPublicKeyInfoDer = '30' + subjectPublicKeyInfoLength + subjectPublicKeyInfo;
  
  // 构造PEM格式的公钥
  const publicKeyPem = '-----BEGIN PUBLIC KEY-----\n' +
    Buffer.from(subjectPublicKeyInfoDer, 'hex').toString('base64').match(/.{1,64}/g).join('\n') +
    '\n-----END PUBLIC KEY-----';
  
  console.log('生成的公钥PEM:');
  console.log(publicKeyPem);
  
  return {
    privateKeyPem,
    publicKeyPem
  };
}

// 生成测试用的SM2密钥对
function generateTestKeys() {
  const keyPair = sm2.generateKeyPairHex();
  console.log('生成的十六进制密钥对:');
  console.log('私钥:', keyPair.privateKey);
  console.log('公钥:', keyPair.publicKey);
  
  // 同时生成PEM格式的密钥
  const pemKeys = hexToPem(keyPair.privateKey, keyPair.publicKey);
  return {
    privateKeyPem: pemKeys.privateKeyPem,
    publicKeyPem: pemKeys.publicKeyPem
  };
}

// 初始化App数据
async function initAppData() {
  console.log('初始化App数据...');
  
  const keys = generateTestKeys();
  const gatewaySigningKeys = generateTestKeys(); // 用于网关签名的密钥对
  
  const appConfig = {
    appid: 'app_001',
    name: '测试应用',
    status: 'active',
    // 仅存储PEM格式的密钥
    sm2_private_key_pem: keys.privateKeyPem,
    sm2_public_key_pem: keys.publicKeyPem,
    // 网关签名用的密钥对(仅PEM格式)
    gateway_sm2_private_key_pem: gatewaySigningKeys.privateKeyPem,
    gateway_sm2_public_key_pem: gatewaySigningKeys.publicKeyPem,
    sm4_key: '1234567890abcdef',
    sm4_iv: 'abcdef1234567890',
    ip_whitelist: ['127.0.0.1', '192.168.1.100', '192.168.1.101'],
    nonce_window: 300,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString()
  };
  
  await client.set('app:app_001', JSON.stringify(appConfig));
  console.log('App配置已创建:', appConfig.appid);
  
  // 创建第二个测试App
  const keys2 = generateTestKeys();
  const gatewaySigningKeys2 = generateTestKeys(); // 用于网关签名的密钥对
  const appConfig2 = {
    appid: 'app_002',
    name: '测试应用2',
    status: 'active',
    // 仅存储PEM格式的密钥
    sm2_private_key_pem: keys2.privateKeyPem,
    sm2_public_key_pem: keys2.publicKeyPem,
    // 网关签名用的密钥对(仅PEM格式)
    gateway_sm2_private_key_pem: gatewaySigningKeys2.privateKeyPem,
    gateway_sm2_public_key_pem: gatewaySigningKeys2.publicKeyPem,
    sm4_key: 'fedcba0987654321',
    sm4_iv: '0987654321fedcba',
    ip_whitelist: ['127.0.0.1'],
    nonce_window: 300,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString()
  };
  
  await client.set('app:app_002', JSON.stringify(appConfig2));
  console.log('App配置已创建:', appConfig2.appid);
}

// 初始化API数据
async function initApiData() {
  console.log('初始化API数据...');
  
  const apis = [
    {
      api_id: 'api_001',
      name: '用户信息查询',
      path: '/api/user/info',
      method: 'GET',
      backend_url: 'http://127.0.0.1:3000/api/user/info',
      status: 'active',
      rate_limit: 1000,
      timeout: 30,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    },
    {
      api_id: 'api_002',
      name: '用户列表查询',
      path: '/api/user/list',
      method: 'GET',
      backend_url: 'http://127.0.0.1:3000/api/user/list',
      status: 'active',
      rate_limit: 1000,
      timeout: 30,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    },
    {
      api_id: 'api_003',
      name: '创建用户',
      path: '/api/user/create',
      method: 'POST',
      backend_url: 'http://127.0.0.1:3000/api/user/create',
      status: 'active',
      rate_limit: 100,
      timeout: 30,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    },
    {
      api_id: 'api_004',
      name: '系统状态查询',
      path: '/api/system/status',
      method: 'GET',
      backend_url: 'http://127.0.0.1:3000/api/system/status',
      status: 'active',
      rate_limit: 2000,
      timeout: 30,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    },
    {
      api_id: 'api_005',
      name: '健康检查',
      path: '/health',
      method: 'GET',
      backend_url: 'http://127.0.0.1:3000/health',
      status: 'active',
      rate_limit: 5000,
      timeout: 10,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    }
  ];
  
  for (const api of apis) {
    await client.set(`api:${api.api_id}`, JSON.stringify(api));
    console.log(`API配置已创建: ${api.api_id} - ${api.name}`);
  }
}

// 初始化App订阅数据
async function initSubscriptionData() {
  console.log('初始化订阅数据...');
  
  const subscriptions = [
    {
      appid: 'app_001',
      subscribed_apis: ['api_001', 'api_002', 'api_003', 'api_004', 'api_005'],
      subscription_status: {
        'api_001': 'active',
        'api_002': 'active',
        'api_003': 'active',
        'api_004': 'active',
        'api_005': 'active'
      },
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    },
    {
      appid: 'app_002',
      subscribed_apis: ['api_001', 'api_002', 'api_005'],
      subscription_status: {
        'api_001': 'active',
        'api_002': 'active',
        'api_005': 'active'
      },
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    }
  ];
  
  for (const subscription of subscriptions) {
    await client.set(`app_subscription:${subscription.appid}`, JSON.stringify(subscription));
    console.log(`订阅配置已创建: ${subscription.appid}`);
  }
}

// 清理现有数据
async function clearExistingData() {
  console.log('清理现有数据...');
  
  const keys = await client.keys('app:*');
  const apiKeys = await client.keys('api:*');
  const subKeys = await client.keys('app_subscription:*');
  const nonceKeys = await client.keys('nonce:*');
  const logKeys = await client.keys('request_log:*');
  
  const allKeys = [...keys, ...apiKeys, ...subKeys, ...nonceKeys, ...logKeys];
  
  if (allKeys.length > 0) {
    await client.del(allKeys);
    console.log(`已清理 ${allKeys.length} 个键`);
  } else {
    console.log('没有找到需要清理的数据');
  }
}

// 显示当前数据
async function showCurrentData() {
  console.log('\n=== 当前Redis数据 ===');
  
  const appKeys = await client.keys('app:*');
  const apiKeys = await client.keys('api:*');
  const subKeys = await client.keys('app_subscription:*');
  
  console.log(`App配置 (${appKeys.length}):`, appKeys);
  console.log(`API配置 (${apiKeys.length}):`, apiKeys);
  console.log(`订阅配置 (${subKeys.length}):`, subKeys);
  
  for (const key of appKeys) {
    const data = await client.get(key);
    const app = JSON.parse(data);
    console.log(`${key}: ${app.name} (${app.status})`);
    // 输出密钥信息用于验证
    if (app.sm2_private_key_pem) {
      console.log(`  SM2私钥(PEM): ${app.sm2_private_key_pem.substring(0, 50)}...`);
    }
    if (app.sm2_public_key_pem) {
      console.log(`  SM2公钥(PEM): ${app.sm2_public_key_pem.substring(0, 50)}...`);
    }
  }
  
  for (const key of apiKeys) {
    const data = await client.get(key);
    const api = JSON.parse(data);
    console.log(`${key}: ${api.name} (${api.method} ${api.path})`);
  }
  
  for (const key of subKeys) {
    const data = await client.get(key);
    const sub = JSON.parse(data);
    console.log(`${key}: ${sub.subscribed_apis.length} 个API订阅`);
  }
  
  console.log('==================\n');
}

// 主函数
async function main() {
  try {
    const command = process.argv[2];
    
    if (command === 'clear') {
      await clearExistingData();
    } else if (command === 'show') {
      await showCurrentData();
    } else {
      // 默认初始化数据
      await clearExistingData();
      await initAppData();
      await initApiData();
      await initSubscriptionData();
      await showCurrentData();
      console.log('数据初始化完成！');
    }
    
  } catch (error) {
    console.error('初始化失败:', error);
  } finally {
    await client.quit();
  }
}

// 运行主函数
if (require.main === module) {
  main();
}

module.exports = {
  initAppData,
  initApiData,
  initSubscriptionData,
  clearExistingData,
  showCurrentData
};