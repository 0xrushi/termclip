# Homebrew Formula for termclip

This directory contains the Homebrew formula for termclip.

## Installation

### From this tap (after publishing)
```bash
brew tap 0xrushi/termclip
brew install termclip
```

### Local installation (for testing)
```bash
# From this directory
brew install --build-from-source ./termclip.rb

# Or install directly from URL
brew install https://raw.githubusercontent.com/0xrushi/termclip/main/packages/homebrew/termclip.rb
```

## Creating your own tap

1. Create a repository named `homebrew-termclip`
2. Copy `termclip.rb` to the root of that repository
3. Users can then install with:
   ```bash
   brew tap 0xrushi/termclip
   brew install termclip
   ```

## Formula details

- Depends on `python@3.12` (Homebrew's Python)
- Installs script to `libexec` and creates wrapper in `bin`
- Includes basic tests for functionality
- Supports installation from HEAD for development

## Testing the formula

```bash
# Test installation
brew install --verbose --build-from-source ./termclip.rb

# Test functionality  
echo "test" | termclip
termclip --paste

# Run formula audit
brew audit --strict ./termclip.rb

# Uninstall
brew uninstall termclip
```

## Publishing to Homebrew core

To submit to the main Homebrew repository:

1. Ensure the formula follows [Homebrew guidelines](https://docs.brew.sh/Formula-Cookbook)
2. Test thoroughly on macOS and Linux
3. Submit a pull request to [homebrew-core](https://github.com/Homebrew/homebrew-core)

## macOS-specific notes

- Uses native `pbcopy`/`pbpaste` when available
- Falls back to OSC 52 sequences for terminal clipboard
- Works great with Terminal.app, iTerm2, and other macOS terminals
