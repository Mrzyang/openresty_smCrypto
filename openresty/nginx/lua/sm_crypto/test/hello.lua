-- 设置响应的 MIME 类型为 text/plain
ngx.header.content_type = "text/html; charset=utf-8" -- 设置字符集为 utf-8
ngx.say("Hello from Lua!")
ngx.exit(200) -- 返回 HTTP 200 状态码
