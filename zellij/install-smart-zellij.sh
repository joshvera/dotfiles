#!/bin/bash
# Install script for smart-zellij wrapper

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ZELLIJ_DIR="$HOME/.config/zellij"
SMART_ZELLIJ="$DOTFILES_DIR/zellij/smart-zellij"
BIN_DIR="$HOME/.local/bin"

echo "🔧 Installing smart-zellij wrapper..."

# Create necessary directories
mkdir -p "$BIN_DIR"
mkdir -p "$ZELLIJ_DIR"

# Copy configs to zellij directory
echo "📋 Copying zellij configurations..."
cp "$DOTFILES_DIR/zellij/config.kdl" "$ZELLIJ_DIR/"
cp "$DOTFILES_DIR/zellij/config-mobile.kdl" "$ZELLIJ_DIR/"
cp "$DOTFILES_DIR/zellij/config-desktop.kdl" "$ZELLIJ_DIR/"

# Copy layouts
if [ -d "$DOTFILES_DIR/zellij/layouts" ]; then
    echo "📐 Copying zellij layouts..."
    cp -r "$DOTFILES_DIR/zellij/layouts" "$ZELLIJ_DIR/"
fi

# Copy scripts
if [ -d "$DOTFILES_DIR/zellij/scripts" ]; then
    echo "📜 Copying zellij scripts..."
    cp -r "$DOTFILES_DIR/zellij/scripts" "$ZELLIJ_DIR/"
fi

# Install smart-zellij to PATH
echo "🔗 Installing smart-zellij to $BIN_DIR..."
cp "$SMART_ZELLIJ" "$BIN_DIR/"
chmod +x "$BIN_DIR/smart-zellij"

# Check if .local/bin is in PATH
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo ""
    echo "⚠️  WARNING: $HOME/.local/bin is not in your PATH"
    echo "   Add this to your shell profile (.bashrc, .zshrc, etc.):"
    echo "   export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo ""
fi

echo "✅ Installation complete!"
echo ""
echo "Usage:"
echo "  smart-zellij                    # Auto-detect device and start"
echo "  smart-zellij --show-detection   # Show detection info"
echo "  smart-zellij --device-type mobile   # Force mobile config"
echo ""
echo "Optional: Add an alias to your shell profile:"
echo "  alias zj='smart-zellij'"
echo ""
echo "Test the installation:"
echo "  smart-zellij --show-detection"