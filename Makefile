# Bill Split — dev shortcuts.
#
# Usage:
#   make test          # run the full Flutter test suite
#   make analyze       # run static analysis
#   make ios           # install the current build on the running iOS Simulator
#   make android       # install the current build on the running Android emulator
#   make run-ios       # build + install + launch with a hot-reload debug session
#   make run-android   # same for Android
#   make boot-ios      # boot the iPhone 17 simulator and open Simulator.app
#   make boot-android  # boot the Medium_Phone Android emulator
#
# See `flutter devices` for what's connected, `flutter emulators` for what's
# registered.
#

.PHONY: test analyze ios android run-ios run-android boot-ios boot-android

test:
	flutter test

analyze:
	flutter analyze

# --- Install only (no debug session) ----------------------------------------
# `flutter install` builds the app if needed and pushes it to the device.
# It does NOT keep a debug session running. Assumes the target device is
# already booted; run `make boot-ios` / `make boot-android` first if not.

ios:
	flutter install -d iphone

android:
	flutter install -d emulator

# --- Run with debug session -------------------------------------------------
# `flutter run` builds, installs, launches, and attaches a hot-reload session.
# Useful when you actively want to iterate; press `q` in the terminal to quit.

run-ios:
	flutter run -d iphone

run-android:
	flutter run -d emulator

run-personal:
	flutter run -d 00008140-0002055614C2801C

# --- Boot a simulator/emulator ----------------------------------------------

boot-ios:
	@xcrun simctl boot "iPhone 17" 2>/dev/null || true
	@open -a Simulator

boot-android:
	@flutter emulators --launch Medium_Phone 2>/dev/null || true
