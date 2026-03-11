.PHONY: default setup build deploy push

default: run

setup:
	swift package resolve
	swift package update

notification:
	osascript -e 'display notification "Test body" with title "OLoveBar" subtitle "Placement test"'

release:
	swift build -c release

bundle:
	@uv run Script/Bundle.py .build/release/olovebar .build/OLoveBar.app com.sacrilege.olovebar

deploy: release bundle
	@uv run Script/Deploy.py --app .build/OLoveBar.app --output .build/OLoveBar.dmg
	
tap:
	TAP_DIR=~/Projects/Utilities/tap uv run Script/Tap.py 