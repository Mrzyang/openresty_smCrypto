import { sm2 } from 'sm-crypto-v2'

let keypair = sm2.generateKeyPairHex()

let publicKey = keypair.publicKey // 公钥
let privateKey = keypair.privateKey // 私钥
console.log("公钥:", publicKey)
console.log("私钥:", privateKey)

let msg = "Hello, SM2!"
// 纯签名 + 生成椭圆曲线点
let sigValueHex = sm2.doSignature(msg, privateKey, {der: true, hash: true}) // 签名
console.log("签名1:", sigValueHex)
let verifyResult = sm2.doVerifySignature(msg, sigValueHex, publicKey, {der: true, hash: true}) // 验签结果
console.log("验签结果1:", verifyResult ? "成功" : "失败")

// 纯签名
let sigValueHex2 = sm2.doSignature(msg, privateKey, {
    pointPool: [sm2.getPoint(), sm2.getPoint(), sm2.getPoint(), sm2.getPoint()], // 传入事先已生成好的椭圆曲线点，可加快签名速度
}) // 签名
console.log("签名2:", sigValueHex2)
let verifyResult2 = sm2.doVerifySignature(msg, sigValueHex2, publicKey) // 验签结果
console.log("验签结果2:", verifyResult2 ? "成功" : "失败")