.PHONY: default setup build deploy tap only-tap

default: run

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
	TAP_DIR=~/Projects/Utilities/tap uv run Script/Tap.py 
	nix hash file --type sha256 --base64 .build/OLoveBar.dmg

only-tap:
	TAP_DIR=~/Projects/Utilities/tap uv run Script/Tap.py 

release: build bundle deploy

nix-hash:
	nix hash file --type sha256 --base64 .build/OLoveBar.dmg