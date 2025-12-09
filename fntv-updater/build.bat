@echo off
setlocal

set "TARGET=%~1"
set GOOS=windows
set CGO_ENABLED=0

if "%TARGET%"=="" goto build_all
if "%TARGET%"=="windows_amd64" goto build_amd64
if "%TARGET%"=="windows_aarch64" goto build_aarch64

echo Unknown target architecture: %TARGET%
exit /b 1

:build_all
call :build_amd64
if %ERRORLEVEL% NEQ 0 exit /b %ERRORLEVEL%
call :build_aarch64
if %ERRORLEVEL% NEQ 0 exit /b %ERRORLEVEL%
echo Build all complete!
goto :eof

:build_amd64
echo Building windows_amd64 fntv-updater...
set GOARCH=amd64
if not exist "build\windows_amd64" mkdir "build\windows_amd64"
go build -ldflags "-s -w" -o build\windows_amd64\fntv-updater.exe .
if %ERRORLEVEL% NEQ 0 (
    echo Failed to build windows_amd64
    exit /b %ERRORLEVEL%
)
echo Build windows_amd64 fntv-updater complete!
goto :eof

:build_aarch64
echo Building windows_aarch64...
set GOARCH=arm64
if not exist "build\windows_aarch64" mkdir "build\windows_aarch64"
go build -ldflags "-s -w" -o build\windows_aarch64\fntv-updater.exe .
if %ERRORLEVEL% NEQ 0 (
    echo Failed to build windows_aarch64
    exit /b %ERRORLEVEL%
)
echo Build windows_aarch64 fntv-updater complete!
goto :eof
