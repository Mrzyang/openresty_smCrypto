// Redis数据初始化脚本
const Redis = require('ioredis');
const sm2 = require('sm-crypto').sm2;

// Redis连接
const client = new Redis({
  host: '192.168.56.2',  // 使用您指定的Redis地址
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

// 生成测试用的SM2密钥对
function generateTestKeys() {
  // 生成十六进制格式的密钥对
  const keyPair = sm2.generateKeyPairHex();
  console.log('生成的十六进制密钥对:');
  console.log('私钥:', keyPair.privateKey);
  console.log('公钥:', keyPair.publicKey);
  
  return {
    privateKey: keyPair.privateKey,
    publicKey: keyPair.publicKey
  };
}

// 生成32个字符的随机十六进制字符串
function generateRandomHex32() {
  let result = '';
  const characters = '0123456789abcdef';
  const charactersLength = characters.length;
  for (let i = 0; i < 32; i++) {
    result += characters.charAt(Math.floor(Math.random() * charactersLength));
  }
  return result;
}

// 初始化App数据
async function initAppData() {
  console.log('初始化App数据...');
  
  const keys = generateTestKeys();
  const gatewaySigningKeys = generateTestKeys(); // 用于网关签名的密钥对
  
  // 生成32个字符的随机十六进制字符串作为SM4密钥和IV
  const sm4Key = generateRandomHex32();
  const sm4Iv = generateRandomHex32();
  
  const appConfig = {
    appid: 'app_001',
    name: '测试应用',
    status: 'active',
    // 存储十六进制格式的密钥
    sm2_private_key: keys.privateKey,
    sm2_public_key: keys.publicKey,
    // 网关签名用的密钥对(十六进制格式)
    gateway_sm2_private_key: gatewaySigningKeys.privateKey,
    gateway_sm2_public_key: gatewaySigningKeys.publicKey,
    // 生成32个字符的随机十六进制字符串作为SM4密钥和IV
    sm4_key: sm4Key,
    sm4_iv: sm4Iv,
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
  
  // 生成32个字符的随机十六进制字符串作为SM4密钥和IV
  const sm4Key2 = generateRandomHex32();
  const sm4Iv2 = generateRandomHex32();
  
  const appConfig2 = {
    appid: 'app_002',
    name: '测试应用2',
    status: 'active',
    // 存储十六进制格式的密钥
    sm2_private_key: keys2.privateKey,
    sm2_public_key: keys2.publicKey,
    // 网关签名用的密钥对(十六进制格式)
    gateway_sm2_private_key: gatewaySigningKeys2.privateKey,
    gateway_sm2_public_key: gatewaySigningKeys2.publicKey,
    // 生成32个字符的随机十六进制字符串作为SM4密钥和IV
    sm4_key: sm4Key2,
    sm4_iv: sm4Iv2,
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
      backend_uri: '/api/user/info',
      backend_ip_list: ['127.0.0.1:3000', '192.168.56.101:3000'],
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
      backend_uri: '/api/user/list',
      backend_ip_list: ['127.0.0.1:3000', '192.168.56.101:3000'],
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
      backend_uri: '/api/user/create',
      backend_ip_list: ['127.0.0.1:3000', '192.168.56.101:3000'],
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
      backend_uri: '/api/system/status',
      backend_ip_list: ['127.0.0.1:3000', '192.168.56.101:3000'],
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
      backend_uri: '/health',
      backend_ip_list: ['127.0.0.1:3000', '192.168.56.101:3000'],
      status: 'active',
      rate_limit: 5000,
      timeout: 10,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    },
    {
      api_id: 'api_006',
      name: '更新用户',
      path: '/api/user/update',
      method: 'PUT',
      backend_uri: '/api/user/update',
      backend_ip_list: ['127.0.0.1:3000', '192.168.56.101:3000'],
      status: 'active',
      rate_limit: 100,
      timeout: 30,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    },
    {
      api_id: 'api_007',
      name: '删除用户',
      path: '/api/user/delete',
      method: 'DELETE',
      backend_uri: '/api/user/delete',
      backend_ip_list: ['127.0.0.1:3000', '192.168.56.101:3000'],
      status: 'active',
      rate_limit: 100,
      timeout: 30,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    }
  ];
  
  // 使用新的键格式存储API数据: api:path:$uri
  for (const api of apis) {
    const key = `api:path:${api.path}`;
    await client.set(key, JSON.stringify(api));
    console.log(`API配置已创建: ${key} - ${api.name}`);
  }
}

// 初始化App订阅数据
async function initSubscriptionData() {
  console.log('初始化订阅数据...');
  
  const subscriptions = [
    {
      appid: 'app_001',
      subscribed_apis: ['/api/user/info', '/api/user/list', '/api/user/create', '/api/user/update', '/api/user/delete', '/api/system/status', '/health'],
      subscription_status: {
        '/api/user/info': 'active',
        '/api/user/list': 'active',
        '/api/user/create': 'active',
        '/api/user/update': 'active',
        '/api/user/delete': 'active',
        '/api/system/status': 'active',
        '/health': 'active'
      },
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    },
    {
      appid: 'app_002',
      subscribed_apis: ['/api/user/info', '/api/user/list', '/health'],
      subscription_status: {
        '/api/user/info': 'active',
        '/api/user/list': 'active',
        '/health': 'active'
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
  const apiPathKeys = await client.keys('api:path:*');  // 新的API键格式
  const subKeys = await client.keys('app_subscription:*');
  const nonceKeys = await client.keys('nonce:*');
  const logKeys = await client.keys('request_log:*');
  
  const allKeys = [...keys, ...apiKeys, ...apiPathKeys, ...subKeys, ...nonceKeys, ...logKeys];
  
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
  const apiPathKeys = await client.keys('api:path:*');  // 新的API键格式
  const subKeys = await client.keys('app_subscription:*');
  
  console.log(`App配置 (${appKeys.length}):`, appKeys);
  console.log(`API配置 (${apiPathKeys.length}):`, apiPathKeys);
  console.log(`订阅配置 (${subKeys.length}):`, subKeys);
  
  for (const key of appKeys) {
    const data = await client.get(key);
    const app = JSON.parse(data);
    console.log(`${key}: ${app.name} (${app.status})`);
    // 输出密钥信息用于验证
    if (app.sm2_private_key) {
      console.log(`  SM2私钥(HEX): ${app.sm2_private_key.substring(0, 50)}...`);
    }
    if (app.sm2_public_key) {
      console.log(`  SM2公钥(HEX): ${app.sm2_public_key.substring(0, 50)}...`);
    }
    // 输出SM4密钥和IV信息
    if (app.sm4_key) {
      console.log(`  SM4密钥(HEX): ${app.sm4_key}`);
    }
    if (app.sm4_iv) {
      console.log(`  SM4 IV(HEX): ${app.sm4_iv}`);
    }
  }
  
  for (const key of apiPathKeys) {
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