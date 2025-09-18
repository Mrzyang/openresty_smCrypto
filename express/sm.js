// https://github.com/JuneAndGreen/sm-crypto
const sm2 = require('sm-crypto').sm2;
const sm3 = require('sm-crypto').sm3;
const sm4 = require('sm-crypto').sm4;

// --- SM2 公私钥生成 ---
const sm2KeyPair = sm2.generateKeyPairHex();
console.log('SM2 公钥:', sm2KeyPair.publicKey);
console.log('SM2 私钥:', sm2KeyPair.privateKey);

// --- 添加PEM格式转换函数（更标准的实现）---
function hexToPem(privateKeyHex, publicKeyHex) {
  // 构造SM2私钥的DER格式
  // SEQUENCE (3 elem)
  //   INTEGER 1
  //   OCTET STRING (32 bytes)
  //   [0] (1 elem) OBJECT IDENTIFIER 1.2.156.10197.1.301 sm2
  //   [1] (1 elem) BIT STRING (65 bytes)
  
  // 构造私钥部分
  const version = '020101'; // INTEGER 1
  const privateKeyOctet = '0420' + privateKeyHex; // OCTET STRING with 32 bytes private key
  const algorithmId = 'a00b06092a811ccf5501822d'; // [0] OBJECT IDENTIFIER sm2
  const publicKeyContext = 'a144034200' + publicKeyHex; // [1] BIT STRING with public key
  
  // 构造完整的私钥DER
  const privateKeySequence = version + privateKeyOctet + algorithmId + publicKeyContext;
  const privateKeyLength = (privateKeySequence.length / 2).toString(16).padStart(2, '0');
  const privateKeyDer = '30' + privateKeyLength + privateKeySequence;
  
  // 构造PEM格式的私钥
  const privateKeyPem = '-----BEGIN PRIVATE KEY-----\n' +
    Buffer.from(privateKeyDer, 'hex').toString('base64').match(/.{1,64}/g).join('\n') +
    '\n-----END PRIVATE KEY-----';
  
  // 构造公钥部分
  // SEQUENCE (2 elem)
  //   SEQUENCE (2 elem)
  //     OBJECT IDENTIFIER 1.2.156.10197.1.301 sm2
  //     NULL
  //   BIT STRING (65 bytes)
  
  const publicKeyAlgorithm = '301306072a811ccf5501822d06082a811ccf5501822d'; // SEQUENCE of algorithm
  const publicKeyBitString = '034200' + publicKeyHex; // BIT STRING with public key
  
  // 构造完整的公钥DER
  const publicKeySequence = publicKeyAlgorithm + publicKeyBitString;
  const publicKeyLength = (publicKeySequence.length / 2).toString(16).padStart(4, '0');
  const publicKeyDer = '30' + publicKeyLength + publicKeySequence;
  
  // 构造PEM格式的公钥
  const publicKeyPem = '-----BEGIN PUBLIC KEY-----\n' +
    Buffer.from(publicKeyDer, 'hex').toString('base64').match(/.{1,64}/g).join('\n') +
    '\n-----END PUBLIC KEY-----';
  
  return {
    privateKeyPem,
    publicKeyPem
  };
}

// --- 转换并打印PEM格式的密钥 ---
const pemKeys = hexToPem(sm2KeyPair.privateKey, sm2KeyPair.publicKey);
console.log('\nSM2 私钥 (PEM格式):');
console.log(pemKeys.privateKeyPem);
console.log('\nSM2 公钥 (PEM格式):');
console.log(pemKeys.publicKeyPem);

// --- SM2 签名和验签 ---
const message = 'Hello, SM2!';

// 生成签名
// 修复：使用SM3杂凑算法生成签名
const sign = sm2.doSignature(message, sm2KeyPair.privateKey, {
  hash: true // 启用SM3杂凑
});
console.log('签名:', sign);

// 验签
// 修复：使用SM3杂凑算法验签
const isVerified = sm2.doVerifySignature(message, sign, sm2KeyPair.publicKey, {
  hash: true // 启用SM3杂凑
});
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