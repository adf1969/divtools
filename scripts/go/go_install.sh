#!/usr/bin/env bash
# install-latest-go.sh
# Downloads and installs the latest stable Go for Linux amd64
# Can be run as a regular user — prompts for sudo password when needed

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo "Fetching latest stable Go version..."

# Fetch the latest stable version from the official JSON endpoint
# The first entry in the array is the latest stable release
LATEST_VERSION=$(curl -s https://go.dev/dl/?mode=json | \
    grep -oP '"version":\s*"\Kgo[0-9]+\.[0-9]+(\.[0-9]+)?(rc|beta)?[0-9]*' | head -n 1)

if [[ -z "$LATEST_VERSION" ]]; then
    echo -e "${RED}Failed to fetch latest version from go.dev${NC}"
    exit 1
fi

echo "Latest stable version: $LATEST_VERSION"

TARBALL="${LATEST_VERSION}.linux-amd64.tar.gz"
DOWNLOAD_URL="https://go.dev/dl/${TARBALL}"

echo "Downloading $TARBALL from $DOWNLOAD_URL..."

curl -fLO "$DOWNLOAD_URL"

if [[ ! -f "$TARBALL" ]]; then
    echo -e "${RED}Download failed.${NC}"
    exit 1
fi

# Use sudo only for system directories
echo "Preparing /usr/local/go (requires sudo)..."
sudo rm -rf /usr/local/go 2>/dev/null || true

echo "Extracting to /usr/local... (requires sudo)"
sudo tar -C /usr/local -xzf "$TARBALL"

echo "Cleaning up tarball..."
rm -f "$TARBALL"

# Create symlink in /usr/local/bin (requires sudo)
echo "Creating symlink: /usr/local/bin/go → /usr/local/go/bin/go (requires sudo)"
sudo ln -sf /usr/local/go/bin/go /usr/local/bin/go

# Optional: also symlink godoc and gofmt
sudo ln -sf /usr/local/go/bin/gofmt /usr/local/bin/gofmt 2>/dev/null || true
sudo ln -sf /usr/local/go/bin/godoc /usr/local/bin/godoc 2>/dev/null || true

echo -e "${GREEN}Go $LATEST_VERSION installed successfully!${NC}"
echo "Run 'go version' to verify."

echo ""
echo "If 'go version' doesn't work yet, add this to your shell config (~/.bashrc or ~/.profile):"
echo "    export PATH=\"\$PATH:/usr/local/go/bin\""
echo "Then run: source ~/.bashrc"
echo ""
echo "Tip: You can also add it permanently for all users by running:"
echo "    echo 'export PATH=\"\$PATH:/usr/local/go/bin\"' | sudo tee /etc/profile.d/go.sh"