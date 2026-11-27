#!/usr/bin/env bash
# Linux and macOS equivalent of start-appium.cmd
# Starts the Appium server from the sandbox for G4 Android sessions, on Appium's default address and port
# (0.0.0.0:4723); arguments are passed to Appium, for example --port 4724.
# APPIUM_HOME keeps the installed drivers (UiAutomator2) inside the sandbox instead of the user profile.
# The UiAutomator2 driver needs the Android SDK (adb): set ANDROID_HOME or ANDROID_SDK_ROOT before starting.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPIUM_MAIN="$SCRIPT_DIR/runtime/nodejs/lib/node_modules/appium/index.js"

if [ ! -f "$APPIUM_MAIN" ]; then
    echo "[ERROR] Appium was not found at \"$APPIUM_MAIN\"." >&2
    echo "[ERROR] This sandbox was published without Appium." >&2
    exit 1
fi

export APPIUM_HOME="$SCRIPT_DIR/appium-home"

if [ -z "${JAVA_HOME:-}" ] && [ -x "$SCRIPT_DIR/runtime/jdk/bin/java" ]; then
    export JAVA_HOME="$SCRIPT_DIR/runtime/jdk"
fi

if [ -z "${ANDROID_HOME:-}" ] && [ -n "${ANDROID_SDK_ROOT:-}" ]; then
    export ANDROID_HOME="$ANDROID_SDK_ROOT"
fi

if [ -z "${ANDROID_HOME:-}" ]; then
    echo "[WARNING] ANDROID_HOME and ANDROID_SDK_ROOT are not set. Appium starts, but Android sessions need the Android SDK." >&2
fi

exec "$SCRIPT_DIR/runtime/nodejs/bin/node" "$APPIUM_MAIN" "$@"
