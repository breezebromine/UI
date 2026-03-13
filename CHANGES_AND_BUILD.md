# Poly Copy - 修改记录与构建指南

本文档记录了对原始项目 (`lalabuy948/poly_copy`) 所做的全部修改，以及在新机器上从零构建和运行的完整步骤。供 Claude 或开发者在其他机器上操作时参考。

---

## 一、代码修改记录

### 1. [核心修复] CLOB API 认证 — `lib/polyx/polymarket/client/auth.ex`

**问题**：调用 Polymarket CLOB API（如 `/balance-allowance`）时返回 `Unauthorized/Invalid api key`。

**根因**：原代码中 `POLY_ADDRESS` 请求头使用的是用户手动填入的地址（`config[:signer_address] || config[:wallet_address]`），可能是全小写的，而 Polymarket 服务端要求 POLY_ADDRESS 必须是从私钥推导出的 **EIP-55 校验和格式**（大小写混合）地址，与 Python 官方客户端 `py_clob_client` 的行为一致。

**修复方案**：从私钥自动推导 EIP-55 校验和地址，不再依赖用户手动填入的地址。

**修改前**（关键行）：
```elixir
auth_address = config[:signer_address] || config[:wallet_address]
```

**修改后**（关键行）：
```elixir
private_key = config[:private_key]
auth_address = derive_checksummed_address(private_key)
```

**新增的私有函数**：

- `derive_checksummed_address/1`：从私钥字节 → `ExSecp256k1.create_public_key` → `ExKeccak.hash_256` → 取后 20 字节 → 应用 EIP-55 校验和
- `eip55_checksum/1`：对小写 hex 地址的每个字符，检查 `keccak256(lowercase_hex)` 对应 nibble 是否 >= 8，是则大写

**依赖的库**：`ex_secp256k1`（secp256k1 椭圆曲线）、`ex_keccak`（Keccak-256 哈希）

### 2. [修复] 页面空白 — `lib/polyx_web/live/home_live.ex`

**问题**：首页加载时白屏约 27 秒，因为 `mount/3` 中同步调用了 `fetch_account_summary()`，该函数请求 CLOB API 且在网络不通时会等待超时。

**修复方案**：

1. 将 `fetch_account_summary()` 从 `mount/3` 中移除，改为 `send(self(), :load_account_summary)` 异步触发
2. `handle_info(:load_account_summary)` 和 `handle_info(:refresh_account)` 中使用 `Task.start/1` 将 API 调用放到独立进程，避免阻塞 LiveView 进程

**修改前**：
```elixir
# mount/3 中：
account_summary = fetch_account_summary()  # 同步阻塞，网络不通时等27秒

# handle_info 中：
def handle_info(:refresh_account, socket) do
  {:noreply, assign(socket, :account_summary, fetch_account_summary())}  # 阻塞LiveView
end
```

**修改后**：
```elixir
# mount/3 中：
send(self(), :load_account_summary)  # 异步
|> assign(:account_summary, %{usdc_balance: nil, positions_value: 0.0, total_pnl: 0.0, positions_count: 0})  # 默认空值

# handle_info 中：
def handle_info(:load_account_summary, socket) do
  pid = self()
  Task.start(fn ->
    summary = fetch_account_summary()
    send(pid, {:account_summary_loaded, summary})
  end)
  {:noreply, socket}
end

def handle_info({:account_summary_loaded, summary}, socket) do
  {:noreply, assign(socket, :account_summary, summary)}
end

def handle_info(:refresh_account, socket) do
  pid = self()
  Task.start(fn ->
    summary = fetch_account_summary()
    send(pid, {:account_summary_loaded, summary})
  end)
  {:noreply, socket}
end
```

### 3. [配置] 强制源码编译 NIF — `config/config.exs`

**新增行**：
```elixir
# Force build exqlite NIF from source (precompiled requires GLIBC 2.33+)
config :exqlite, force_build: true
```

**原因**：exqlite 的预编译 NIF 二进制需要 GLIBC 2.33+，部分 Linux 系统（如 Ubuntu 20.04）只有 GLIBC 2.31。强制从 C 源码编译可以解决兼容性问题。

### 4. [依赖] 添加 Rustler — `mix.exs`

在 `deps` 中新增：
```elixir
{:rustler, ">= 0.0.0", optional: true},
```

**原因**：`ex_secp256k1` 和 `ex_keccak` 是 Rust NIF 库。它们的预编译二进制也需要 GLIBC 2.33+。添加 `rustler` 依赖后可以通过设置 `RUSTLER_BUILD=1` 环境变量强制从 Rust 源码编译这些 NIF。

