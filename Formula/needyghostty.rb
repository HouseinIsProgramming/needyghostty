class Needyghostty < Formula
  desc "Menu bar notifications for Claude Code sessions in Ghostty"
  homepage "https://github.com/housien/needyghostty"
  version "0.1.0"

  on_macos do
    url "https://github.com/housien/needyghostty/releases/download/v#{version}/needyghostty-macos-universal.tar.gz"
    # sha256 will be updated by the release workflow
    sha256 "PLACEHOLDER"
  end

  depends_on :macos

  def install
    bin.install "needyghostty"
  end

  service do
    run [opt_bin/"needyghostty"]
    keep_alive true
    log_path var/"log/needyghostty.log"
    error_log_path var/"log/needyghostty.log"
  end

  def caveats
    <<~EOS
      To start NeedyGhostty:
        brew services start needyghostty

      Add the following hooks to ~/.claude/settings.json:
        {
          "hooks": {
            "SessionStart": [{"hooks": [{"type": "command", "command": "needyghostty hook session-start"}]}],
            "Notification": [{"hooks": [{"type": "command", "command": "needyghostty hook notification"}]}],
            "UserPromptSubmit": [{"hooks": [{"type": "command", "command": "needyghostty hook user-prompt-submit"}]}]
          }
        }
    EOS
  end
end
