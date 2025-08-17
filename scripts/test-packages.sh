#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Testing termclip packages locally...${NC}"
echo ""

# Test basic script functionality
echo "Testing basic functionality..."
cd "$PROJECT_DIR"

# Test help
echo -n "  Help command: "
if python3 termclip.py --help >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
fi

# Test pipe (non-destructive)
echo -n "  Pipe test: "
if echo "test" | python3 termclip.py >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${YELLOW}⚠ (may be normal if no clipboard available)${NC}"
fi

# Test WSL installer (dry run)
echo ""
echo "Testing WSL installer (dry run)..."
cd "$PROJECT_DIR/packages/wsl"
if bash -n install.sh; then
    echo -e "${GREEN}✓ WSL installer syntax is valid${NC}"
else
    echo -e "${RED}✗ WSL installer has syntax errors${NC}"
fi

# Test Arch PKGBUILD
echo ""
echo "Testing Arch PKGBUILD..."
cd "$PROJECT_DIR/packages/arch"
if command -v makepkg >/dev/null 2>&1; then
    if makepkg --nobuild --nodeps 2>/dev/null; then
        echo -e "${GREEN}✓ PKGBUILD is valid${NC}"
    else
        echo -e "${YELLOW}⚠ PKGBUILD validation failed${NC}"
    fi
else
    echo -e "${YELLOW}⚠ makepkg not available, skipping PKGBUILD test${NC}"
fi

# Test Homebrew formula
echo ""
echo "Testing Homebrew formula..."
cd "$PROJECT_DIR/packages/homebrew"
if command -v brew >/dev/null 2>&1; then
    if brew audit --strict termclip.rb 2>/dev/null; then
        echo -e "${GREEN}✓ Homebrew formula passes audit${NC}"
    else
        echo -e "${YELLOW}⚠ Homebrew formula has audit warnings${NC}"
    fi
else
    echo -e "${YELLOW}⚠ brew not available, skipping formula test${NC}"
fi

# Test winget manifest validation
echo ""
echo "Testing winget manifests..."
cd "$PROJECT_DIR/packages/winget/manifests/b/0xrushi/termclip/1.0.0"
if command -v winget >/dev/null 2>&1; then
    if winget validate --manifest . 2>/dev/null; then
        echo -e "${GREEN}✓ Winget manifests are valid${NC}"
    else
        echo -e "${YELLOW}⚠ Winget manifest validation failed${NC}"
    fi
else
    echo -e "${YELLOW}⚠ winget not available, skipping manifest validation${NC}"
fi

echo ""
echo -e "${BLUE}Local testing complete!${NC}"
echo ""
echo -e "${YELLOW}Manual tests to perform:${NC}"
echo "1. Test actual installation on each platform"
echo "2. Verify clipboard functionality works"
echo "3. Test OSC 52 sequences in compatible terminals"
echo "4. Test SSH/remote functionality"
