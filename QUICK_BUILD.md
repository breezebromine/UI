# 快速打包指南

## 一键打包所有平台

### Linux / macOS
```bash
chmod +x build.sh
./build.sh
```

### Windows
```cmd
build.bat
```

## 打包单个平台

### Linux
```bash
MIX_ENV=prod BURRITO_TARGET=linux mix release poly_copy --overwrite
```

### Windows
```bash
MIX_ENV=prod BURRITO_TARGET=windows mix release poly_copy --overwrite
```

### macOS (Intel)
```bash
MIX_ENV=prod BURRITO_TARGET=macos mix release poly_copy --overwrite
```

### macOS (Apple Silicon)
```bash
MIX_ENV=prod BURRITO_TARGET=macos_silicon mix release poly_copy --overwrite
```

## 输出文件位置

所有打包文件在 `burrito_out/` 目录：
- `poly_copy_linux` - Linux 可执行文件
- `poly_copy_windows.exe` - Windows 可执行文件
- `poly_copy_macos` - macOS Intel 可执行文件
- `poly_copy_macos_silicon` - macOS M1/M2 可执行文件

## 运行打包后的应用

1. 将可执行文件和 `.env` 文件放在同一目录
2. 配置 `.env` 文件（参考 `.env.example`）
3. 运行：

**Linux/macOS:**
```bash
PHX_SERVER=1 ./poly_copy_linux
```

**Windows:**
```cmd
set PHX_SERVER=1
poly_copy_windows.exe
```

4. 访问 http://localhost:4000

## 完整文档

详细打包说明请查看 [BUILD_GUIDE.md](BUILD_GUIDE.md)
