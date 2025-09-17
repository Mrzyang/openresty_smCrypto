// 分析PEM格式的ASN.1结构（简化版）
const sm2 = require('sm-crypto').sm2;

// 分析PEM格式
function analyzePem(pemData, type) {
  try {
    // 移除PEM头尾
    const base64Data = pemData
      .replace(/-----BEGIN [A-Z ]+-----/, '')
      .replace(/-----END [A-Z ]+-----/, '')
      .replace(/\s/g, '');
    
    // 解码base64
    const derBuffer = Buffer.from(base64Data, 'base64');
    console.log(`${type} DER数据长度:`, derBuffer.length);
    console.log(`${type} DER数据(HEX):`, derBuffer.toString('hex'));
    
    // 简单分析ASN.1结构
    analyzeAsn1Structure(derBuffer, type);
    
    return derBuffer;
  } catch (error) {
    console.error(`分析${type} PEM格式时出错:`, error.message);
    return null;
  }
}

// 简单分析ASN.1结构
function analyzeAsn1Structure(buffer, type) {
  console.log(`\n${type} ASN.1结构分析:`);
  
  let offset = 0;
  while (offset < buffer.length) {
    if (offset >= buffer.length) break;
    
    const tag = buffer[offset];
    offset++;
    
    if (offset >= buffer.length) break;
    
    let length = buffer[offset];
    offset++;
    
    // 处理长格式长度
    if (length & 0x80) {
      const lengthBytes = length & 0x7F;
      length = 0;
      for (let i = 0; i < lengthBytes; i++) {
        if (offset >= buffer.length) break;
        length = (length << 8) | buffer[offset];
        offset++;
      }
    }
    
    console.log(`  Tag: 0x${tag.toString(16)}, Length: ${length}`);
    
    if (offset + length > buffer.length) break;
    
    // 根据tag类型输出信息
    switch (tag) {
      case 0x30: // SEQUENCE
        console.log(`    SEQUENCE (${length} bytes)`);
        break;
      case 0x02: // INTEGER
        console.log(`    INTEGER (${length} bytes)`);
        break;
      case 0x04: // OCTET STRING
        console.log(`    OCTET STRING (${length} bytes)`);
        break;
      case 0x03: // BIT STRING
        console.log(`    BIT STRING (${length} bytes)`);
        break;
      case 0x05: // NULL
        console.log(`    NULL`);
        break;
      case 0x06: // OBJECT IDENTIFIER
        console.log(`    OBJECT IDENTIFIER (${length} bytes)`);
        break;
      default:
        console.log(`    Unknown tag 0x${tag.toString(16)} (${length} bytes)`);
    }
    
    // 跳过内容
    offset += length;
    
    // 如果是SEQUENCE，递归分析（简化处理）
    if (tag === 0x30 && length > 0) {
      // 这里可以添加更详细的递归分析，但为了简化，我们只分析一层
    }
  }
}

// 当前的PEM转换函数
function hexToPem(privateKeyHex, publicKeyHex) {
  console.log('\n=== PEM格式生成过程 ===');
  console.log('输入十六进制私钥:', privateKeyHex);
  console.log('输入十六进制公钥:', publicKeyHex);
  
  // 构造SM2私钥的DER格式 (RFC 5915格式)
  // SEQUENCE {
  //   INTEGER 1,  // version
  //   OCTET STRING,  // private key
  //   [0] OBJECT IDENTIFIER,  // parameters (optional)
  //   [1] BIT STRING  // public key (optional)
  // }
  
  // 版本号 (INTEGER 1)
  const version = '020101';
  console.log('版本字段:', version);
  
  // 私钥 (OCTET STRING)
  const privateKeyOctet = '0420' + privateKeyHex;
  console.log('私钥OCTET STRING字段:', privateKeyOctet);
  
  // 参数 (可选) - SM2算法标识符
  const parameters = 'a00b06092a811ccf5501822d';
  console.log('参数字段:', parameters);
  
  // 公钥 (可选) - BIT STRING
  const publicKeyBitString = 'a144034200' + publicKeyHex;
  console.log('公钥BIT STRING字段:', publicKeyBitString);
  
  // 构造完整的私钥DER编码
  const privateKeySequence = version + privateKeyOctet + parameters + publicKeyBitString;
  console.log('私钥SEQUENCE内容:', privateKeySequence);
  
  const privateKeyLength = (privateKeySequence.length / 2).toString(16).padStart(2, '0');
  console.log('私钥SEQUENCE长度:', privateKeyLength);
  
  const privateKeyDer = '30' + privateKeyLength + privateKeySequence;
  console.log('完整私钥DER:', privateKeyDer);
  
  // 构造PEM格式的私钥
  const privateKeyPem = '-----BEGIN PRIVATE KEY-----\n' +
    Buffer.from(privateKeyDer, 'hex').toString('base64').match(/.{1,64}/g).join('\n') +
    '\n-----END PRIVATE KEY-----';
  
  // 构造SM2公钥的DER格式 (RFC 5280格式)
  // SEQUENCE {
  //   SEQUENCE {
  //     OBJECT IDENTIFIER,  // algorithm identifier
  //     NULL  // parameters
  //   },
  //   BIT STRING  // public key
  // }
  
  // 算法标识符 (包含NULL参数)
  const algorithmIdentifier = '300d06072a811ccf5501822d0500';
  console.log('算法标识符SEQUENCE:', algorithmIdentifier);
  
  // 公钥 (BIT STRING)
  const publicKeyData = '034200' + publicKeyHex;
  console.log('公钥BIT STRING字段:', publicKeyData);
  
  // 构造完整的公钥DER编码
  const publicKeySequence = algorithmIdentifier + publicKeyData;
  console.log('公钥SEQUENCE内容:', publicKeySequence);
  
  const publicKeyLength = (publicKeySequence.length / 2).toString(16).padStart(2, '0');
  console.log('公钥SEQUENCE长度:', publicKeyLength);
  
  const publicKeyDer = '30' + publicKeyLength + publicKeySequence;
  console.log('完整公钥DER:', publicKeyDer);
  
  // 构造PEM格式的公钥
  const publicKeyPem = '-----BEGIN PUBLIC KEY-----\n' +
    Buffer.from(publicKeyDer, 'hex').toString('base64').match(/.{1,64}/g).join('\n') +
    '\n-----END PUBLIC KEY-----';
  
  return {
    privateKeyPem,
    publicKeyPem
  };
}

// 生成测试密钥对并分析格式
function generateAndAnalyzeKeys() {
  console.log('=== 生成并分析SM2密钥格式 ===');
  
  // 生成SM2密钥对
  const keyPair = sm2.generateKeyPairHex();
  console.log('十六进制格式密钥:');
  console.log('- 私钥:', keyPair.privateKey);
  console.log('- 公钥:', keyPair.publicKey);
  
  // 使用我们当前的PEM转换函数
  const pemKeys = hexToPem(keyPair.privateKey, keyPair.publicKey);
  
  console.log('\n生成的PEM格式密钥:');
  console.log('- 私钥PEM:');
  console.log(pemKeys.privateKeyPem);
  console.log('- 公钥PEM:');
  console.log(pemKeys.publicKeyPem);
  
  // 分析私钥格式
  console.log('\n=== 分析私钥格式 ===');
  analyzePem(pemKeys.privateKeyPem, '私钥');
  
  // 分析公钥格式
  console.log('\n=== 分析公钥格式 ===');
  analyzePem(pemKeys.publicKeyPem, '公钥');
}

// 主函数
async function main() {
  generateAndAnalyzeKeys();
}

// 运行主函数
main().catch(console.error);