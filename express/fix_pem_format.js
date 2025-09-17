// 修复PEM格式以兼容OpenResty
const sm2 = require('sm-crypto').sm2;
const asn1 = require('asn1.js');

// 定义ASN.1结构
const SM2PrivateKey = asn1.define('SM2PrivateKey', function() {
  this.seq().obj(
    this.key('version').int(),
    this.key('privateKey').octstr(),
    this.key('parameters').explicit(0).objid().optional(),
    this.key('publicKey').explicit(1).bitstr().optional()
  );
});

const SM2PublicKey = asn1.define('SM2PublicKey', function() {
  this.seq().obj(
    this.key('algorithm').seq().obj(
      this.key('algorithm').objid(),
      this.key('parameters').null_()
    ),
    this.key('publicKey').bitstr()
  );
});

// 修正PEM格式转换函数
function hexToPemFixed(privateKeyHex, publicKeyHex) {
  console.log('原始十六进制私钥:', privateKeyHex);
  console.log('原始十六进制公钥:', publicKeyHex);
  
  try {
    // 创建私钥DER编码
    const privateKeyDer = SM2PrivateKey.encode({
      version: 1,
      privateKey: Buffer.from(privateKeyHex, 'hex'),
      parameters: [1, 2, 156, 10197, 1, 301], // SM2算法OID
      publicKey: {
        data: Buffer.from('00' + publicKeyHex, 'hex') // 添加前导0x00
      }
    }, 'der');
    
    // 构造PEM格式的私钥
    const privateKeyPem = '-----BEGIN PRIVATE KEY-----\n' +
      privateKeyDer.toString('base64').match(/.{1,64}/g).join('\n') +
      '\n-----END PRIVATE KEY-----';
    
    console.log('修正后的私钥PEM:');
    console.log(privateKeyPem);
    
    // 创建公钥DER编码
    const publicKeyDer = SM2PublicKey.encode({
      algorithm: {
        algorithm: [1, 2, 156, 10197, 1, 301], // SM2算法OID
        parameters: null
      },
      publicKey: {
        data: Buffer.from('00' + publicKeyHex, 'hex') // 添加前导0x00
      }
    }, 'der');
    
    // 构造PEM格式的公钥
    const publicKeyPem = '-----BEGIN PUBLIC KEY-----\n' +
      publicKeyDer.toString('base64').match(/.{1,64}/g).join('\n') +
      '\n-----END PUBLIC KEY-----';
    
    console.log('修正后的公钥PEM:');
    console.log(publicKeyPem);
    
    return {
      privateKeyPem,
      publicKeyPem
    };
  } catch (error) {
    console.error('PEM格式转换错误:', error.message);
    console.error(error.stack);
    
    // 如果ASN.1转换失败，回退到原来的简单方法
    return hexToPemSimple(privateKeyHex, publicKeyHex);
  }
}

// 简单的PEM格式转换（回退方法）
function hexToPemSimple(privateKeyHex, publicKeyHex) {
  console.log('使用简单方法生成PEM格式');
  
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
  const publicKeyAlgorithm = '300d06072a811ccf5501822d0500'; // SEQUENCE with OID and NULL
  const publicKeyBitString = '034200' + publicKeyHex; // BIT STRING with public key
  
  // 构造完整的公钥DER
  const publicKeySequence = publicKeyAlgorithm + publicKeyBitString;
  const publicKeyLength = (publicKeySequence.length / 2).toString(16).padStart(2, '0');
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

// 生成测试密钥对
function generateTestKeys() {
  const keyPair = sm2.generateKeyPairHex();
  console.log('生成的十六进制密钥对:');
  console.log('私钥:', keyPair.privateKey);
  console.log('公钥:', keyPair.publicKey);
  
  // 使用修正的PEM格式转换函数
  const pemKeys = hexToPemFixed(keyPair.privateKey, keyPair.publicKey);
  return {
    privateKeyHex: keyPair.privateKey,
    publicKeyHex: keyPair.publicKey,
    privateKeyPem: pemKeys.privateKeyPem,
    publicKeyPem: pemKeys.publicKeyPem
  };
}

// 主函数
async function main() {
  console.log('=== 修复PEM格式以兼容OpenResty ===');
  
  // 生成测试密钥对
  const keys = generateTestKeys();
  
  console.log('\n=== 修复完成 ===');
}

// 运行主函数
main().catch(console.error);