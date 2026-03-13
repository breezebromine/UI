@echo off
setlocal enabledelayedexpansion

echo ========================================
echo    Poly Copy Build Script (Windows)
echo ========================================
echo.

REM 检查 Elixir 是否安装
where elixir >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Elixir not found. Please install Elixir and Erlang first.
    echo Install guide: https://elixir-lang.org/install.html#windows
    pause
    exit /b 1
)

echo [OK] Elixir is installed
elixir --version | findstr "Elixir"
echo.

REM 清理旧文件
echo [CLEAN] Removing old build files...
if exist burrito_out rmdir /s /q burrito_out
echo.

REM 安装依赖
echo [DEPS] Installing dependencies...
call mix deps.get
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Failed to install dependencies
    pause
    exit /b 1
)
echo.

REM 编译资产
echo [ASSETS] Setting up assets...
call mix assets.setup
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Failed to setup assets
    pause
    exit /b 1
)

echo [ASSETS] Building assets...
set MIX_ENV=prod
call mix assets.deploy
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Failed to build assets
    pause
    exit /b 1
)
echo.

REM 打包各平台
echo ========================================
echo    Building releases...
echo ========================================
echo.

echo [BUILD] Building Linux x86_64...
set BURRITO_TARGET=linux
call mix release poly_copy --overwrite
echo.

echo [BUILD] Building Windows x86_64...
set BURRITO_TARGET=windows
call mix release poly_copy --overwrite
echo.

echo [BUILD] Building macOS Intel...
set BURRITO_TARGET=macos
call mix release poly_copy --overwrite
echo.

echo [BUILD] Building macOS Apple Silicon...
set BURRITO_TARGET=macos_silicon
call mix release poly_copy --overwrite
echo.

REM 显示结果
echo ========================================
echo    Build Complete!
echo ========================================
echo.
echo Generated files:
dir burrito_out /B
echo.
echo Output directory: %CD%\burrito_out
echo.
echo TIP: Place the executable and .env file in the same directory to run
echo.
pause
