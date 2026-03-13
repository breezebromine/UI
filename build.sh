#!/bin/bash
set -e

echo "🔨 开始打包 Poly Copy..."
echo ""

# 加载 asdf 环境（如果使用 asdf 安装）
if [ -f "$HOME/.asdf/asdf.sh" ]; then
    source "$HOME/.asdf/asdf.sh"
fi

# 检查 Elixir 是否安装
if ! command -v elixir &> /dev/null; then
    echo "❌ 错误: 未找到 Elixir。请先安装 Elixir 和 Erlang。"
    echo "安装指南: https://elixir-lang.org/install.html"
    exit 1
fi

echo "✅ Elixir 版本: $(elixir --version | head -n 1)"
echo ""

# 清理旧文件
echo "🧹 清理旧的打包文件..."
rm -rf burrito_out
rm -rf _build
rm -rf deps

# 安装依赖
echo "📦 安装依赖..."
export HEX_HTTP_CONCURRENCY=1
export HEX_HTTP_TIMEOUT=300
mix deps.get

# 编译资产
echo "🎨 编译前端资产..."
mix assets.setup
MIX_ENV=prod mix assets.deploy

# 打包各平台
export MIX_ENV=prod

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "开始打包各平台版本..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "🐧 打包 Linux x86_64 版本..."
BURRITO_TARGET=linux mix release poly_copy --overwrite
echo ""

echo "🪟 打包 Windows x86_64 版本..."
BURRITO_TARGET=windows mix release poly_copy --overwrite
echo ""

echo "🍎 打包 macOS Intel 版本..."
BURRITO_TARGET=macos mix release poly_copy --overwrite
echo ""

echo "🍎 打包 macOS Apple Silicon 版本..."
BURRITO_TARGET=macos_silicon mix release poly_copy --overwrite
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ 打包完成！"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "生成的文件："
ls -lh burrito_out/

# 获取版本号
VERSION=$(grep 'version:' mix.exs | head -1 | sed 's/.*"\(.*\)".*/\1/')
echo ""
echo "📦 版本: v$VERSION"
echo "📂 输出目录: $(pwd)/burrito_out"
echo ""
echo "提示: 将可执行文件和 .env 文件放在同一目录下即可运行"
