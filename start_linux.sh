#!/bin/bash

# Poly Copy Linux 启动脚本
# 自动加载 .env 文件并启动应用

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 检查 .env 文件是否存在
if [ ! -f ".env" ]; then
    echo "❌ 错误: 未找到 .env 文件"
    echo ""
    echo "请按照以下步骤操作:"
    echo "1. 复制 .env.example 为 .env"
    echo "   cp .env.example .env"
    echo ""
    echo "2. 编辑 .env 文件，填入你的配置"
    echo "   nano .env"
    echo ""
    exit 1
fi

echo "📋 正在加载配置文件 .env..."

# 加载 .env 文件到环境变量
set -a  # 自动导出所有变量
source .env
set +a

# 检查可执行文件
EXECUTABLE="poly_copy_linux"
if [ ! -f "$EXECUTABLE" ]; then
    echo "❌ 错误: 未找到可执行文件 $EXECUTABLE"
    exit 1
fi

# 确保可执行权限
chmod +x "$EXECUTABLE"

# 启动应用
echo "🚀 正在启动 Poly Copy..."
echo "📍 访问地址: http://localhost:${PORT:-4000}"
echo "🔒 管理员: ${ADMIN_USERNAME:-admin}"
echo ""
echo "按 Ctrl+C 停止应用"
echo ""

# 设置 PHX_SERVER=1 并启动
PHX_SERVER=1 exec ./"$EXECUTABLE"
