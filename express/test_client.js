// API网关测试客户端
const sm2 = require("sm-crypto").sm2;
const sm3 = require("sm-crypto").sm3;
const sm4 = require("sm-crypto").sm4;
const axios = require("axios");

// 测试配置
const CONFIG = {
  gateway_url: "http://localhost:8082",
  appid: "app_001",
  sm2_private_key: "your_sm2_private_key_here",
  gateway_sm2_public_key: "your_gateway_sm2_public_key_here",
  sm4_key: "your_sm4_key_here", // 32字符十六进制字符串
  sm4_iv: "your_sm4_iv_here", // 32字符十六进制字符串
};

// 生成测试用的SM2密钥对
function generateTestKeys() {
  const keyPair = sm2.generateKeyPairHex();
  console.log("=== 生成测试密钥对 ===");
  console.log("SM2 私钥:", keyPair.privateKey);
  console.log("SM2 公钥:", keyPair.publicKey);
  console.log("========================\n");
  return keyPair;
}

// 构建签名数据
function buildSignatureData(method, uri, queryString, body, nonce, timestamp) {
  const parts = [
    method,
    uri,
    queryString || "",
    body || "",
    nonce,
    timestamp.toString(),
  ];
  return parts.join("&");
}

// 加密请求体
function encryptRequestBody(body, key, iv) {
  if (!body || body === "") {
    return "";
  }

  console.log("加密参数:");
  console.log("  密钥:", key);
  console.log("  IV:", iv);
  console.log("  密钥长度:", key.length);
  console.log("  IV长度:", iv.length);
  console.log("  原始请求体:", body);

  try {
    // 直接使用十六进制格式的密钥和IV进行加密（32字符）
    const encrypted = sm4.encrypt(body, key, { mode: "cbc", iv: iv });
    const result = Buffer.from(encrypted, "hex").toString("base64");
    console.log("  加密结果 (base64):", result);
    return result;
  } catch (error) {
    console.error("加密过程中发生错误:", error.message);
    throw error;
  }
}

// 解密响应体
function decryptResponseBody(encryptedBody, key, iv) {
  if (!encryptedBody || encryptedBody === "") {
    return "";
  }
  if (typeof encryptedBody !== "string") {
    try {
      return JSON.stringify(encryptedBody);
    } catch (e) {
      return String(encryptedBody);
    }
  }

  console.log("解密参数:");
  console.log("  密钥:", key);
  console.log("  IV:", iv);
  console.log("  密钥长度:", key.length);
  console.log("  IV长度:", iv.length);
  console.log("  加密数据 (base64):", encryptedBody);

  try {
    // 直接使用十六进制格式的密钥和IV进行解密（32字符）
    const hexString = Buffer.from(encryptedBody, "base64").toString("utf-8");
    const result = sm4.decrypt(hexString, key, { mode: "cbc", iv: iv });
    console.log("  解密结果:", result);
    return result;
  } catch (error) {
    console.error("解密过程中发生错误:", error.message);
    throw error;
  }
}

// 验证响应签名
function verifyResponseSignature(body, signature, publicKey) {
  if (!signature || !publicKey) {
    console.log("响应签名或公钥为空，跳过验签");
    return true;
  }

  try {
    console.log("响应验签数据:", body);
    console.log("响应签名:", signature);
    console.log("网关公钥:", publicKey);

    // 验证签名 (使用十六进制格式的公钥，启用SM3杂凑和DER编码)
    const is_valid = sm2.doVerifySignature(body, signature, publicKey, {
      hash: true,
      der: true
    });

    console.log("响应签名验证结果:", is_valid);
    return is_valid;
  } catch (error) {
    console.error("响应签名验证过程中发生错误:", error.message);
    return false;
  }
}

// 生成nonce
function generateNonce() {
  // 生成 20 位纯数字：10 位随机数 + 10 位秒级时间戳，满足网关 10-20 位要求
  const random10 = Math.floor(Math.random() * 1e10)
    .toString()
    .padStart(10, "0");
  const ts10 = Math.floor(Date.now() / 1000)
    .toString()
    .padStart(10, "0");
  return random10 + ts10;
}

