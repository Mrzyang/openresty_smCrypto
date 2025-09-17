// 检查请求格式
const sm4 = require('sm-crypto').sm4;

// 转换函数：将16字节字符串转换为32字符的十六进制字符串
function convertToHex(keyOrIv) {
    if (keyOrIv.length === 16) {
        return Buffer.from(keyOrIv, 'utf-8').toString('hex');
    } else if (keyOrIv.length === 32) {
        return keyOrIv; // 已经是十六进制格式
    } else {
        // 其他情况，先调整长度再转换
        const fixed = keyOrIv.length > 16 ? keyOrIv.substring(0, 16) : keyOrIv.padEnd(16, '\0');
        return Buffer.from(fixed, 'utf-8').toString('hex');
    }
}

// Node.js客户端加密逻辑
function encryptRequestBody(body, key, iv) {
    if (!body || body === '') {
        return '';
    }
    
    try {
        // 使用转换函数将16字节字符串转换为32字符的十六进制字符串
        const hexKey = convertToHex(key);
        const hexIv = convertToHex(iv);
        
        // 使用十六进制格式的密钥和IV进行加密
        const encrypted = sm4.encrypt(body, hexKey, { mode: 'cbc', iv: hexIv });
        const result = Buffer.from(encrypted, 'hex').toString('base64');
        return result;
    } catch (error) {
        console.error('加密过程中发生错误:', error.message);
        throw error;
    }
}

// 测试数据
const testData = '{"name":"Test User","email":"test@example.com"}';
const key = '1234567890abcdef'; // 16字节密钥
const iv = 'abcdef1234567890';   // 16字节IV

console.log('原始数据:', testData);

// 加密
const encrypted = encryptRequestBody(testData, key, iv);
console.log('加密结果:', encrypted);
console.log('加密结果长度:', encrypted.length);

// 检查base64字符集
const base64Regex = /^[A-Za-z0-9+/=]+$/;
console.log('是否符合base64格式:', base64Regex.test(encrypted));

// 检查填充
if (encrypted.length % 4 !== 0) {
    console.log('警告: Base64字符串长度不是4的倍数');
}

// 检查结尾字符
if (encrypted.endsWith('=')) {
    console.log('Base64字符串包含填充字符');
}

// 尝试解码
try {
    const decoded = Buffer.from(encrypted, 'base64');
    console.log('解码成功，长度:', decoded.length);
    console.log('解码后数据 (hex):', decoded.toString('hex'));
} catch (e) {
    console.error('解码失败:', e.message);
}

// 检查特殊字符
console.log('\n字符分析:');
for (let i = 0; i < encrypted.length; i++) {
    const char = encrypted[i];
    const code = char.charCodeAt(0);
    if (code < 32 || code > 126) {
        console.log(`  位置${i}: 非ASCII字符 '${char}' (编码: ${code})`);
    }
}