### 5. [配置] 运行时配置 — `config/runtime.exs`

- 添加了 `ADMIN_USERNAME` / `ADMIN_PASSWORD` 环境变量支持（Basic Auth 保护页面）
- 添加了 `DISCORD_WEBHOOK_URL` 环境变量支持
- prod 环境默认 `server: true`（直接启动 HTTP 服务器）
- 数据库路径默认为可执行文件同目录的 `polyx.db`

### 6. [新增] Discord 通知 — `lib/polyx/discord_notifier.ex`

新增模块，用于在成功执行跟单交易后通过 Discord Webhook 发送通知。

### 7. [新增] 构建脚本

- `build.sh` — Linux/macOS 构建脚本
- `build.bat` — Windows 构建脚本
- `build_with_docker.sh` — 使用 Docker 构建
- `Dockerfile.burrito` — Burrito 打包用的 Dockerfile
- `start_linux.sh` — Linux 启动脚本

---

## 二、环境配置文件

### `.env` 文件

从 `.env.example` 复制并填写：

```bash
cp .env.example .env
```

需要填写的字段：

| 字段 | 说明 | 必填 |
|------|------|------|
| `SECRET_KEY_BASE` | Phoenix secret，至少 64 字符 | 是 |
| `ADMIN_USERNAME` | 登录用户名（如 `admin`） | 是 |
| `ADMIN_PASSWORD` | 登录密码（如 `changeme`） | 是 |
| `DISCORD_WEBHOOK_URL` | Discord 通知 webhook URL | 否 |

**注意**：Polymarket API 凭证（api_key/secret/passphrase/wallet_address/private_key）通过网页 UI 的 "API Credentials" 面板填写，保存在 SQLite 数据库中，不需要写在 .env 文件里。

### 生成 SECRET_KEY_BASE

```bash
mix phx.gen.secret
```

或使用 openssl：
```bash
openssl rand -base64 48
```

---

## 三、新机器构建步骤

### 方式 A：标准 Mix Release（推荐，无需翻墙）

#### 1. 安装系统依赖

**Ubuntu/Debian**：
```bash
# Erlang + Elixir（推荐通过 asdf 安装）
# 或使用包管理器：
sudo apt-get install erlang elixir

# Rust（用于编译 NIF 原生库）
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env

# C 编译工具（exqlite 需要）
sudo apt-get install build-essential
```

**macOS**：
```bash
brew install erlang elixir rust
```

**Windows**：
- 安装 Erlang/OTP: https://www.erlang.org/downloads
- 安装 Elixir: https://elixir-lang.org/install.html
- 安装 Rust: https://rustup.rs/
- 安装 Visual Studio Build Tools（C 编译器）

#### 2. 克隆和编译

```bash
git clone https://github.com/breezebromine/UI.git
cd UI

# 安装 Elixir 依赖
mix deps.get

# 强制从源码编译 Rust NIF（关键步骤！）
# 必须先编译 rustler，再编译 ex_secp256k1 和 ex_keccak
mix deps.compile rustler
RUSTLER_BUILD=1 mix deps.compile ex_secp256k1 ex_keccak --force

# exqlite 会自动从 C 源码编译（config.exs 已配置 force_build: true）

# 编译项目
MIX_ENV=prod mix compile
```

#### 3. 构建前端资源

```bash
MIX_ENV=prod mix assets.deploy
```

#### 4. 配置环境

```bash
cp .env.example .env
# 编辑 .env 填写 SECRET_KEY_BASE、ADMIN_USERNAME、ADMIN_PASSWORD
```

#### 5. 生成 Release

```bash
MIX_ENV=prod mix release polyx --overwrite
```

#### 6. 启动

**Linux/macOS**：
```bash
# 加载环境变量
export $(cat .env | grep -v '^#' | xargs)

# 启动
_build/prod/rel/polyx/bin/polyx start
```

**Windows**：
```bat
REM 设置环境变量（手动或从 .env 读取）
set SECRET_KEY_BASE=your-secret
set ADMIN_USERNAME=admin
set ADMIN_PASSWORD=changeme

REM 启动
_build\prod\rel\polyx\bin\polyx.bat start
```

然后访问 http://localhost:4000/，使用 ADMIN_USERNAME/ADMIN_PASSWORD 登录。

### 方式 B：Burrito 单文件可执行程序（需要翻墙或手动下载）

Burrito 会生成一个单独的可执行文件，双击即可运行，无需安装 Erlang/Elixir。

