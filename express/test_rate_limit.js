const { exec } = require('child_process');
const util = require('util');
const execPromise = util.promisify(exec);

async function runTest() {
  const promises = [];
  // 先测试较小的并发数，比如100个请求
  for (let i = 0; i < 1001; i++) {
    promises.push(execPromise('node test_client.js test'));
  }
  
  try {
    const results = await Promise.allSettled(promises);
    let successCount = 0;
    let rateLimitCount = 0;
    
    results.forEach(result => {
      if (result.status === 'fulfilled') {
        successCount++;
      } else {
        if (result.reason.message.includes('429')) {
          rateLimitCount++;
        }
      }
    });
    
    console.log(`成功请求: ${successCount}`);
    console.log(`被限流请求: ${rateLimitCount}`);
  } catch (error) {
    console.error('测试出错:', error);
  }
}

runTest();