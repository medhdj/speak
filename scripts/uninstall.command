#!/bin/bash

echo "=============================="
echo "  Uninstalling Speak..."
echo "=============================="

BUNDLE_ID="com.speak.app"

# Quit Speak if running
if pgrep -x "Speak" > /dev/null; then
    echo "Stopping Speak..."
    pkill -x "Speak"
    sleep 1
fi

# Remove app
if [ -d "/Applications/Speak.app" ]; then
    rm -rf "/Applications/Speak.app"
    echo "Removed Speak.app"
else
    echo "Speak.app not found in /Applications."
fi

# Clean up preferences and caches
defaults delete "$BUNDLE_ID" 2>/dev/null
rm -f "$HOME/Library/Preferences/$BUNDLE_ID.plist"
rm -rf "$HOME/Library/Saved Application State/$BUNDLE_ID.savedState" 2>/dev/null
rm -rf "$HOME/Library/Caches/$BUNDLE_ID" 2>/dev/null

echo ""
echo "=============================="
echo "  Done!"
echo "=============================="
echo ""
echo "One manual step:"
echo "  System Settings > Privacy & Security > Accessibility"
echo "  → Remove Speak from the list"
echo ""
