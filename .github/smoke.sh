#!/usr/bin/env bash
# Runs inside the Android emulator: installs the APK, launches it, prints the crash cause.
set +e
PKG=com.shatranj.chess_game
adb install -r apk/app-release.apk
adb logcat -c
adb shell monkey -p $PKG -c android.intent.category.LAUNCHER 1
sleep 25
adb exec-out screencap -p > screen.png

PID=$(adb shell pidof $PKG | tr -d '\r')
echo "=============== RESULT ($VARIANT) ==============="
if [ -n "$PID" ]; then
  echo "APP IS RUNNING (pid $PID)"
else
  echo "APP IS NOT RUNNING (it crashed or closed)"
fi

echo "=============== CRASH TRACE (AndroidRuntime only) ==============="
adb logcat -d -s AndroidRuntime:E | head -70

echo "=============== ROOT CAUSE LINES ==============="
adb logcat -d -s AndroidRuntime:E | grep -E "Caused by|IllegalState|RuntimeException|NoClassDef|NoSuchMethod|ClassNotFound|UnsatisfiedLink|Exception:" | head -8

echo "=============== NATIVE CRASH ==============="
adb logcat -d | grep -E -B2 -A 25 "Fatal signal|SIGSEGV|SIGABRT|Abort message" | head -50

# short cause shown as an annotation at the top of the run page
CAUSE=$(adb logcat -d -s AndroidRuntime:E | grep -E "Caused by|IllegalState|RuntimeException|NoClassDef|NoSuchMethod|ClassNotFound|UnsatisfiedLink" | head -3 | sed 's/^.*AndroidRuntime: *//' | tr '\n' ' ' | cut -c1-600)
if [ -z "$PID" ]; then
  echo "::error title=CRASH in $VARIANT::${CAUSE:-no AndroidRuntime lines (see log)}"
else
  echo "::notice title=OK $VARIANT::app is running"
fi

if [ -n "$GITHUB_STEP_SUMMARY" ]; then
  {
    echo "### $VARIANT: $( [ -n "$PID" ] && echo RUNNING || echo CRASHED )"
    echo '```'
    adb logcat -d -s AndroidRuntime:E | head -25 | sed 's/^.*AndroidRuntime: *//'
    echo '```'
  } >> "$GITHUB_STEP_SUMMARY"
fi

[ -n "$PID" ] || exit 1
