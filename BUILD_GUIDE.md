# Poly Copy 打包指南

本项目使用 [Burrito](https://github.com/burrito-elixir/burrito) 将 Phoenix 应用打包成独立可执行文件。

## 前置要求

### 1. 安装 Elixir 和 Erlang

#### Linux (Ubuntu/Debian)
```bash
# 添加 Erlang Solutions 仓库
wget https://packages.erlang-solutions.com/erlang-solutions_2.0_all.deb
sudo dpkg -i erlang-solutions_2.0_all.deb
sudo apt-get update

# 安装 Erlang 和 Elixir
sudo apt-get install esl-erlang elixir
```

#### macOS
```bash
brew install elixir
```

#### Windows
下载并安装：
- Erlang: https://www.erlang.org/downloads
- Elixir: https://elixir-lang.org/install.html#windows

### 2. 验证安装
```bash
elixir --version
# 应显示 Elixir 1.15+ 和 Erlang/OTP 25+
```

## 打包步骤

### 1. 安装依赖
```bash
cd poly_copy
mix deps.get
```

### 2. 编译资产文件
```bash
mix assets.setup
mix assets.deploy
```

### 3. 打包所有平台版本
```bash
# 设置生产环境
export MIX_ENV=prod

# 打包所有目标平台
mix release poly_copy
```

### 4. 打包特定平台

#### Linux 版本
```bash
MIX_ENV=prod mix release poly_copy --overwrite
```
生成文件：`burrito_out/poly_copy_linux`

#### Windows 版本
```bash
# 在任何平台上都可以交叉编译 Windows 版本
MIX_ENV=prod BURRITO_TARGET=windows mix release poly_copy --overwrite
```
生成文件：`burrito_out/poly_copy_windows.exe`

#### macOS 版本 (Intel)
```bash
MIX_ENV=prod BURRITO_TARGET=macos mix release poly_copy --overwrite
```
生成文件：`burrito_out/poly_copy_macos`

#### macOS 版本 (Apple Silicon M1/M2)
```bash
MIX_ENV=prod BURRITO_TARGET=macos_silicon mix release poly_copy --overwrite
```
生成文件：`burrito_out/poly_copy_macos_silicon`

## 打包输出

所有打包的可执行文件会生成在 `burrito_out/` 目录中：

```
burrito_out/
├── poly_copy_linux           # Linux x86_64
├── poly_copy_windows.exe     # Windows x86_64
├── poly_copy_macos           # macOS Intel
└── poly_copy_macos_silicon   # macOS Apple Silicon
```

## 使用打包后的文件

### 1. 准备 .env 文件
在可执行文件同目录下创建 `.env` 文件：

```bash
SECRET_KEY_BASE=your-64-char-secret-key-base-here
ADMIN_USERNAME=admin
ADMIN_PASSWORD=changeme

# Discord webhook (可选)
DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/your-webhook-url

# Polymarket 配置
POLYMARKET_API_KEY=your-api-key
POLYMARKET_API_SECRET=your-api-secret
POLYMARKET_API_PASSPHRASE=your-passphrase
POLYMARKET_WALLET_ADDRESS=0x...
POLYMARKET_SIGNER_ADDRESS=0x...
POLYMARKET_PRIVATE_KEY=0x...
```

### 2. 运行应用

#### Linux/macOS
```bash
chmod +x poly_copy_linux
PHX_SERVER=1 ./poly_copy_linux
```

#### Windows
```cmd
set PHX_SERVER=1
poly_copy_windows.exe
```

### 3. 访问应用
打开浏览器访问：`http://localhost:4000`

## 数据库文件位置

应用启动后会在可执行文件同目录下自动创建：
- `polyx.db` - SQLite 数据库
- `polyx.db-shm` - 共享内存文件
- `polyx.db-wal` - 预写日志文件

## 常见问题

### Q1: 打包失败，提示依赖错误
```bash
# 清理并重新获取依赖
rm -rf _build deps
mix deps.get
mix deps.compile
```

### Q2: 跨平台编译 Windows 版本失败
Burrito 支持交叉编译，但某些依赖可能需要对应平台的原生编译。如果遇到问题：
1. 在 Windows 机器上直接编译
2. 使用 Docker 容器编译

### Q3: 可执行文件体积过大
这是正常的，因为包含了完整的 Erlang 运行时。通常大小为 50-100MB。

### Q4: Linux 上运行提示权限错误
```bash
chmod +x poly_copy_linux
```

### Q5: 修改配置后如何生效
1. 修改 `.env` 文件
2. 重启应用
3. 不需要重新打包

## 发布分发

### 打包为压缩文件
```bash
# Linux
tar -czf poly_copy_linux_v0.1.2.tar.gz burrito_out/poly_copy_linux .env.example

# Windows
zip poly_copy_windows_v0.1.2.zip burrito_out/poly_copy_windows.exe .env.example
```

### 使用 Docker 打包（推荐用于 CI/CD）
```bash
# 构建 Docker 镜像
docker build -t poly_copy_builder .

# 从容器中提取可执行文件
docker run --rm -v $(pwd)/output:/output poly_copy_builder cp /app/burrito_out/* /output/
```

## 自动化打包脚本

创建 `build.sh` 用于一键打包所有平台：

```bash
#!/bin/bash
set -e

echo "🔨 开始打包 Poly Copy..."

# 清理旧文件
rm -rf burrito_out

# 安装依赖
echo "📦 安装依赖..."
mix deps.get

# 编译资产
echo "🎨 编译前端资产..."
mix assets.setup
mix assets.deploy

# 打包各平台
export MIX_ENV=prod

echo "🐧 打包 Linux 版本..."
mix release poly_copy --overwrite

echo "🪟 打包 Windows 版本..."
BURRITO_TARGET=windows mix release poly_copy --overwrite

echo "🍎 打包 macOS Intel 版本..."
BURRITO_TARGET=macos mix release poly_copy --overwrite

echo "🍎 打包 macOS Silicon 版本..."
BURRITO_TARGET=macos_silicon mix release poly_copy --overwrite

echo "✅ 打包完成！文件位于 burrito_out/ 目录"
ls -lh burrito_out/
```

使用方法：
```bash
chmod +x build.sh
./build.sh
```

## 版本更新

修改 [mix.exs](mix.exs) 中的版本号：
```elixir
version: "0.1.3",  # 更新版本号
```

然后重新打包即可。

## 技术细节

- **打包工具**: Burrito 1.1
- **Erlang/OTP**: 需要 25+
- **Elixir**: 需要 1.15+
- **数据库**: SQLite3 (嵌入式，无需额外安装)
- **Web 服务器**: Bandit (内置)
- **可执行文件**: 包含完整的 BEAM VM 和所有依赖

## 相关链接

- [Burrito 文档](https://github.com/burrito-elixir/burrito)
- [Phoenix 部署指南](https://hexdocs.pm/phoenix/deployment.html)
- [Mix Release 文档](https://hexdocs.pm/mix/Mix.Tasks.Release.html)