// 发送API请求
async function sendApiRequest(method, path, body = "", queryString = "") {
  try {
    const nonce = generateNonce();
    const timestamp = Math.floor(Date.now() / 1000);

    // 构建签名数据
    const dataToSign = buildSignatureData(
      method,
      path,
      queryString,
      body,
      nonce,
      timestamp
    );

    // 生成签名 (使用十六进制格式的私钥)
    const signature = sm2.doSignature(dataToSign, CONFIG.sm2_private_key, {
      hash: true, // 启用SM3杂凑
      der: true, //启动ans1/der编码
      //publicKey  //传入公钥，签名过程会更快，但是公钥也是通过私钥解出来的，客户端没有从redis中获取公钥，所以这里注释掉
      //userId: "1234567812345678",  //国密算法国标userId默认为1234567812345678，可省略
    });

    // 加密请求体
    const encryptedBody = encryptRequestBody(
      body,
      CONFIG.sm4_key,
      CONFIG.sm4_iv
    );

    // 构建请求头
    const headers = {
      "X-App-ID": CONFIG.appid,
      "X-Signature": signature,
      "X-Nonce": nonce,
      "X-Timestamp": timestamp.toString(),
      "Content-Type": "application/octet-stream",
    };

    // 构建完整URL
    let url = `${CONFIG.gateway_url}${path}`;
    if (queryString) {
      url += `?${queryString}`;
    }

    console.log(`=== 发送 ${method} 请求到 ${url} ===`);
    console.log("请求头:", headers);
    console.log("原始请求体:", body);
    console.log("加密后请求体:", encryptedBody);
    console.log("签名数据:", dataToSign);
    console.log("SM2 私钥:", CONFIG.sm2_private_key);
    console.log("签名:", signature);
    console.log("=====================================\n");

    // 确保Content-Type正确设置
    headers["Content-Type"] = "application/octet-stream";

    // 发送请求
    const response = await axios({
      method: method.toLowerCase(),
      url: url,
      headers: headers,
      data: encryptedBody,
      timeout: 30000,
      transformRequest: [
        (data, headers) => {
          // 确保发送的是原始数据，而不是JSON字符串
          return data;
        },
      ],
    });

    console.log(`=== 收到响应 ===`);
    console.log("状态码:", response.status);
    console.log("响应头:", response.headers);
    console.log("加密响应体:", response.data);

    // 解密响应体
    let decryptedBody;
    const xEncrypted =
      response.headers &&
      (response.headers["x-encrypted"] === "true" ||
        response.headers["X-encrypted"] === "true" ||
        response.headers["X-Encrypted"] === "true");
    
    if (xEncrypted) {
      decryptedBody = decryptResponseBody(
        response.data,
        CONFIG.sm4_key,
        CONFIG.sm4_iv
      );
    } else {
      decryptedBody =
        typeof response.data === "string"
          ? response.data
          : JSON.stringify(response.data);
    }

    // 对于200状态码的响应，验证网关签名
    if (response.status === 200) {
      const responseSignature = response.headers["x-response-signature"] || 
                               response.headers["X-Response-Signature"] ||
                               response.headers["X-response-signature"];
      
      const isSignatureValid = verifyResponseSignature(
        decryptedBody,
        responseSignature,
        CONFIG.gateway_sm2_public_key
      );
      
      if (!isSignatureValid) {
        console.error("响应签名验证失败!");
        throw new Error("Response signature verification failed");
      } else {
        console.log("响应签名验证通过");
      }
    }

    console.log("==================\n");

    return {
      status: response.status,
      headers: response.headers,
      data: decryptedBody,
      encryptedData: response.data,
    };
  } catch (error) {
    console.error("请求失败:", error.message);
    if (error.response) {
      console.error("错误状态码:", error.response.status);
      console.error("错误响应头:", error.response.headers);
      console.error("错误响应体:", error.response.data);
    } else if (error.request) {
      console.error("请求已发送但无响应:", error.request);
    } else {
      console.error("请求配置错误:", error.message);
    }
    throw error;
  }
}

