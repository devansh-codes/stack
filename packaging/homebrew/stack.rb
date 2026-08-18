cask "stack" do
  version "0.1.0"
  sha256 "REPLACE_WITH_SHA256_FROM_RELEASE_ZIP"

  url "https://github.com/devansh-codes/stack/releases/download/v#{version}/Stack.zip"
  name "Stack"
  desc "A pad of sticky notes for your Mac"
  homepage "https://github.com/devansh-codes/stack"

  depends_on macos: ">= :tahoe"

  app "Stack.app"

  zap trash: [
    "~/Library/Application Support/StackNotes",
    "~/Library/Preferences/com.devansh.stack.plist",
  ]
end
