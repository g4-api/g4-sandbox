@echo off
rem Starts the Appium server from the sandbox for G4 Android sessions, on Appium's default address and port
rem (0.0.0.0:4723); arguments are passed to Appium, for example --port 4724.
rem APPIUM_HOME keeps the installed drivers (UiAutomator2) inside the sandbox instead of the user profile.
rem The UiAutomator2 driver needs the Android SDK (adb): set ANDROID_HOME or ANDROID_SDK_ROOT before starting.
setlocal

set "SCRIPT_DIR=%~dp0"
set "APPIUM_MAIN=%SCRIPT_DIR%runtime\nodejs\node_modules\appium\index.js"

if not exist "%APPIUM_MAIN%" (
    echo [ERROR] Appium was not found at "%APPIUM_MAIN%".
    echo [ERROR] This sandbox was published without Appium.
    exit /b 1
)

set "APPIUM_HOME=%SCRIPT_DIR%appium-home"

if not defined JAVA_HOME if exist "%SCRIPT_DIR%runtime\jdk\bin\java.exe" set "JAVA_HOME=%SCRIPT_DIR%runtime\jdk"
if not defined ANDROID_HOME if defined ANDROID_SDK_ROOT set "ANDROID_HOME=%ANDROID_SDK_ROOT%"
if not defined ANDROID_HOME (
    echo [WARNING] ANDROID_HOME and ANDROID_SDK_ROOT are not set. Appium starts, but Android sessions need the Android SDK.
)

"%SCRIPT_DIR%runtime\nodejs\node.exe" "%APPIUM_MAIN%" %*
exit /b %ERRORLEVEL%
