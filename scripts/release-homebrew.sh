#!/bin/bash
set -e

VERSION="$1"
if [[ -z "$VERSION" ]]; then
    echo "Usage: $0 <version>"
    echo "Example: $0 1.0.0"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Preparing Homebrew release for termclip v${VERSION}...${NC}"
echo ""

# 1. Check if git tag exists
if ! git tag | grep -q "^v${VERSION}$"; then
    echo -e "${YELLOW}Creating git tag v${VERSION}...${NC}"
    git tag "v${VERSION}"
    git push origin "v${VERSION}"
    echo -e "${GREEN}✓ Tag created and pushed${NC}"
    
    # Wait for GitHub to process the tag
    echo "Waiting 10 seconds for GitHub to process the tag..."
    sleep 10
else
    echo -e "${GREEN}✓ Tag v${VERSION} already exists${NC}"
fi

# 2. Calculate SHA256 of the release tarball
echo "Calculating SHA256 hash..."
TARBALL_URL="https://github.com/0xrushi/termclip/archive/v${VERSION}.tar.gz"
SHA256=$(curl -fsSL "$TARBALL_URL" | shasum -a 256 | cut -d' ' -f1)
echo -e "${GREEN}✓ SHA256: $SHA256${NC}"

# 3. Update Homebrew formula
FORMULA_FILE="$PROJECT_DIR/packages/homebrew/termclip.rb"
echo "Updating Homebrew formula..."

# Create updated formula
cat > "$FORMULA_FILE" << EOF
class Termclip < Formula
  desc "Cross-platform terminal clipboard helper with OSC 52 support"
  homepage "https://github.com/0xrushi/termclip"
  url "https://github.com/0xrushi/termclip/archive/v${VERSION}.tar.gz"
  sha256 "${SHA256}"
  license "MIT"
  head "https://github.com/0xrushi/termclip.git", branch: "main"

  depends_on "python@3.12"

  def install
    # Install the script to libexec and create a wrapper
    libexec.install "termclip.py"
    
    # Create wrapper script that uses Homebrew's Python
    (bin/"termclip").write <<~EOS
      #!/bin/bash
      exec "#{Formula["python@3.12"].opt_bin}/python3" "#{libexec}/termclip.py" "\$@"
    EOS
    
    chmod 0755, bin/"termclip"
  end

  test do
    # Test that the script loads without errors
    system bin/"termclip", "--help"
    
    # Test basic functionality on macOS
    if OS.mac?
      # Simple test: echo something and verify it doesn't crash
      pipe_output("#{bin}/termclip", "test")
    end
  end
end
EOF

echo -e "${GREEN}✓ Updated formula with v${VERSION} and SHA256${NC}"

# 4. Test the formula locally
echo ""
echo "Testing formula locally..."
cd "$PROJECT_DIR/packages/homebrew"

if command -v brew >/dev/null 2>&1; then
    echo "Running brew audit..."
    if brew audit --strict termclip.rb; then
        echo -e "${GREEN}✓ Formula passes audit${NC}"
    else
        echo -e "${YELLOW}⚠ Formula has audit warnings${NC}"
    fi
    
    echo ""
    echo "Testing installation..."
    if brew install --build-from-source ./termclip.rb; then
        echo -e "${GREEN}✓ Formula installs successfully${NC}"
        
        # Test basic functionality
        if termclip --help >/dev/null 2>&1; then
            echo -e "${GREEN}✓ termclip runs successfully${NC}"
        else
            echo -e "${YELLOW}⚠ termclip command failed${NC}"
        fi
        
        # Clean up test installation
        brew uninstall termclip
    else
        echo -e "${YELLOW}⚠ Formula installation failed${NC}"
    fi
else
    echo -e "${YELLOW}⚠ brew not available, skipping local test${NC}"
fi

echo ""
echo -e "${GREEN}🎉 Homebrew release preparation complete!${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "1. Copy updated formula to your homebrew-termclip tap repository:"
echo "   cp $FORMULA_FILE /path/to/homebrew-termclip/termclip.rb"
echo ""
echo "2. Commit and push to your tap:"
echo "   git add termclip.rb"
echo "   git commit -m 'Update termclip to v${VERSION}'"
echo "   git push origin main"
echo ""
echo "3. Users can now install with:"
echo "   brew tap 0xrushi/termclip"
echo "   brew install termclip"
echo ""
echo -e "${BLUE}Formula details:${NC}"
echo "  Version: ${VERSION}"
echo "  URL: ${TARBALL_URL}"
echo "  SHA256: ${SHA256}"