// 从Redis获取App配置
async function getAppConfigFromRedis(appid) {
  const Redis = require("ioredis");
  const redisClient = new Redis({
    host: "192.168.56.2",
    port: 6379,
    retryDelayOnFailover: 100,
    enableReadyCheck: false,
    maxRetriesPerRequest: null,
  });

  try {
    const appData = await redisClient.get(`app:${appid}`);
    if (appData) {
      const appConfig = JSON.parse(appData);
      return appConfig;
    }
  } catch (error) {
    console.error("获取App配置失败:", error.message);
  } finally {
    redisClient.quit();
  }

  return null;
}

// 测试函数
async function runTests() {
  console.log("开始API网关测试...\n");

  try {
    // 从Redis获取App配置
    const appConfig = await getAppConfigFromRedis("app_001");
    if (appConfig) {
      CONFIG.sm2_private_key = appConfig.sm2_private_key;
      CONFIG.gateway_sm2_public_key = appConfig.gateway_sm2_public_key;
      CONFIG.sm4_key = appConfig.sm4_key; // 32字符十六进制字符串
      CONFIG.sm4_iv = appConfig.sm4_iv; // 32字符十六进制字符串
    }

    // 测试1: 健康检查
    console.log("测试1: 健康检查");
    await sendApiRequest("GET", "/health");

    // 测试2: 获取用户信息
    console.log("测试2: 获取用户信息");
    await sendApiRequest("GET", "/api/user/info");

    // 测试3: 获取用户列表
    console.log("测试3: 获取用户列表");
    await sendApiRequest("GET", "/api/user/list");

    // 测试4: 创建用户
    console.log("测试4: 创建用户");
    const createUserData = JSON.stringify({
      name: "Test User",
      email: "test@example.com",
    });
    await sendApiRequest("POST", "/api/user/create", createUserData);

    // 测试5: 系统状态
    console.log("测试5: 系统状态");
    await sendApiRequest("GET", "/api/system/status");

    // 测试6: 带查询参数的请求
    console.log("测试6: 带查询参数的请求");
    await sendApiRequest("GET", "/api/user/list", "", "page=1&size=10");

    console.log("所有测试完成！");
  } catch (error) {
    console.error("测试失败:", error.message);
  }
}

// 单独测试函数
async function testSingleApi(method, path, body = "") {
  try {
    // 从Redis获取App配置
    const appConfig = await getAppConfigFromRedis("app_001");
    if (appConfig) {
      CONFIG.sm2_private_key = appConfig.sm2_private_key;
      CONFIG.gateway_sm2_public_key = appConfig.gateway_sm2_public_key;
      CONFIG.sm4_key = appConfig.sm4_key; // 32字符十六进制字符串
      CONFIG.sm4_iv = appConfig.sm4_iv; // 32字符十六进制字符串
      if (appConfig.gateway_sm2_public_key) {
        CONFIG.gateway_sm2_public_key = appConfig.gateway_sm2_public_key;
      }
    }

    await sendApiRequest(method, path, body);
  } catch (error) {
    console.error("测试失败:", error.message);
  }
}

// 命令行参数处理
const args = process.argv.slice(2);
if (args.length > 0) {
  const command = args[0];
  if (command === "test") {
    runTests();
  } else if (command === "single" && args.length >= 3) {
    const method = args[1];
    const path = args[2];
    const body = args[3] || "";
    testSingleApi(method, path, body);
  } else {
    console.log("用法:");
    console.log("  node test_client.js test                    # 运行所有测试");
    console.log(
      "  node test_client.js single GET /api/user/info  # 测试单个API"
    );
    console.log(
      '  node test_client.js single POST /api/user/create \'{"name":"test"}\'  # 测试POST请求'
    );
  }
} else {
  runTests();
}

module.exports = {
  sendApiRequest,
  generateTestKeys,
  buildSignatureData,
  encryptRequestBody,
  decryptResponseBody,
  verifyResponseSignature,
  getAppConfigFromRedis,
};