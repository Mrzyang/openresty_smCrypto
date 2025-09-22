#!/bin/bash

# 检查是否提供了参数
if [ $# -eq 0 ]; then
    echo "错误: 请提供要执行的Lua文件名"
    echo "用法: $0 <lua文件名>"
    exit 1
fi

# 定义OpenResty路径
openresty_path="/opt/zy/software/openresty/"

# 将Luajit的bin目录添加到PATH环境变量
export PATH="$openresty_path/luajit/bin:$PATH"

# 执行Lua文件
luajit "$1"