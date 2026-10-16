#!/usr/bin/env bash
# Runs inside the Android emulator: installs the APK, launches it, prints the crash log.
set +e
PKG=com.example.chess_game
adb install -r apk/app-release.apk
adb logcat -c
adb shell monkey -p $PKG -c android.intent.category.LAUNCHER 1
sleep 25
adb exec-out screencap -p > screen.png

PID=$(adb shell pidof $PKG | tr -d '\r')
echo "=============== RESULT ==============="
if [ -n "$PID" ]; then
  echo "APP IS RUNNING (pid $PID)"
else
  echo "APP IS NOT RUNNING (it crashed or closed)"
fi

echo "=============== JAVA CRASH (FATAL EXCEPTION) ==============="
adb logcat -d | grep -E -A 35 "FATAL EXCEPTION" | head -90

echo "=============== NATIVE CRASH ==============="
adb logcat -d | grep -E -B2 -A 25 "Fatal signal|SIGSEGV|SIGABRT|Abort message" | head -70

echo "=============== ERRORS FROM ADS / BILLING / FLUTTER ==============="
adb logcat -d | grep -iE "admob|mobileads|gads|billing|flutter" | grep -iE "error|exception|fail|crash" | head -40

[ -n "$PID" ] || exit 1
