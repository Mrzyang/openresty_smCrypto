const Redis = require('ioredis');

// Redis连接
const client = new Redis({
  host: '192.168.110.45',  // 使用正确的地址
  port: 6379,
  retryDelayOnFailover: 100,
  enableReadyCheck: false,
  maxRetriesPerRequest: null,
});

client.on('error', (err) => {
  console.error('Redis Client Error:', err);
});

client.on('connect', async () => {
  console.log('Connected to Redis');
  
  try {
    // 获取 app_001 配置
    const appData = await client.get('app:app_001');
    if (appData) {
      const appConfig = JSON.parse(appData);
      console.log('App 配置:');
      console.log('  SM4 Key:', appConfig.sm4_key);
      console.log('  SM4 Key 长度:', appConfig.sm4_key.length);
      console.log('  SM4 IV:', appConfig.sm4_iv);
      console.log('  SM4 IV 长度:', appConfig.sm4_iv.length);
      
      // 测试使用这些密钥进行加密/解密
      const sm4 = require('sm-crypto').sm4;
      const plaintext = 'Test message';
      
      console.log('\n测试加密/解密:');
      console.log('  明文:', plaintext);
      
      // 尝试直接使用存储的密钥和 IV
      try {
        const encrypted = sm4.encrypt(plaintext, appConfig.sm4_key, { mode: 'cbc', iv: appConfig.sm4_iv });
        console.log('  加密成功 (hex):', encrypted);
        
        const decrypted = sm4.decrypt(encrypted, appConfig.sm4_key, { mode: 'cbc', iv: appConfig.sm4_iv });
        console.log('  解密成功:', decrypted);
      } catch (e) {
        console.log('  直接使用存储的密钥/IV失败:', e.message);
      }
      
      // 尝试转换为十六进制格式
      try {
        const keyHex = Buffer.from(appConfig.sm4_key, 'utf-8').toString('hex');
        const ivHex = Buffer.from(appConfig.sm4_iv, 'utf-8').toString('hex');
        
        console.log('  密钥 (hex):', keyHex);
        console.log('  IV (hex):', ivHex);
        
        const encrypted = sm4.encrypt(plaintext, keyHex, { mode: 'cbc', iv: ivHex });
        console.log('  使用十六进制加密成功 (hex):', encrypted);
        
        const decrypted = sm4.decrypt(encrypted, keyHex, { mode: 'cbc', iv: ivHex });
        console.log('  使用十六进制解密成功:', decrypted);
      } catch (e) {
        console.log('  使用十六进制密钥/IV失败:', e.message);
      }
    } else {
      console.log('未找到 app:app_001 配置');
    }
  } catch (error) {
    console.error('检查配置时出错:', error);
  } finally {
    await client.quit();
  }
});