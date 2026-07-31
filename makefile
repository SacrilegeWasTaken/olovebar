.PHONY: default setup build bundle deploy tap only-tap run run-app


VERSION := $(shell uv run Script/Version.py)
USER_SHELL := $(shell echo $$SHELL)
TAP_DIR= "~/Projects/Utilitiestap"

default: run-app


# Build and launch the real .app bundle. Required for features gated by TCC
# (e.g. Wi-Fi network scanning needs Location Services, which is only granted
# to a bundled app, never to the bare `swift run` binary).
run: run-app

run-app: build bundle
	@pkill -f 'OLoveBar.app/Contents/MacOS/OLoveBar' 2>/dev/null || true
	.build/OLoveBar.app/Contents/MacOS/OLoveBar


setup:
	swift package resolve
	swift package update


notification:
	osascript -e 'display notification "Test body" with title "OLoveBar" subtitle "Placement test"'


build:
	swift build -c release


bundle:
	@uv run Script/Bundle.py .build/release/olovebar .build/OLoveBar.app com.sacrilege.olovebar


deploy:
	@uv run Script/Deploy.py --app .build/OLoveBar.app --output .build/OLoveBar.dmg


tap:
	TAP_DIR=$(TAP_DIR) VERSION=$(VERSION) uv run Script/Tap.py 


release: build bundle deploy


nix-hash:
	nix hash file --type sha256 --base64 .build/OLoveBar.dmg
