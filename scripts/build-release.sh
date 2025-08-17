#!/bin/bash
set -e

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
RELEASE_DIR="$PROJECT_DIR/release"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Building termclip v${VERSION} release packages...${NC}"
echo ""

# Clean and create release directory
rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

# Copy main script
cp "$PROJECT_DIR/termclip.py" "$RELEASE_DIR/"
echo -e "${GREEN}✓ Copied termclip.py${NC}"

# Create Windows zip for winget
echo "Creating Windows package..."
cd "$RELEASE_DIR"
zip -q "termclip-windows-${VERSION}.zip" termclip.py
WINDOWS_SHA256=$(shasum -a 256 "termclip-windows-${VERSION}.zip" | cut -d' ' -f1)
echo -e "${GREEN}✓ Created termclip-windows-${VERSION}.zip${NC}"
echo -e "${YELLOW}  SHA256: $WINDOWS_SHA256${NC}"

# Create source tarball for Arch/Homebrew
echo "Creating source tarball..."
cd "$PROJECT_DIR"
git archive --format=tar.gz --prefix="termclip-${VERSION}/" HEAD > "$RELEASE_DIR/termclip-${VERSION}.tar.gz"
SOURCE_SHA256=$(shasum -a 256 "$RELEASE_DIR/termclip-${VERSION}.tar.gz" | cut -d' ' -f1)
echo -e "${GREEN}✓ Created termclip-${VERSION}.tar.gz${NC}"
echo -e "${YELLOW}  SHA256: $SOURCE_SHA256${NC}"

# Update manifests with correct SHA256 hashes
echo "Updating package manifests..."

# Update winget installer manifest
WINGET_INSTALLER="$PROJECT_DIR/packages/winget/manifests/b/0xrushi/termclip/1.0.0/termclip.installer.yaml"
if [[ -f "$WINGET_INSTALLER" ]]; then
    sed -i.bak "s/REPLACE_WITH_ACTUAL_SHA256_HASH/$WINDOWS_SHA256/" "$WINGET_INSTALLER"
    rm "$WINGET_INSTALLER.bak"
    echo -e "${GREEN}✓ Updated winget installer manifest${NC}"
fi

# Update Homebrew formula
HOMEBREW_FORMULA="$PROJECT_DIR/packages/homebrew/termclip.rb"
if [[ -f "$HOMEBREW_FORMULA" ]]; then
    sed -i.bak "s/REPLACE_WITH_ACTUAL_SHA256/$SOURCE_SHA256/" "$HOMEBREW_FORMULA"
    rm "$HOMEBREW_FORMULA.bak"
    echo -e "${GREEN}✓ Updated Homebrew formula${NC}"
fi

# Update Arch PKGBUILD
ARCH_PKGBUILD="$PROJECT_DIR/packages/arch/PKGBUILD"
if [[ -f "$ARCH_PKGBUILD" ]]; then
    sed -i.bak "s/sha256sums=('SKIP')/sha256sums=('$SOURCE_SHA256')/" "$ARCH_PKGBUILD"
    rm "$ARCH_PKGBUILD.bak"
    echo -e "${GREEN}✓ Updated Arch PKGBUILD${NC}"
fi

# Create installation instructions
cat > "$RELEASE_DIR/INSTALL.md" << EOF
# termclip v${VERSION} Installation

## Windows (winget)
\`\`\`cmd
winget install termclip
\`\`\`

## WSL/Ubuntu/Debian
\`\`\`bash
curl -fsSL https://raw.githubusercontent.com/0xrushi/termclip/main/packages/wsl/install.sh | bash
\`\`\`

## Arch Linux
\`\`\`bash
# From AUR (when published)
yay -S termclip

# Manual build
git clone https://github.com/0xrushi/termclip
cd termclip/packages/arch
makepkg -si
\`\`\`

## macOS (Homebrew)
\`\`\`bash
# From tap (when published)
brew tap 0xrushi/termclip
brew install termclip

# Direct install
brew install https://raw.githubusercontent.com/0xrushi/termclip/main/packages/homebrew/termclip.rb
\`\`\`

## Manual Installation
\`\`\`bash
# Download the script
curl -fsSL https://raw.githubusercontent.com/0xrushi/termclip/main/termclip.py -o termclip
chmod +x termclip

# Move to PATH
sudo mv termclip /usr/local/bin/
\`\`\`

## File Hashes
- Windows ZIP: \`$WINDOWS_SHA256\`
- Source TAR: \`$SOURCE_SHA256\`
EOF

echo -e "${GREEN}✓ Created installation instructions${NC}"

# Test Arch package build (if on Linux with makepkg)
if command -v makepkg >/dev/null 2>&1; then
    echo "Testing Arch package build..."
    cd "$PROJECT_DIR/packages/arch"
    if makepkg --nobuild --nodeps 2>/dev/null; then
        echo -e "${GREEN}✓ Arch PKGBUILD syntax is valid${NC}"
    else
        echo -e "${YELLOW}⚠ Could not validate Arch PKGBUILD${NC}"
    fi
fi

# Test Homebrew formula (if on macOS with brew)
if command -v brew >/dev/null 2>&1 && [[ "$OSTYPE" == "darwin"* ]]; then
    echo "Testing Homebrew formula..."
    cd "$PROJECT_DIR/packages/homebrew"
    if brew audit --strict termclip.rb 2>/dev/null; then
        echo -e "${GREEN}✓ Homebrew formula passes audit${NC}"
    else
        echo -e "${YELLOW}⚠ Homebrew formula audit warnings (may be normal)${NC}"
    fi
fi

echo ""
echo -e "${GREEN}🎉 Release build complete!${NC}"
echo ""
echo -e "${BLUE}Release files created in: $RELEASE_DIR${NC}"
echo "  • termclip.py"
echo "  • termclip-windows-${VERSION}.zip"
echo "  • termclip-${VERSION}.tar.gz"
echo "  • INSTALL.md"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "1. Create a GitHub release with the files in $RELEASE_DIR"
echo "2. Submit winget manifest to: https://github.com/Microsoft/winget-pkgs"
echo "3. Submit Arch PKGBUILD to AUR: https://aur.archlinux.org/"
echo "4. Create Homebrew tap or submit to homebrew-core"
echo ""
echo -e "${YELLOW}Important SHA256 hashes:${NC}"
echo "  Windows: $WINDOWS_SHA256"
echo "  Source:  $SOURCE_SHA256"
