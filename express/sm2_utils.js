const crypto = require('crypto');
const fs = require('fs');

// 您的SM2密钥
const publicKeyHex = '043a0361bed06dcc5ae184e1bb34a43aef88acf04305f0ae070c0b5c7314ad2417c08107ea633addea55404dbe9468cb99703ae3b5776c9111508c0fd435790ac5';
const privateKeyHex = '4842e67863802a958cd82c7425511346b86a02a87dcf76f526e67b2d0fadfc7d';

// 将十六进制私钥转换为PEM格式
function convertPrivateKeyHexToPEM(privateKeyHex) {
    // 创建私钥的ASN.1结构
    // SM2私钥的ASN.1结构: ECPrivateKey ::= SEQUENCE {
    //   version INTEGER { ecPrivkeyVer1(1) } (ecPrivkeyVer1),
    //   privateKey OCTET STRING,
    //   parameters [0] ECDomainParameters OPTIONAL,
    //   publicKey [1] BIT STRING OPTIONAL
    // }
    
    const version = '02'; // 版本号 (INTEGER 1)
    const privateKey = '04' + privateKeyHex; // OCTET STRING (带04标签)
    
    // 构建ASN.1序列
    const sequence = '30' + // SEQUENCE
        getLength(version.length / 2 + privateKey.length / 2) + 
        version + 
        privateKey;
    
    // 转换为DER格式
    const der = Buffer.from(sequence, 'hex');
    
    // 创建PEM格式
    const base64 = der.toString('base64');
    const pem = `-----BEGIN PRIVATE KEY-----\n${formatBase64(base64)}\n-----END PRIVATE KEY-----`;
    
    return pem;
}

// 将十六进制公钥转换为PEM格式
function convertPublicKeyHexToPEM(publicKeyHex) {
    // 公钥已经是未压缩格式 (04 + X + Y)
    // 创建SubjectPublicKeyInfo结构
    // SEQUENCE {
    //   SEQUENCE {
    //     OBJECT IDENTIFIER ecPublicKey (1.2.840.10045.2.1)
    //     OBJECT IDENTIFIER sm2p256v1 (1.2.156.10197.1.301)
    //   }
    //   BIT STRING (公钥数据)
    // }
    
    // OID for ecPublicKey: 1.2.840.10045.2.1
    const ecPublicKeyOID = '06082a8648ce3d0201';
    
    // OID for sm2p256v1: 1.2.156.10197.1.301
    const sm2OID = '06082a811ccf5501822d';
    
    // 算法标识序列
    const algorithmSequence = '30' + getLength((ecPublicKeyOID.length + sm2OID.length) / 2) + 
                             ecPublicKeyOID + sm2OID;
    
    // 公钥位字符串 (04 + X + Y)
    const publicKeyBitString = '03' + getLength(publicKeyHex.length / 2 + 1) + '00' + publicKeyHex;
    
    // 主序列
    const mainSequence = '30' + getLength((algorithmSequence.length + publicKeyBitString.length) / 2) + 
                        algorithmSequence + publicKeyBitString;
    
    // 转换为DER格式
    const der = Buffer.from(mainSequence, 'hex');
    
    // 创建PEM格式
    const base64 = der.toString('base64');
    const pem = `-----BEGIN PUBLIC KEY-----\n${formatBase64(base64)}\n-----END PUBLIC KEY-----`;
    
    return pem;
}

// 辅助函数：计算ASN.1长度字段
function getLength(length) {
    if (length < 128) {
        return length.toString(16).padStart(2, '0');
    } else {
        const lengthBytes = length.toString(16);
        const lengthLength = lengthBytes.length / 2;
        return (0x80 + lengthLength).toString(16) + lengthBytes;
    }
}

// 辅助函数：格式化Base64字符串（每64字符换行）
function formatBase64(base64) {
    const chunks = [];
    for (let i = 0; i < base64.length; i += 64) {
        chunks.push(base64.substring(i, i + 64));
    }
    return chunks.join('\n');
}

// 验证密钥转换
function verifyKeys() {
    console.log('正在验证密钥转换...');
    
    try {
        const privateKeyPEM = convertPrivateKeyHexToPEM(privateKeyHex);
        const publicKeyPEM = convertPublicKeyHexToPEM(publicKeyHex);
        
        console.log('✅ 私钥PEM格式:');
        console.log(privateKeyPEM);
        console.log('\n✅ 公钥PEM格式:');
        console.log(publicKeyPEM);
        
          // 保存到文件
            fs.writeFileSync('sm2-private.pem', privateKeyPEM);
            fs.writeFileSync('sm2-public.pem', publicKeyPEM);
            console.log('\n✅ 密钥已保存到文件: sm2-private.pem 和 sm2-public.pem');
        // 尝试使用Node.js crypto加载密钥验证格式
        try {
            const privateKey = crypto.createPrivateKey(privateKeyPEM);
            const publicKey = crypto.createPublicKey(publicKeyPEM);
            
            console.log('\n✅ 密钥格式验证成功！');
            console.log(`私钥类型: ${privateKey.asymmetricKeyType}`);
            console.log(`公钥类型: ${publicKey.asymmetricKeyType}`);
            
          
            
        } catch (error) {
            console.log('❌ 密钥格式验证失败:', error.message);
            console.log('这可能是因为Node.js的crypto模块对SM2的支持有限');
        }
        
        return { privateKeyPEM, publicKeyPEM };
        
    } catch (error) {
        console.log('❌ 密钥转换失败:', error.message);
        return null;
    }
}

// 使用OpenSSL命令行验证（如果系统安装了OpenSSL）
function verifyWithOpenSSL() {
    const { execSync } = require('child_process');
    
    try {
        console.log('\n🔍 使用OpenSSL验证密钥:');
        
        // 检查私钥
        const privateKeyInfo = execSync('openssl ec -in sm2-private.pem -text -noout 2>/dev/null || echo "OpenSSL验证失败"', { encoding: 'utf8' });
        console.log('私钥信息:');
        console.log(privateKeyInfo);
        
        // 检查公钥
        const publicKeyInfo = execSync('openssl ec -in sm2-public.pem -pubin -text -noout 2>/dev/null || echo "OpenSSL验证失败"', { encoding: 'utf8' });
        console.log('公钥信息:');
        console.log(publicKeyInfo);
        
    } catch (error) {
        console.log('OpenSSL验证不可用或失败');
    }
}

// 主函数
function main() {
    console.log('='.repeat(60));
    console.log('SM2 十六进制密钥转PEM格式工具');
    console.log('='.repeat(60));
    
    console.log('原始私钥 (HEX):', privateKeyHex);
    console.log('原始公钥 (HEX):', publicKeyHex);
    console.log('');
    
    const keys = verifyKeys();
    
    if (keys) {
        // 尝试使用OpenSSL验证
        verifyWithOpenSSL();
    }
    
    console.log('\n' + '='.repeat(60));
    console.log('转换完成！');
    console.log('='.repeat(60));
}

// 运行主函数
main();