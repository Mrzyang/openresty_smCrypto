// 测试发送原始数据
const axios = require('axios');

async function testRawData() {
    const testData = 'fVkw5b5yc8FoIZfpns7ukB/xjSXhc5Q4xIOxHkhTHXupodGiwyrF3Yv0/J9grcFq';
    
    console.log('发送的数据:', testData);
    console.log('数据类型:', typeof testData);
    console.log('数据长度:', testData.length);
    
    try {
        const response = await axios({
            method: 'POST',
            url: 'http://localhost:8082/test',
            headers: {
                'Content-Type': 'application/octet-stream'
            },
            data: testData,
            transformRequest: [(data, headers) => {
                return data;
            }]
        });
        
        console.log('请求发送成功');
    } catch (error) {
        console.error('请求失败:', error.message);
    }
}

testRawData();