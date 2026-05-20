# Bill Split — top-level Makefile.
#
# Delegates to frontend/ (Flutter app) and backend/ (FastAPI service).
# Each tier also has its own Makefile / scripts inside its directory; this
# file is the convenience entry point from the repo root.
#
# Common usage:
#   make test           # run both frontend and backend test suites
#   make analyze        # frontend static analysis
#   make frontend-run-ios       # boot the iPhone 17 sim + run the app
#   make frontend-run-android   # run the app on the Android emulator
#   make frontend-ios-rebuild   # clean Flutter + re-run `pod install` (use after Podfile or native-plugin changes)
#   make backend-run    # uvicorn locally on http://localhost:9090
#   make backend-test   # pytest in backend/

.PHONY: test analyze \
        frontend-test frontend-analyze frontend-install frontend-run-ios frontend-run-android \
        frontend-ios-rebuild \
        backend-test backend-run backend-install

# --- Aggregate -------------------------------------------------------------

test: frontend-test backend-test

analyze: frontend-analyze

# --- Frontend (Flutter) ----------------------------------------------------

frontend-test:
	cd frontend && flutter test

frontend-analyze:
	cd frontend && flutter analyze

frontend-install:
	cd frontend && flutter pub get

frontend-run-ios:
	cd frontend && flutter run -d iphone

frontend-run-android:
	cd frontend && flutter run -d emulator

# Run after editing ios/Podfile or upgrading a plugin with native iOS code
# (e.g. permission_handler). Clears Flutter's build cache, refreshes pub
# deps, then re-runs `pod install` so the new pod settings (preprocessor
# flags, deployment targets, etc.) actually take effect on the next build.
frontend-ios-rebuild:
	cd frontend && flutter clean && flutter pub get
	cd frontend/ios && pod install

# --- Backend (FastAPI) -----------------------------------------------------

backend-install:
	cd backend && python3 -m venv .venv && \
		.venv/bin/pip install --upgrade pip setuptools wheel && \
		.venv/bin/pip install -e ".[dev]"

backend-test:
	cd backend && .venv/bin/pytest

backend-run:
	# --host 0.0.0.0 so physical devices on the LAN (e.g. an iPhone running
	# the app on the same Wi-Fi) can reach the backend at the Mac's LAN IP.
	# Auth is enforced regardless: every request needs a valid Firebase ID
	# token, so non-loopback exposure is safe in dev.
	cd backend && .venv/bin/uvicorn app.main:app --reload --host 0.0.0.0 --port 9090
