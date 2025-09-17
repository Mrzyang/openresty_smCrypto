// 调试解密过程
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

// 测试数据（来自错误信息）
const encryptedBase64 = 'fVkw5b5yc8FoIZfpns7ukB/xjSXhc5Q4xIOxHkhTHXt33j5KXA9iVabJzS2c4e/9Une/PZDCzrlXyHtnWogHJA==';
const key = '1234567890abcdef'; // 16字节密钥
const iv = 'abcdef1234567890';   // 16字节IV

console.log('测试数据:');
console.log('  encryptedBase64:', encryptedBase64);
console.log('  key:', key);
console.log('  iv:', iv);

// 转换密钥和IV
const hexKey = convertToHex(key);
const hexIv = convertToHex(iv);

console.log('\n转换后:');
console.log('  hexKey:', hexKey);
console.log('  hexIv:', hexIv);

// 解密
try {
    const encryptedBuffer = Buffer.from(encryptedBase64, 'base64');
    console.log('\nBase64解码后:');
    console.log('  encryptedBuffer length:', encryptedBuffer.length);
    console.log('  encryptedBuffer (hex):', encryptedBuffer.toString('hex'));
    
    // 使用十六进制格式的密钥和IV进行解密
    const result = sm4.decrypt(encryptedBuffer.toString('hex'), hexKey, { mode: 'cbc', iv: hexIv });
    console.log('\n解密结果:');
    console.log('  result:', result);
} catch (error) {
    console.error('\n解密过程中发生错误:', error.message);
    console.error('  error stack:', error.stack);
}