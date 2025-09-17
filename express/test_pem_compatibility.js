// 测试PEM格式与OpenResty的兼容性
const sm2 = require('sm-crypto').sm2;

// 新的PEM格式转换函数
function hexToPem(privateKeyHex, publicKeyHex) {
  console.log('生成PEM格式密钥 - 输入十六进制私钥:', privateKeyHex);
  console.log('生成PEM格式密钥 - 输入十六进制公钥:', publicKeyHex);
  
  // 生成PKCS#8格式的私钥，这是OpenResty更兼容的格式
  // PrivateKeyInfo ::= SEQUENCE {
  //   version                   Version,
  //   privateKeyAlgorithm       PrivateKeyAlgorithmIdentifier,
  //   privateKey                PrivateKey,
  //   attributes            [0] Attributes OPTIONAL }
  
  // Version (INTEGER 0 for PKCS#8)
  const version = '020100';
  
  // PrivateKeyAlgorithmIdentifier (SM2 algorithm identifier)
  const algorithmIdentifier = '300d06072a811ccf5501822d0500';
  
  // PrivateKey (OCTET STRING containing the actual private key)
  const actualPrivateKey = '0420' + privateKeyHex;
  
  // 构造完整的私钥SEQUENCE
  const privateKeySequence = algorithmIdentifier + actualPrivateKey;
  const privateKeyLength = (privateKeySequence.length / 2).toString(16).padStart(2, '0');
  const privateKeyWrapper = '04' + privateKeyLength + privateKeySequence;
  
  // 构造完整的PrivateKeyInfo
  const privateKeyInfo = version + algorithmIdentifier + privateKeyWrapper;
  const privateKeyInfoLength = (privateKeyInfo.length / 2).toString(16).padStart(2, '0');
  const privateKeyInfoDer = '30' + privateKeyInfoLength + privateKeyInfo;
  
  // 构造PEM格式的私钥
  const privateKeyPem = '-----BEGIN PRIVATE KEY-----\n' +
    Buffer.from(privateKeyInfoDer, 'hex').toString('base64').match(/.{1,64}/g).join('\n') +
    '\n-----END PRIVATE KEY-----';
  
  console.log('生成的私钥PEM:');
  console.log(privateKeyPem);
  
  // 生成公钥格式 (SubjectPublicKeyInfo)
  // SubjectPublicKeyInfo ::= SEQUENCE {
  //   algorithm            AlgorithmIdentifier,
  //   subjectPublicKey     BIT STRING }
  
  // AlgorithmIdentifier (SM2 algorithm identifier with NULL parameter)
  const pubAlgorithmIdentifier = '300d06072a811ccf5501822d0500';
  
  // subjectPublicKey (BIT STRING containing the public key)
  // BIT STRING需要一个前导字节表示忽略的位数（通常为0）
  const publicKeyData = '00' + publicKeyHex; // 添加前导0x00
  const publicKeyLength = (publicKeyData.length / 2).toString(16).padStart(2, '0');
  const publicKeyBitString = '03' + publicKeyLength + publicKeyData;
  
  // 构造完整的SubjectPublicKeyInfo
  const subjectPublicKeyInfo = pubAlgorithmIdentifier + publicKeyBitString;
  const subjectPublicKeyInfoLength = (subjectPublicKeyInfo.length / 2).toString(16).padStart(2, '0');
  const subjectPublicKeyInfoDer = '30' + subjectPublicKeyInfoLength + subjectPublicKeyInfo;
  
  // 构造PEM格式的公钥
  const publicKeyPem = '-----BEGIN PUBLIC KEY-----\n' +
    Buffer.from(subjectPublicKeyInfoDer, 'hex').toString('base64').match(/.{1,64}/g).join('\n') +
    '\n-----END PUBLIC KEY-----';
  
  console.log('生成的公钥PEM:');
  console.log(publicKeyPem);
  
  return {
    privateKeyPem,
    publicKeyPem
  };
}

// 生成测试密钥对
function generateTestKeys() {
  const keyPair = sm2.generateKeyPairHex();
  console.log('生成的十六进制密钥对:');
  console.log('私钥:', keyPair.privateKey);
  console.log('公钥:', keyPair.publicKey);
  
  // 使用新的PEM格式转换函数
  const pemKeys = hexToPem(keyPair.privateKey, keyPair.publicKey);
  return {
    privateKeyHex: keyPair.privateKey,
    publicKeyHex: keyPair.publicKey,
    privateKeyPem: pemKeys.privateKeyPem,
    publicKeyPem: pemKeys.publicKeyPem
  };
}

// 测试签名和验签
function testSignVerify(keys) {
  const testData = 'Hello, SM2!';
  console.log('\n测试数据:', testData);
  
  // 使用十六进制私钥签名
  const signature = sm2.doSignature(testData, keys.privateKeyHex);
  console.log('\n使用十六进制私钥生成的签名:', signature);
  
  // 使用十六进制公钥验签
  const isValid1 = sm2.doVerifySignature(testData, signature, keys.publicKeyHex);
  console.log('\n使用十六进制公钥验签结果:', isValid1 ? '成功' : '失败');
}

// 主函数
async function main() {
  console.log('=== 测试PEM格式与OpenResty的兼容性 ===');
  
  // 生成测试密钥对
  const keys = generateTestKeys();
  
  // 测试签名和验签
  testSignVerify(keys);
  
  console.log('\n=== 生成完成，请将以下密钥复制到OpenResty测试脚本中 ===');
  console.log('私钥PEM:');
  console.log(keys.privateKeyPem);
  console.log('\n公钥PEM:');
  console.log(keys.publicKeyPem);
  
  console.log('\n=== 测试完成 ===');
}

// 运行主函数
main().catch(console.error);