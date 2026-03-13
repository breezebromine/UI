#!/bin/bash
# Docker Burrito 打包脚本

set -e

echo "🐳 使用 Docker 打包 Poly Copy..."
echo ""

# 检查 Docker 是否安装
if ! command -v docker &> /dev/null; then
    echo "❌ Docker 未安装。请先安装 Docker:"
    echo "   sudo apt-get install docker.io"
    exit 1
fi

# 创建临时 Dockerfile 用于 Burrito 打包
cat > Dockerfile.burrito << 'EOF'
FROM hexpm/elixir:1.17.3-erlang-27.1.1-debian-trixie-20251208-slim

# 安装构建依赖
RUN apt-get update && \
    apt-get install -y build-essential git curl && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 安装 hex 和 rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# 复制项目文件
COPY . .

# 安装依赖
RUN mix deps.get

# 设置环境
ENV MIX_ENV=prod

# 编译资产
RUN mix assets.setup
RUN mix assets.deploy

# 打包所有平台
RUN mix release poly_copy --overwrite

CMD ["bash"]
EOF

echo "📦 构建 Docker 镜像..."
docker build -f Dockerfile.burrito -t poly_copy_builder .

echo ""
echo "🚀 开始打包..."

# 创建输出目录
mkdir -p burrito_out_docker

# 运行容器并复制输出文件
docker run --rm -v $(pwd)/burrito_out_docker:/output poly_copy_builder bash -c "
    cp -r burrito_out/* /output/ 2>/dev/null || echo '正在打包...'
"

echo ""
echo "✅ 打包完成！"
echo "📂 输出目录: $(pwd)/burrito_out_docker"
ls -lh burrito_out_docker/

# 清理
rm -f Dockerfile.burrito
