#!/usr/bin/env bash

APK_PATH="/Users/mm/AI_BLIND_ASSISTANT/deliverables/AI-Blind-Assistant.apk"

echo "Started background auto-installer. Waiting for phone authorization..."

while true; do
    DEVICE=$(adb devices | grep -E "^[a-zA-Z0-9_-]+\s+device$" | head -n 1 | awk '{print $1}')
    if [ -n "$DEVICE" ]; then
        echo "Device authorized: $DEVICE"
        echo "Installing APK..."
        adb -s "$DEVICE" install -r "$APK_PATH"
        adb -s "$DEVICE" reverse tcp:8765 tcp:8765 || true
        adb -s "$DEVICE" shell am start -n com.example.ai_blind_assistant/.MainActivity
        echo "SUCCESS: Installed and launched on $DEVICE!"
        exit 0
    fi
    sleep 2
done
