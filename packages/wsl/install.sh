#!/bin/bash
set -e

VERSION="1.0.0"
INSTALL_DIR="$HOME/.local/bin"
SCRIPT_URL="https://raw.githubusercontent.com/0xrushi/termclip/main/termclip.py"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Installing termclip v${VERSION} for WSL/Linux...${NC}"
echo ""

# Check if we're in WSL
if grep -qEi "(Microsoft|WSL)" /proc/version 2>/dev/null; then
    echo -e "${GREEN}✓ WSL environment detected${NC}"
elif [[ -n "$WSL_DISTRO_NAME" ]]; then
    echo -e "${GREEN}✓ WSL environment detected${NC}"
else
    echo -e "${YELLOW}⚠ Not in WSL, but continuing installation...${NC}"
fi

# Check if Python is available
echo "Checking Python installation..."
if command -v python3 >/dev/null 2>&1; then
    PYTHON_VERSION=$(python3 --version 2>&1)
    echo -e "${GREEN}✓ Found: $PYTHON_VERSION${NC}"
    
    # Check Python version (need 3.8+)
    PYTHON_MAJOR=$(python3 -c "import sys; print(sys.version_info.major)")
    PYTHON_MINOR=$(python3 -c "import sys; print(sys.version_info.minor)")
    
    if [[ $PYTHON_MAJOR -lt 3 ]] || [[ $PYTHON_MAJOR -eq 3 && $PYTHON_MINOR -lt 8 ]]; then
        echo -e "${YELLOW}⚠ Python 3.8+ recommended, found $PYTHON_VERSION${NC}"
    fi
else
    echo -e "${RED}✗ Python 3 not found. Installing...${NC}"
    
    # Detect distro and install Python
    if command -v apt-get >/dev/null 2>&1; then
        echo "Detected Debian/Ubuntu. Installing python3..."
        sudo apt-get update
        sudo apt-get install -y python3 python3-pip curl
    elif command -v yum >/dev/null 2>&1; then
        echo "Detected RHEL/CentOS. Installing python3..."
        sudo yum install -y python3 python3-pip curl
    elif command -v dnf >/dev/null 2>&1; then
        echo "Detected Fedora. Installing python3..."
        sudo dnf install -y python3 python3-pip curl
    elif command -v pacman >/dev/null 2>&1; then
        echo "Detected Arch. Installing python..."
        sudo pacman -Sy python python-pip curl
    elif command -v zypper >/dev/null 2>&1; then
        echo "Detected openSUSE. Installing python3..."
        sudo zypper install -y python3 python3-pip curl
    else
        echo -e "${RED}Error: Could not detect package manager.${NC}"
        echo "Please install Python 3.8+ manually, then re-run this script."
        exit 1
    fi
    
    # Verify installation
    if command -v python3 >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Python installed successfully${NC}"
    else
        echo -e "${RED}✗ Python installation failed${NC}"
        exit 1
    fi
fi

# Create install directory
echo "Creating installation directory..."
mkdir -p "$INSTALL_DIR"
echo -e "${GREEN}✓ Created $INSTALL_DIR${NC}"

# Download script
echo "Downloading termclip..."
if command -v curl >/dev/null 2>&1; then
    if curl -fsSL "$SCRIPT_URL" -o "$INSTALL_DIR/termclip"; then
        echo -e "${GREEN}✓ Downloaded termclip.py${NC}"
    else
        echo -e "${RED}✗ Failed to download termclip${NC}"
        exit 1
    fi
elif command -v wget >/dev/null 2>&1; then
    if wget -q "$SCRIPT_URL" -O "$INSTALL_DIR/termclip"; then
        echo -e "${GREEN}✓ Downloaded termclip.py${NC}"
    else
        echo -e "${RED}✗ Failed to download termclip${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ Neither curl nor wget found${NC}"
    echo "Please install curl or wget and try again."
    exit 1
fi

# Make executable
chmod +x "$INSTALL_DIR/termclip"
echo -e "${GREEN}✓ Made termclip executable${NC}"

# Ensure proper shebang
if ! head -1 "$INSTALL_DIR/termclip" | grep -q "^#!/usr/bin/env python3"; then
    # Create temp file with shebang
    echo "#!/usr/bin/env python3" > "$INSTALL_DIR/termclip.tmp"
    cat "$INSTALL_DIR/termclip" >> "$INSTALL_DIR/termclip.tmp"
    mv "$INSTALL_DIR/termclip.tmp" "$INSTALL_DIR/termclip"
    chmod +x "$INSTALL_DIR/termclip"
    echo -e "${GREEN}✓ Added proper shebang${NC}"
fi

# Add to PATH if not already there
echo "Configuring PATH..."
PATH_ADDED=false

if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    # Add to appropriate shell config files
    for rc in ~/.bashrc ~/.zshrc ~/.profile; do
        if [[ -f "$rc" ]]; then
            if ! grep -q "export PATH.*$INSTALL_DIR" "$rc" 2>/dev/null; then
                echo "" >> "$rc"
                echo "# Added by termclip installer" >> "$rc"
                echo "export PATH=\"\$PATH:$INSTALL_DIR\"" >> "$rc"
                echo -e "${GREEN}✓ Added to $rc${NC}"
                PATH_ADDED=true
            fi
        fi
    done
    
    # Add to current session
    export PATH="$PATH:$INSTALL_DIR"
else
    echo -e "${GREEN}✓ $INSTALL_DIR already in PATH${NC}"
fi

echo ""
echo -e "${GREEN}🎉 termclip installed successfully!${NC}"
echo ""
echo -e "${BLUE}Usage examples:${NC}"
echo "  echo 'hello world' | termclip"
echo "  cat file.txt | termclip"
echo "  termclip --paste"
echo ""
echo -e "${BLUE}WSL-specific tips:${NC}"
echo "• termclip uses OSC 52 sequences to communicate with Windows Terminal"
echo "• Works great with Windows Terminal, Visual Studio Code integrated terminal"
echo "• For best results, use a modern terminal that supports OSC 52"
echo ""

# Test installation
if command -v termclip >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Installation verified - termclip is ready to use!${NC}"
    
    # Test basic functionality
    if echo "test" | termclip 2>/dev/null; then
        echo -e "${GREEN}✅ Basic functionality test passed${NC}"
    else
        echo -e "${YELLOW}⚠ Installation complete, but basic test failed${NC}"
        echo "This might be normal if you're not in a compatible terminal"
    fi
else
    echo -e "${YELLOW}⚠ termclip installed but not in current PATH${NC}"
    if [[ "$PATH_ADDED" == "true" ]]; then
        echo "Try: source ~/.bashrc  (or restart your shell)"
    else
        echo "Add $INSTALL_DIR to your PATH manually"
    fi
fi

echo ""
echo -e "${BLUE}Need help? Check: https://github.com/0xrushi/termclip${NC}"
