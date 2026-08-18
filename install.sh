#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${STACK_REPO_URL:-https://github.com/devansh-codes/stack.git}"
INSTALL_DIR="${STACK_INSTALL_DIR:-$HOME/Applications}"

command -v swift >/dev/null 2>&1 || {
  echo "swift is required. Install Xcode Command Line Tools with: xcode-select --install" >&2
  exit 1
}

# Works both when piped from curl and when run from inside a checkout.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)"

if [[ -n "$SCRIPT_DIR" && -x "$SCRIPT_DIR/scripts/build-app.sh" ]]; then
  BUILD_DIR="$SCRIPT_DIR"
else
  command -v git >/dev/null 2>&1 || {
    echo "git is required. Install Xcode Command Line Tools with: xcode-select --install" >&2
    exit 1
  }
  TMP_DIR="$(mktemp -d)"
  trap 'rm -rf "$TMP_DIR"' EXIT
  git clone --depth 1 "$REPO_URL" "$TMP_DIR/stack"
  BUILD_DIR="$TMP_DIR/stack"
fi

cd "$BUILD_DIR"
./scripts/build-app.sh

mkdir -p "$INSTALL_DIR"
rm -rf "$INSTALL_DIR/Stack.app"
cp -R "$BUILD_DIR/dist/Stack.app" "$INSTALL_DIR/Stack.app"

echo "Installed Stack to $INSTALL_DIR/Stack.app"
echo "Stack runs in the menu bar - look for the paperclip icon after launching."
