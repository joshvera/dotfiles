# Smart Zellij Configuration

Auto-detecting zellij configurations that adapt to your device type (mobile/desktop) with consistent keybindings and viewport-aware session management.

## Quick Start

```bash
# Just run the z command directly from your dotfiles!
./zellij/z

# Or add dotfiles/zellij to your PATH for global access
export PATH="$HOME/path/to/dotfiles/zellij:$PATH"
z
```

## The Problem This Solves

- **Viewport Persistence**: Sessions created on mobile were locked to small viewport sizes when opened on desktop
- **Device-Specific UX**: Mobile needs touch-friendly bindings, desktop needs full keyboard shortcuts
- **Manual Config Switching**: Having to remember different configs for different devices

## Auto-Detection Logic

The `z` command detects your device type using:

1. **Mobile Platforms**: Termux (Android), iSH (iOS), a-Shell
2. **Terminal Dimensions**: < 100 columns typically indicates mobile
3. **SSH Context**: Narrow SSH terminals often indicate mobile clients
4. **System Info**: ARM architecture with small terminal size

## Configuration Files

- `config.kdl` - Default/fallback configuration
- `config-mobile.kdl` - Touch-optimized (unbinds conflicting shortcuts)
- `config-desktop.kdl` - Full keyboard shortcuts enabled

### Key Differences

| Feature | Mobile | Desktop |
|---------|--------|---------|
| Ctrl shortcuts | Disabled (conflict with touch) | Enabled |
| Status hints | 40 chars, 3 hints | 80 chars, 5 hints |
| F-key bindings | ✅ Consistent | ✅ Consistent |
| Viewport serialization | ❌ Disabled | ❌ Disabled |

## Usage Examples

```bash
# Auto-detect and start
z

# Force specific device type
z --device-type mobile
z --device-type desktop

# Show detection details
z --show-detection

# Pass through zellij options
z -s mysession
z attach main

# Environment variable override
ZELLIJ_DEVICE_TYPE=desktop z
```

## Manual Override

If auto-detection isn't working correctly:

```bash
# Temporary override
export ZELLIJ_DEVICE_TYPE=mobile

# Or use command line flag
z --device-type desktop
```

## Setup

No installation needed! The `z` script finds configs relative to its location in your dotfiles.

**Option 1: Run directly**
```bash
./zellij/z
```

**Option 2: Add to PATH for global access**
```bash
# Add this to your shell profile (.zshrc, .bashrc, etc.)
export PATH="$HOME/path/to/your/dotfiles/zellij:$PATH"
```

## Troubleshooting

### Session Still Uses Wrong Viewport

```bash
# Delete problematic session to force fresh viewport
zellij delete-session <session-name>

# Or clear all cached sessions
rm -rf ~/.cache/org.Zellij-Contributors.Zellij/*/session_info/
```

### Wrong Device Detection

```bash
# Check what's being detected
z --show-detection

# Override if needed
z --device-type desktop
```

### Config Not Found

```bash
# Make sure you're running z from the zellij directory or it's in your PATH
./zellij/z --show-detection

# Configs should be in the same directory as the z script
ls -la zellij/config*.kdl
```

## Technical Details

### Viewport Fix
- `serialize-pane-viewport false` prevents mobile viewport dimensions from being persisted
- Sessions now adapt to current terminal size instead of using cached dimensions

### Consistent Keybindings
All configs share the same core keybindings to prevent muscle memory conflicts:
- F1-F6 for mode switching
- PageUp/PageDown for scrolling
- Ctrl+V/Alt+V for page scrolling
- Vim bindings in scroll mode

Only desktop configs add extra Ctrl shortcuts that might conflict with mobile touch gestures.