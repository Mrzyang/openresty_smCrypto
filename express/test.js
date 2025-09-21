// const sm4 = require('sm-crypto').sm4;


// const key = 'af77614559c1af0a257fe623e1bd94b4'
// const iv = 'f0b6b1ae0e4b909a26715a55d2e45a9d'

// // 你的加密后的数据（从 API 网关返回的 Base64 字符串）
// const encryptedData = 'NzM5MTIzZjY3MTVjMjg5MmViMjE4NTFjMjRiYjc4NzIxMzZkMjYyN2VjNDBlOTE3MTI2MGFiYWVkZDM4M2JlZTI0NDJmZjY3OTg2OTJiNDJmMWJlZmMyZjU4ZjEwNzE4M2JjNjc0ZDdjMWU2ZmJiNjYyZGZiZWJmY2M3NDljM2Q0YWZmZjgzZWZlZTljN2U4OWI0ZjUwY2YwYWIyN2Y2NzBmMWM2OGUzMTFiMTdjODgzMTUyMDJkMWUzNWZkYWZlYTJhMWZkNWZlOTM4NWJlMDFmMDdhNDUwZWFhZDE3YTM2MWYwM2JlZjUwODNjZDNmYzNiYjAwMzc0YTA3ZTk2ZDdlNzFiZmI4MmRkYTFlYzJlZjQ5NzI3Njg3NThmZTc2MGYyYThmMjhiNzIwMWUxMjY4NjhkNjc1NzU4Y2E1YjI3OTdmZTdjODkxYzM0ZmJmNTQzZWI2NTdjZDk5ZDRiMWNlNGNmODc0ZDJjMzQxZWYzNzJjYTM4YjNhOWU4Yjk5OWQ0ZTk4NThlOTNlNjc3ZGJmYWMyZTViOTg0YmU1ZDE=';


// let a = Buffer.from(encryptedData, 'base64').toString('hex');

// let decryptData = sm4.decrypt(a, key, {mode: 'cbc', iv}) // 解密，cbc 模式
// console.log(decryptData)


const sm4 = require('sm-crypto').sm4
const base64js = require('base64-js');
const encryptData = '739123f6715c2892eb21851c24bb7872136d2627ec40e9171260abaedd383bee2442ff6798692b42f1befc2f58f107183bc674d7c1e6fbb662dfbebfcc749c3d0a06b2aceef7533c0d8bd5010a2b6072bd60ddbc7a51c9a43ffbbe72cc7acbfeec449e81a39a901e320e1ed0df16c597320a08554026d6fc8b6189b081e5b2da85574d48bbdab9a648b968f35e0d2bf1686a04164245cedd3132f20c2a8f2531911ae688a7d37fc5836a946f1177023d2f676cc12b4eb16d532c61df04f230290c4a6f2c268fbbfe380c5716b8706169' // 可以为 16 进制串或字节数组
const key = 'af77614559c1af0a257fe623e1bd94b4' // 可以为 16 进制串或字节数组，要求为 128 比特

// let decryptData = sm4.decrypt(encryptData, key) // 解密，默认输出 utf8 字符串，默认使用 pkcs#7 填充（传 pkcs#5 也会走 pkcs#7 填充）
// let decryptData = sm4.decrypt(encryptData, key, {padding: 'none'}) // 解密，不使用 padding
// let decryptData = sm4.decrypt(encryptData, key, {padding: 'none', output: 'array'}) // 解密，不使用 padding，输出为字节数组
let decryptData = sm4.decrypt(encryptData, key, {mode: 'cbc', iv: 'f0b6b1ae0e4b909a26715a55d2e45a9d'}) // 解密，cbc 模式

console.log(decryptData)

const base64String = 'NzM5MTIzZjY3MTVjMjg5MmViMjE4NTFjMjRiYjc4NzIxMzZkMjYyN2VjNDBlOTE3MTI2MGFiYWVkZDM4M2JlZTI0NDJmZjY3OTg2OTJiNDJmMWJlZmMyZjU4ZjEwNzE4M2JjNjc0ZDdjMWU2ZmJiNjYyZGZiZWJmY2M3NDljM2QwYTA2YjJhY2VlZjc1MzNjMGQ4YmQ1MDEwYTJiNjA3MmJkNjBkZGJjN2E1MWM5YTQzZmZiYmU3MmNjN2FjYmZlZWM0NDllODFhMzlhOTAxZTMyMGUxZWQwZGYxNmM1OTczMjBhMDg1NTQwMjZkNmZjOGI2MTg5YjA4MWU1YjJkYTg1NTc0ZDQ4YmJkYWI5YTY0OGI5NjhmMzVlMGQyYmYxNjg2YTA0MTY0MjQ1Y2VkZDMxMzJmMjBjMmE4ZjI1MzE5MTFhZTY4OGE3ZDM3ZmM1ODM2YTk0NmYxMTc3MDIzZDJmNjc2Y2MxMmI0ZWIxNmQ1MzJjNjFkZjA0ZjIzMDI5MGM0YTZmMmMyNjhmYmJmZTM4MGM1NzE2Yjg3MDYxNjk='; // 你的Base64字符串

const buffer = Buffer.from(base64String, 'base64');

// 将解码后的内容转为字符串
const decodedString = buffer.toString('utf-8');

console.log(decodedString); // 打印解码后的文本内容
