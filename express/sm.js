// https://github.com/JuneAndGreen/sm-crypto
const sm2 = require("sm-crypto").sm2;
const sm3 = require("sm-crypto").sm3;
const sm4 = require("sm-crypto").sm4;

// --- SM2 公私钥生成 ---
const sm2KeyPair = sm2.generateKeyPairHex();
console.log("SM2 公钥:", sm2KeyPair.publicKey);
console.log("SM2 私钥:", sm2KeyPair.privateKey);

// --- SM2 签名和验签 ---
const message = "{name: \"Seahigh DX\", nick: \"Seahigh DX\"}";

// --- SM3 哈希摘要 ---
const sm3Digest = sm3(message);
console.log("SM3 哈希摘要:", sm3Digest);

// 生成签名
const sign = sm2.doSignature(message, sm2KeyPair.privateKey, {
  der: true,
  hash: true,
  //publicKey: sm2KeyPair.publicKey,
  //userId: "1234567812345678",
});
console.log("签名:", sign);

// 验签
const isVerified = sm2.doVerifySignature(message, sign, sm2KeyPair.publicKey, {
  der: true,
  hash: true,
  //userId: "1234567812345678",
});
console.log("签名验证结果:", isVerified ? "验证成功" : "验证失败");

// --- SM4 密钥和 IV 生成 ---
const sm4Key = "9123456789abcdeffedcba9876543210"; // 可以为 16 进制串或字节数组，要求为 128 比特
const sm4Iv = "aedcba98765432100123456789abcdef"; // 可以为 16 进制串或字节数组，要求为 128 比特

// --- SM4 CBC 模式对称加密 ---
const plaintext = "This is a secret message";

// 对称加密（CBC 模式）
const ciphertext = sm4.encrypt(plaintext, sm4Key, sm4Iv); //默认用pkcs#7填充
console.log("密文:", ciphertext.toString("hex"));

// SM4 解密
const decryptedText = sm4.decrypt(ciphertext, sm4Key, sm4Iv);
console.log("解密后的明文:", decryptedText);
