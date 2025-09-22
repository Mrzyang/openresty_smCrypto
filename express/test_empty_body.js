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

// 从环境变量获取Redis配置，如果没有则使用默认值
const REDIS_HOST = process.env.REDIS_HOST || '192.168.17.1';
const REDIS_PORT = process.env.REDIS_PORT || '6379';


// 从Redis获取App配置
async function getAppConfigFromRedis(appid) {
  const Redis = require("ioredis");
  const redisClient = new Redis({
    host: REDIS_HOST,
    port: REDIS_PORT,
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

// 发送测试请求
async function sendTestRequest(method, path, body = "") {
  try {
    // 从Redis获取App配置
    const appConfig = await getAppConfigFromRedis("app_001");
    if (appConfig) {
      CONFIG.sm2_private_key = appConfig.sm2_private_key;
      CONFIG.gateway_sm2_public_key = appConfig.gateway_sm2_public_key;
      CONFIG.sm4_key = appConfig.sm4_key;
      CONFIG.sm4_iv = appConfig.sm4_iv;
    }

    const nonce = generateNonce();
    const timestamp = Math.floor(Date.now() / 1000);

    // 构建签名数据
    const dataToSign = buildSignatureData(
      method,
      path,
      "",
      body,
      nonce,
      timestamp
    );

    // 生成签名
    const signature = sm2.doSignature(dataToSign, CONFIG.sm2_private_key, {
      hash: true,
      der: true,
    });

    // 构建请求头
    const headers = {
      "X-App-ID": CONFIG.appid,
      "X-Signature": signature,
      "X-Nonce": nonce,
      "X-Timestamp": timestamp.toString(),
      "Content-Type": "application/octet-stream",
    };

    // 构建完整URL
    const url = `${CONFIG.gateway_url}${path}`;

    console.log(`=== 发送 ${method} 请求到 ${url} ===`);
    console.log("请求头:", headers);
    console.log("请求体:", body);
    console.log("签名数据:", dataToSign);
    console.log("签名:", signature);

    // 发送请求
    const response = await axios({
      method: method.toLowerCase(),
      url: url,
      headers: headers,
      data: body,
      timeout: 30000,
    });

    console.log(`=== 收到响应 ===`);
    console.log("状态码:", response.status);
    console.log("响应头:", response.headers);
    console.log("响应体:", response.data);
    console.log("==================\n");

    return response;
  } catch (error) {
    console.error("请求失败:", error.message);
    if (error.response) {
      console.error("错误状态码:", error.response.status);
      console.error("错误响应头:", error.response.headers);
      console.error("错误响应体:", error.response.data);
    }
    throw error;
  }
}

// 测试函数
async function runTests() {
  console.log("开始测试空请求体处理...\n");

  try {
    // 测试1: GET请求（应该成功，即使没有请求体）
    console.log("测试1: GET请求 /api/user/info (无请求体)");
    await sendTestRequest("GET", "/api/user/info");

    // 测试2: POST请求（无请求体，应该失败）
    console.log("测试2: POST请求 /api/user/create (无请求体)");
    try {
      await sendTestRequest("POST", "/api/user/create");
    } catch (error) {
      console.log("POST请求无请求体时正确返回错误\n");
    }

    // 测试3: POST请求（空字符串请求体，应该失败）
    console.log("测试3: POST请求 /api/user/create (空字符串请求体)");
    try {
      await sendTestRequest("POST", "/api/user/create", "");
    } catch (error) {
      console.log("POST请求空字符串请求体时正确返回错误\n");
    }

    // 测试4: PUT请求（无请求体，应该失败）
    console.log("测试4: PUT请求 /api/user/update (无请求体)");
    try {
      await sendTestRequest("PUT", "/api/user/update");
    } catch (error) {
      console.log("PUT请求无请求体时正确返回错误\n");
    }

    // 测试5: DELETE请求（无请求体，应该失败）
    console.log("测试5: DELETE请求 /api/user/delete (无请求体)");
    try {
      await sendTestRequest("DELETE", "/api/user/delete");
    } catch (error) {
      console.log("DELETE请求无请求体时正确返回错误\n");
    }

    console.log("所有测试完成！");
  } catch (error) {
    console.error("测试失败:", error.message);
  }
}

// 运行测试
runTests();