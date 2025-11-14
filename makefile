.PHONY: default setup build run release install uninstall push

default: run

setup:
	@uv run Script/Setup.py || (echo "Setup failed" && exit 1)

build:
	swift build

run: build
	./.build/debug/olovebar


bundle: release
	@bash Script/Bundle.sh .build/release/olovebar .build/OLoveBar.app com.sacrilege.olovebar


install: bundle
	@echo "Installing .app to /Applications (may require sudo)"
	@if [ -d "/Applications/OLoveBar.app" ]; then \
		echo "Removing existing /Applications/OLoveBar.app"; \
		rm -rf "/Applications/OLoveBar.app"; \
	fi
	@echo "Copying .build/OLoveBar.app -> /Applications/OLoveBar.app"
	@ditto ".build/OLoveBar.app" "/Applications/OLoveBar.app"
	@echo "Installed. You may need to restart the app or Dock if an older process is running."

release:
	swift build -c release

install-cli: setup release
	uv run Script/Deploy.py

uninstall:
	uv run Script/Uninstall.py