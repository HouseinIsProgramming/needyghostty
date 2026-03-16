PREFIX ?= /usr/local
BIN_DIR = $(PREFIX)/bin
DATA_DIR = $(HOME)/.local/share/needyghostty
LAUNCH_AGENTS_DIR = $(HOME)/Library/LaunchAgents
PLIST_NAME = com.needyghostty.plist

.PHONY: build test install uninstall release clean

build:
	swift build -c release

test:
	swift test

install: build
	@mkdir -p $(BIN_DIR) $(DATA_DIR) $(LAUNCH_AGENTS_DIR)
	@cp .build/release/needyghostty $(BIN_DIR)/needyghostty
	@sed "s|{{HOME}}|$(HOME)|g; s|{{BIN_DIR}}|$(BIN_DIR)|g" $(PLIST_NAME) > $(LAUNCH_AGENTS_DIR)/$(PLIST_NAME)
	@launchctl unload $(LAUNCH_AGENTS_DIR)/$(PLIST_NAME) 2>/dev/null || true
	@launchctl load $(LAUNCH_AGENTS_DIR)/$(PLIST_NAME)
	@[ -f "$(DATA_DIR)/notifications.json" ] || echo '[]' > "$(DATA_DIR)/notifications.json"
	@[ -f "$(DATA_DIR)/session-map.json" ] || echo '{}' > "$(DATA_DIR)/session-map.json"
	@echo "Installed needyghostty to $(BIN_DIR)/needyghostty"
	@echo ""
	@echo "Add to ~/.claude/settings.json:"
	@echo '  "hooks": {'
	@echo '    "SessionStart": [{"hooks": [{"type": "command", "command": "needyghostty hook session-start"}]}],'
	@echo '    "Notification": [{"hooks": [{"type": "command", "command": "needyghostty hook notification"}]}],'
	@echo '    "UserPromptSubmit": [{"hooks": [{"type": "command", "command": "needyghostty hook user-prompt-submit"}]}]'
	@echo '  }'

uninstall:
	@launchctl unload $(LAUNCH_AGENTS_DIR)/$(PLIST_NAME) 2>/dev/null || true
	@rm -f $(LAUNCH_AGENTS_DIR)/$(PLIST_NAME)
	@pkill -x needyghostty 2>/dev/null || true
	@rm -f $(BIN_DIR)/needyghostty
	@rm -rf $(DATA_DIR)
	@rmdir /tmp/needyghostty.lock 2>/dev/null || true
	@echo "Uninstalled needyghostty"

release:
	swift build -c release --arch arm64 --arch x86_64
	@mkdir -p .build/release-universal
	@cp .build/apple/Products/Release/needyghostty .build/release-universal/needyghostty
	@cd .build/release-universal && tar czf needyghostty-macos-universal.tar.gz needyghostty
	@echo "Universal binary: .build/release-universal/needyghostty-macos-universal.tar.gz"

clean:
	swift package clean
	rm -rf .build
