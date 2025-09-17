// https://github.com/JuneAndGreen/sm-crypto
const sm2 = require('sm-crypto').sm2;
const sm3 = require('sm-crypto').sm3;
const sm4 = require('sm-crypto').sm4;

// --- SM2 公私钥生成 ---
const sm2KeyPair = sm2.generateKeyPairHex();
console.log('SM2 公钥:', sm2KeyPair.publicKey);
console.log('SM2 私钥:', sm2KeyPair.privateKey);

// --- SM2 签名和验签 ---
const message = 'Hello, SM2!';

// 生成签名
const sign = sm2.doSignature(message, sm2KeyPair.privateKey);
console.log('签名:', sign);

// 验签
const isVerified = sm2.doVerifySignature(message, sign, sm2KeyPair.publicKey);
console.log('签名验证结果:', isVerified ? '验证成功' : '验证失败');

// --- SM3 哈希摘要 ---
const sm3Digest = sm3(message);
console.log('SM3 哈希摘要:', sm3Digest);

// --- SM4 密钥和 IV 生成 ---
// 改为长度为16的字符串
const sm4Key = '1234567890abcdef'; // 16字节字符串
const sm4Iv = 'abcdef1234567890';  // 16字节字符串

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

// --- SM4 CBC 模式对称加密 ---
const plaintext = 'This is a secret message';

// 对称加密（CBC 模式）
// 使用转换函数将16字节字符串转换为32字符的十六进制字符串
const ciphertext = sm4.encrypt(plaintext, convertToHex(sm4Key), { mode: 'cbc', iv: convertToHex(sm4Iv) }); //默认用pkcs#7填充
console.log('密文:', ciphertext.toString('hex'));

// SM4 解密
const decryptedText = sm4.decrypt(ciphertext, convertToHex(sm4Key), { mode: 'cbc', iv: convertToHex(sm4Iv) });
console.log('解密后的明文:', decryptedText);