#!/usr/bin/env bash
set -euo pipefail

REPO="devstroop/gitctl"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
VERSION="${VERSION:-latest}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dir) INSTALL_DIR="$2"; shift 2 ;;
        --version) VERSION="$2"; shift 2 ;;
        --help)
            echo "Usage: curl -fsSL https://github.com/$REPO/releases/latest/download/install.sh | bash"
            echo ""
            echo "Options:"
            echo "  --dir <path>      Install directory (default: $INSTALL_DIR)"
            echo "  --version <tag>   Version tag to install (default: latest)"
            echo "  --help            Show this help"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Detect platform
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"

case "$ARCH" in
    x86_64|amd64) ARCH="x86_64" ;;
    aarch64|arm64) ARCH="aarch64" ;;
    *) echo "error: unsupported architecture '$ARCH' (expected x86_64 or aarch64)"; exit 1 ;;
esac

case "$OS" in
    linux) ;;
    darwin) OS="macos" ;;
    *) echo "error: unsupported OS '$OS' (expected linux or darwin)"; exit 1 ;;
esac

# Resolve latest version
if [ "$VERSION" = "latest" ]; then
    echo "  Fetching latest release..."
    VERSION="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" | grep '"tag_name"' | sed 's/.*"tag_name": "\(.*\)",/\1/')"
fi

ARCHIVE="gitctl-${VERSION}-${ARCH}-${OS}.tar.gz"
URL="https://github.com/$REPO/releases/download/$VERSION/$ARCHIVE"

echo "  Repository:  $REPO"
echo "  Version:     $VERSION"
echo "  Platform:    $ARCH-$OS"
echo "  Target:      $INSTALL_DIR/gitctl"
echo ""

# Download
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
echo "  Downloading $ARCHIVE..."
curl -fsSL "$URL" -o "$TMP/$ARCHIVE"

# Extract
echo "  Extracting..."
tar xzf "$TMP/$ARCHIVE" -C "$TMP"

# Install
mkdir -p "$INSTALL_DIR"
if [ ! -w "$INSTALL_DIR" ]; then
    echo "  Escalating with sudo to write to $INSTALL_DIR..."
    sudo install "$TMP/gitctl" "$INSTALL_DIR/gitctl"
else
    install "$TMP/gitctl" "$INSTALL_DIR/gitctl"
fi

echo ""
echo "  ✓ gitctl $VERSION installed to $INSTALL_DIR/gitctl"
"$INSTALL_DIR/gitctl" --help | head -1
