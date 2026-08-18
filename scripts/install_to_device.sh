#!/usr/bin/env bash
set -e

APK_PATH="/Users/mm/AI_BLIND_ASSISTANT/deliverables/AI-Blind-Assistant.apk"

if [ ! -f "$APK_PATH" ]; then
    echo "Error: APK not found at $APK_PATH"
    exit 1
fi

DEVICE_STATUS=$(adb devices | grep -E "^[a-zA-Z0-9_-]+\s+device$" | head -n 1 | awk '{print $1}')

if [ -n "$DEVICE_STATUS" ]; then
    echo "Device detected and authorized: $DEVICE_STATUS"
    echo "Installing updated APK..."
    adb -s "$DEVICE_STATUS" install -r "$APK_PATH"
    echo "Setting up reverse port forwarding for local assistant..."
    adb -s "$DEVICE_STATUS" reverse tcp:8765 tcp:8765 || true
    echo "Launching app..."
    adb -s "$DEVICE_STATUS" shell am start -n com.example.ai_blind_assistant/.MainActivity
    echo "Successfully installed and launched on $DEVICE_STATUS!"
else
    UNAUTHORIZED=$(adb devices | grep "unauthorized" | head -n 1 | awk '{print $1}')
    if [ -n "$UNAUTHORIZED" ]; then
        echo "Device $UNAUTHORIZED is connected but UNAUTHORIZED."
        echo "Please unlock your phone screen, check 'Always allow from this computer', and tap 'Allow'."
    else
        echo "No Android device detected over USB. Please connect your phone via USB cable."
    fi
    exit 1
fi
