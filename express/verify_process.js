// 验证Node.js客户端的加密解密过程
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
const body = 'test message';
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

// 加密过程
console.log('\n=== 加密过程 ===');
const encryptedHex = sm4.encrypt(body, hexKey, { mode: 'cbc', iv: hexIv });
console.log('  encryptedHex:', encryptedHex);
console.log('  encryptedHex length:', encryptedHex.length);
console.log('  encryptedHex type:', typeof encryptedHex);

const encryptedBuffer = Buffer.from(encryptedHex, 'hex');
console.log('  encryptedBuffer length:', encryptedBuffer.length);
console.log('  encryptedBuffer (hex):', encryptedBuffer.toString('hex'));

const encryptedBase64 = encryptedBuffer.toString('base64');
console.log('  encryptedBase64:', encryptedBase64);

// 解密过程
console.log('\n=== 解密过程 ===');
const receivedBase64 = encryptedBase64;
console.log('  receivedBase64:', receivedBase64);

const receivedBuffer = Buffer.from(receivedBase64, 'base64');
console.log('  receivedBuffer length:', receivedBuffer.length);
console.log('  receivedBuffer (hex):', receivedBuffer.toString('hex'));

const receivedHex = receivedBuffer.toString('hex');
console.log('  receivedHex:', receivedHex);

const decrypted = sm4.decrypt(receivedHex, hexKey, { mode: 'cbc', iv: hexIv });
console.log('  decrypted:', decrypted);
console.log('  match:', decrypted === body);