#### 额外依赖

- `zig` 编译器：`sudo snap install zig --classic --beta`（或从 https://ziglang.org/download/ 下载）

#### Burrito 构建需要从 CDN 下载两个文件

CDN 地址 `beam-machine-universal.b-cdn.net` 在中国大陆被墙，需要通过 VPN 或手动下载。

**需要下载的文件**：

1. **musl libc**：
   - URL: `https://beam-machine-universal.b-cdn.net/musl/libc-musl-71c35316aff45bbfd243d8eb9bfc4a58b6eb97cee09514cd2030e145b68107fb.so`
   - 缓存文件名: `C47E2DB07C17594967D715468BC01E17AF29D846`

2. **OTP 27 ERTS（Erlang 运行时）**：
   - URL: `https://beam-machine-universal.b-cdn.net/OTP-27/linux/x86_64/any/otp_27_linux_any_x86_64.tar.gz`
   - 缓存文件名: `281FB32DF27F02366B73140F39071D6FE9D0D77B`

**手动安装步骤**：
```bash
mkdir -p ~/.cache/burrito_file_cache

# 用 VPN 下载后放入缓存目录并重命名
cp downloaded_musl.so ~/.cache/burrito_file_cache/C47E2DB07C17594967D715468BC01E17AF29D846
cp downloaded_erts.tar.gz ~/.cache/burrito_file_cache/281FB32DF27F02366B73140F39071D6FE9D0D77B
```

**注意**：缓存文件名是 Burrito 根据 URL 计算的 SHA1 哈希。如果 Burrito/OTP 版本变化，这些哈希也会变。

#### 构建命令

```bash
BURRITO_TARGET=linux MIX_ENV=prod mix release poly_copy --overwrite
```

生成的可执行文件在 `_build/prod/rel/poly_copy/` 目录下。

### 方式 C：Docker

```bash
docker build -f Dockerfile.burrito -t poly-copy .
docker run -p 4000:4000 \
  -e SECRET_KEY_BASE=your-secret \
  -e ADMIN_USERNAME=admin \
  -e ADMIN_PASSWORD=changeme \
  poly-copy
```

---

## 四、平台特定说明

### NIF 原生库兼容性

本项目依赖三个 NIF 原生库，它们的预编译二进制都需要 GLIBC 2.33+：

| NIF 库 | 语言 | 用途 | 解决方案 |
|--------|------|------|----------|
| `ex_secp256k1` | Rust | secp256k1 椭圆曲线签名 | `RUSTLER_BUILD=1 mix deps.compile ex_secp256k1 --force` |
| `ex_keccak` | Rust | Keccak-256 哈希 | `RUSTLER_BUILD=1 mix deps.compile ex_keccak --force` |
| `exqlite` | C | SQLite3 数据库 | `config :exqlite, force_build: true`（已在 config.exs 中配置） |

**如果系统 GLIBC >= 2.33**（Ubuntu 22.04+、Debian 12+等），可以直接使用预编译二进制，不需要安装 Rust，也不需要 `RUSTLER_BUILD=1`。

### 跨平台说明

Release 包含平台特定的 NIF 二进制，**不能跨平台复制**。每个目标平台需要单独编译：

- Linux 上编译的 release 只能在 Linux 上运行
- macOS 上编译的 release 只能在 macOS 上运行
- Windows 上编译的 release 只能在 Windows 上运行

---

## 五、Polymarket API 凭证获取

1. 打开 https://polymarket.com/ 并连接 MetaMask 钱包
2. 进入 Builder 页面生成 API 凭证，获取：
   - **API Key**
   - **API Secret**
   - **API Passphrase**
3. 从 MetaMask 导出：
   - **Private Key**（签名钱包的私钥）
4. 从 Polymarket 网站获取：
   - **Wallet Address**（Proxy 钱包地址，即 Polymarket 资金所在的地址）

在网页 UI 的 "API Credentials" 面板中填入以上信息并保存。

**重要**：`Signer Address` 字段是可选的，因为代码现在会自动从 Private Key 推导出正确的 EIP-55 校验和地址。

---

## 六、已知问题

1. **Burrito CDN 被墙**：`beam-machine-universal.b-cdn.net` 在中国大陆无法访问，需要 VPN 或手动下载缓存文件
2. **GLIBC 兼容性**：Ubuntu 20.04 等老系统需要从源码编译 NIF（已有解决方案，见上文）
3. **CLOB API 网络**：如果 `clob.polymarket.com` 无法访问（被墙），页面功能正常但数据为空。需要 VPN/代理环境运行
