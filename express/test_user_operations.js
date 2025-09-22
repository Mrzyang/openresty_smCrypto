const { sendApiRequest, getAppConfigFromRedis } = require('./test_client.js');

async function testUserOperations() {
  try {
    console.log('开始测试用户管理操作...\n');
    
    // 从Redis获取App配置
    const appConfig = await getAppConfigFromRedis("app_001");
    
    // 测试1: 创建用户
    console.log('1. 测试创建用户');
    const createResponse = await sendApiRequest(
      'POST', 
      '/api/user/create', 
      JSON.stringify({
        name: 'Test User',
        email: 'test@example.com'
      })
    );
    console.log('创建用户响应:', JSON.stringify(createResponse.data, null, 2));
    
    // 从创建响应中获取用户ID用于后续测试
    const userId = createResponse.data.data.id;
    
    // 测试2: 更新用户
    console.log('\n2. 测试更新用户');
    const updateResponse = await sendApiRequest(
      'PUT', 
      '/api/user/update', 
      JSON.stringify({
        id: userId,
        name: 'Updated User',
        email: 'updated@example.com'
      })
    );
    console.log('更新用户响应:', JSON.stringify(updateResponse.data, null, 2));
    
    // 测试3: 删除用户
    console.log('\n3. 测试删除用户');
    const deleteResponse = await sendApiRequest(
      'DELETE', 
      '/api/user/delete', 
      JSON.stringify({
        id: userId
      })
    );
    console.log('删除用户响应:', JSON.stringify(deleteResponse.data, null, 2));
    
    console.log('\n所有用户管理操作测试完成！');
  } catch (error) {
    console.error('测试过程中发生错误:', error.message);
  }
}

// 运行测试
testUserOperations();