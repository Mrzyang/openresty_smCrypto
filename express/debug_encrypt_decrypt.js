// 调试Node.js加密与OpenResty解密的兼容性
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
    
    console.log('加密参数:');
    console.log('  密钥:', key);
    console.log('  IV:', iv);
    console.log('  密钥长度:', key.length);
    console.log('  IV长度:', iv.length);
    console.log('  原始请求体:', body);
    
    try {
        // 使用转换函数将16字节字符串转换为32字符的十六进制字符串
        const hexKey = convertToHex(key);
        const hexIv = convertToHex(iv);
        
        console.log('  转换后密钥 (hex):', hexKey);
        console.log('  转换后IV (hex):', hexIv);
        console.log('  转换后密钥长度:', hexKey.length);
        console.log('  转换后IV长度:', hexIv.length);
        
        // 使用十六进制格式的密钥和IV进行加密
        const encrypted = sm4.encrypt(body, hexKey, { mode: 'cbc', iv: hexIv });
        const result = Buffer.from(encrypted, 'hex').toString('base64');
        console.log('  加密结果 (base64):', result);
        return result;
    } catch (error) {
        console.error('加密过程中发生错误:', error.message);
        throw error;
    }
}

// Node.js客户端解密逻辑
function decryptResponseBody(encryptedBody, key, iv) {
    if (!encryptedBody || encryptedBody === '') {
        return '';
    }
    if (typeof encryptedBody !== 'string') {
        try {
            return JSON.stringify(encryptedBody);
        } catch (e) {
            return String(encryptedBody);
        }
    }
    
    console.log('解密参数:');
    console.log('  密钥:', key);
    console.log('  IV:', iv);
    console.log('  密钥长度:', key.length);
    console.log('  IV长度:', iv.length);
    console.log('  加密数据 (base64):', encryptedBody);
    
    try {
        // 使用转换函数将16字节字符串转换为32字符的十六进制字符串
        const hexKey = convertToHex(key);
        const hexIv = convertToHex(iv);
        
        console.log('  转换后密钥 (hex):', hexKey);
        console.log('  转换后IV (hex):', hexIv);
        console.log('  转换后密钥长度:', hexKey.length);
        console.log('  转换后IV长度:', hexIv.length);
        
        const encryptedBuffer = Buffer.from(encryptedBody, 'base64');
        console.log('  解码后的缓冲区长度:', encryptedBuffer.length);
        
        // 使用十六进制格式的密钥和IV进行解密
        const result = sm4.decrypt(encryptedBuffer.toString('hex'), hexKey, { mode: 'cbc', iv: hexIv });
        console.log('  解密结果:', result);
        return result;
    } catch (error) {
        console.error('解密过程中发生错误:', error.message);
        throw error;
    }
}

// 模拟OpenResty解密逻辑
function openresty_decrypt(ciphertext, key, iv) {
    // 这里模拟OpenResty的解密逻辑
    // OpenResty直接使用base64解码后的二进制数据进行解密
    console.log('\n=== 模拟OpenResty解密 ===');
    console.log('  密钥:', key);
    console.log('  IV:', iv);
    console.log('  密钥长度:', key.length);
    console.log('  IV长度:', iv.length);
    console.log('  加密数据 (base64):', ciphertext);
    
    try {
        // 解码base64密文，直接得到二进制数据
        const cipher_bytes = Buffer.from(ciphertext, 'base64');
        console.log('  解码后的缓冲区长度:', cipher_bytes.length);
        console.log('  解码后的缓冲区 (hex):', cipher_bytes.toString('hex'));
        
        // 确保密钥和IV都是16字节长度（这里直接使用原始字符串）
        const fixed_key = key.length === 16 ? key : (key.length > 16 ? key.substring(0, 16) : key.padEnd(16, '\0'));
        const fixed_iv = iv.length === 16 ? iv : (iv.length > 16 ? iv.substring(0, 16) : iv.padEnd(16, '\0'));
        
        console.log('  固定后密钥:', fixed_key);
        console.log('  固定后IV:', fixed_iv);
        
        // 转换为十六进制
        const hexKey = convertToHex(fixed_key);
        const hexIv = convertToHex(fixed_iv);
        
        console.log('  转换后密钥 (hex):', hexKey);
        console.log('  转换后IV (hex):', hexIv);
        
        // 使用十六进制格式的密钥和IV进行解密
        const result = sm4.decrypt(cipher_bytes.toString('hex'), hexKey, { mode: 'cbc', iv: hexIv });
        console.log('  解密结果:', result);
        return result;
    } catch (error) {
        console.error('OpenResty解密过程中发生错误:', error.message);
        throw error;
    }
}

// 测试数据
const testData = '{"name":"Test User","email":"test@example.com"}';
const key = '1234567890abcdef'; // 16字节密钥
const iv = 'abcdef1234567890';   // 16字节IV

console.log('=== 测试数据 ===');
console.log('原始数据:', testData);
console.log('密钥:', key);
console.log('IV:', iv);

// 1. Node.js客户端加密
console.log('\n=== Node.js客户端加密 ===');
const encrypted = encryptRequestBody(testData, key, iv);

// 2. Node.js客户端解密（验证加密结果）
console.log('\n=== Node.js客户端解密 ===');
const decrypted1 = decryptResponseBody(encrypted, key, iv);
console.log('解密结果匹配:', decrypted1 === testData ? '成功' : '失败');

// 3. 模拟OpenResty解密（验证兼容性）
console.log('\n=== 模拟OpenResty解密 ===');
try {
    const decrypted2 = openresty_decrypt(encrypted, key, iv);
    console.log('解密结果匹配:', decrypted2 === testData ? '成功' : '失败');
} catch (error) {
    console.error('OpenResty解密失败:', error.message);
}