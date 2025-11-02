.PHONY: default setup build run release install uninstall

default: run

setup:
	@uv run Script/Setup.py || (echo "Setup failed" && exit 1)

build:
	swift build

run: build
	./.build/debug/olovebar

release:
	swift build -c release

install: setup release
	uv run Script/Deploy.py

uninstall:
	uv run Script/Uninstall.py