@echo off
setlocal

REM Narutibia: build do OTClient (Windows - Release).
REM Requer: Visual Studio 2022 + Ninja + vcpkg em C:\vcpkg (ou VCPKG_ROOT setado).

REM Force VCPKG_ROOT to C:\vcpkg if a valid vcpkg is installed there.
if exist "C:\vcpkg\vcpkg.exe" set VCPKG_ROOT=C:\vcpkg

if "%VCPKG_ROOT%"=="" set VCPKG_ROOT=C:\vcpkg
if not exist "%VCPKG_ROOT%\vcpkg.exe" (
    echo [ERRO] vcpkg.exe nao encontrado em %VCPKG_ROOT%
    exit /b 1
)

REM Ativa ambiente do MSVC x64 se ainda nao estiver.
where cl.exe >nul 2>nul
if errorlevel 1 (
    set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
    if not exist "%VSWHERE%" set "VSWHERE=%ProgramFiles%\Microsoft Visual Studio\Installer\vswhere.exe"
    for /f "usebackq tokens=*" %%i in (`"%VSWHERE%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "VSPATH=%%i"
    if "%VSPATH%"=="" (
        echo [ERRO] Visual Studio com toolchain C++ x64 nao encontrado.
        exit /b 1
    )
    call "%VSPATH%\VC\Auxiliary\Build\vcvars64.bat" || exit /b 1
)

pushd "%~dp0"

set PRESET=windows-release
if not "%1"=="" set PRESET=%1

echo === Configurando preset: %PRESET% ===
cmake --preset %PRESET% || (popd & exit /b 1)

echo === Compilando ===
cmake --build build\%PRESET% --parallel || (popd & exit /b 1)

echo.
echo === Build concluido ===
echo Binario em: build\%PRESET%\otclient.exe
popd
endlocal
