@echo off
chcp 65001 >nul
title SMART PROJECT CLEANER

echo ================================
echo      SMART PROJECT CLEANER
echo ================================
echo.

REM Check for pubspec.yaml
if not exist pubspec.yaml (
    echo [ERROR] pubspec.yaml not found. Run this file inside your Flutter project folder.
    pause
    exit /b
)

REM Check if Flutter is installed
where flutter >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Flutter is not detected in PATH.
    echo افتح CMD واكتب:
    echo flutter --version
    pause
    exit /b
)

echo Running flutter clean...
flutter clean

echo Removing build folders...
rmdir /s /q ".dart_tool"
rmdir /s /q "build"
rmdir /s /q ".idea"
rmdir /s /q "linux\ephemeral"
rmdir /s /q "chrome-device"

echo Creating CLEAN_EXPORT folder...
mkdir CLEAN_EXPORT

echo Copying project files...
xcopy lib CLEAN_EXPORT\lib /E /H /C /I
xcopy assets CLEAN_EXPORT\assets /E /H /C /I
copy pubspec.yaml CLEAN_EXPORT\
copy pubspec.lock CLEAN_EXPORT\

echo.
echo ================================
echo  CLEAN EXPORT READY SUCCESSFULLY
echo ================================

pause
