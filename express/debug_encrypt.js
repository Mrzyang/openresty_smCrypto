// 调试加密过程
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

// 测试数据
const body = '{"name":"Test User","email":"test@example.com"}';
const key = '1234567890abcdef'; // 16字节密钥
const iv = 'abcdef1234567890';   // 16字节IV

console.log('原始数据:');
console.log('  body:', body);
console.log('  key:', key);
console.log('  iv:', iv);

// 转换密钥和IV
const hexKey = convertToHex(key);
const hexIv = convertToHex(iv);

console.log('\n转换后:');
console.log('  hexKey:', hexKey);
console.log('  hexIv:', hexIv);

// 加密
const encrypted = sm4.encrypt(body, hexKey, { mode: 'cbc', iv: hexIv });
console.log('\n加密结果:');
console.log('  encrypted (hex):', encrypted);
console.log('  encrypted length:', encrypted.length);

// 转换为base64
const base64Result = Buffer.from(encrypted, 'hex').toString('base64');
console.log('\nBase64格式:');
console.log('  base64Result:', base64Result);

// 解密测试
const decrypted = sm4.decrypt(encrypted, hexKey, { mode: 'cbc', iv: hexIv });
console.log('\n解密结果:');
console.log('  decrypted:', decrypted);
console.log('  match:', decrypted === body);