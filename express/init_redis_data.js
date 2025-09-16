// Redis数据初始化脚本
const Redis = require('ioredis');
const sm2 = require('sm-crypto').sm2;

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

client.on('connect', () => {
  console.log('Connected to Redis');
});

// 生成测试密钥对
function generateTestKeys() {
  const keyPair = sm2.generateKeyPairHex();
  return {
    privateKey: keyPair.privateKey,
    publicKey: keyPair.publicKey
  };
}

// 初始化App数据
async function initAppData() {
  console.log('初始化App数据...');
  
  const keys = generateTestKeys();
  
  const appConfig = {
    appid: 'app_001',
    name: '测试应用',
    status: 'active',
    sm2_private_key: keys.privateKey,
    sm2_public_key: keys.publicKey,
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
  const appConfig2 = {
    appid: 'app_002',
    name: '测试应用2',
    status: 'active',
    sm2_private_key: keys2.privateKey,
    sm2_public_key: keys2.publicKey,
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
