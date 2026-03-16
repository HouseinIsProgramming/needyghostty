APP_DIR ?= $(HOME)/Applications
APP_BUNDLE = $(APP_DIR)/NeedyGhostty.app
BIN_LINK = $(HOME)/.local/bin/needyghostty
DATA_DIR = $(HOME)/.local/share/needyghostty

.PHONY: build test install uninstall release clean

build:
	swift build -c release

test:
	swift test

install: build
	@mkdir -p "$(APP_BUNDLE)/Contents/MacOS" "$$(dirname "$(BIN_LINK)")" "$(DATA_DIR)"
	@cp .build/release/needyghostty "$(APP_BUNDLE)/Contents/MacOS/needyghostty"
	@cp Sources/NeedyGhostty/Info.plist "$(APP_BUNDLE)/Contents/Info.plist"
	@codesign --force --deep -s - "$(APP_BUNDLE)"
	@/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$(APP_BUNDLE)"
	@ln -sf "$(APP_BUNDLE)/Contents/MacOS/needyghostty" "$(BIN_LINK)"
	@[ -f "$(DATA_DIR)/notifications.json" ] || echo '[]' > "$(DATA_DIR)/notifications.json"
	@[ -f "$(DATA_DIR)/session-map.json" ] || echo '{}' > "$(DATA_DIR)/session-map.json"
	@pkill -x needyghostty 2>/dev/null || true
	@sleep 1
	@open "$(APP_BUNDLE)"
	@echo "Installed NeedyGhostty to $(APP_BUNDLE)"
	@echo ""
	@echo "Add to ~/.claude/settings.json:"
	@echo '  "hooks": {'
	@echo '    "SessionStart": [{"hooks": [{"type": "command", "command": "needyghostty hook session-start"}]}],'
	@echo '    "Stop": [{"hooks": [{"type": "command", "command": "needyghostty hook stop"}]}],'
	@echo '    "UserPromptSubmit": [{"hooks": [{"type": "command", "command": "needyghostty hook user-prompt-submit"}]}]'
	@echo '  }'

uninstall:
	@pkill -x needyghostty 2>/dev/null || true
	@rm -f "$(BIN_LINK)"
	@rm -rf "$(APP_BUNDLE)"
	@rm -rf "$(DATA_DIR)"
	@launchctl unload "$(HOME)/Library/LaunchAgents/com.needyghostty.plist" 2>/dev/null || true
	@rm -f "$(HOME)/Library/LaunchAgents/com.needyghostty.plist"
	@rmdir /tmp/needyghostty.lock 2>/dev/null || true
	@echo "Uninstalled NeedyGhostty"

release:
	swift build -c release --arch arm64 --arch x86_64
	@mkdir -p dist
	@rm -rf dist/NeedyGhostty.app
	@mkdir -p dist/NeedyGhostty.app/Contents/MacOS
	@cp .build/apple/Products/Release/needyghostty dist/NeedyGhostty.app/Contents/MacOS/needyghostty
	@cp Sources/NeedyGhostty/Info.plist dist/NeedyGhostty.app/Contents/Info.plist
	@codesign --force --deep -s - dist/NeedyGhostty.app
	@cd dist && zip -r NeedyGhostty.app.zip NeedyGhostty.app
	@echo "Release: dist/NeedyGhostty.app.zip"

clean:
	swift package clean
	rm -rf .build dist
