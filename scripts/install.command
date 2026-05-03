#!/bin/bash

echo "=============================="
echo "  Installing Speak..."
echo "=============================="

APP_NAME="Speak.app"
BUNDLE_ID="com.speak.app"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Check if Speak is currently running — quit it
if pgrep -x "Speak" > /dev/null; then
    echo "Speak is running — stopping it first..."
    pkill -x "Speak"
    sleep 1
fi

# Check if a previous install exists — clean it up
if [ -d "/Applications/$APP_NAME" ]; then
    echo "Previous install detected — removing it..."
    rm -rf "/Applications/$APP_NAME"
    defaults delete "$BUNDLE_ID" 2>/dev/null
    rm -f "$HOME/Library/Preferences/$BUNDLE_ID.plist"
    rm -rf "$HOME/Library/Saved Application State/$BUNDLE_ID.savedState" 2>/dev/null
    rm -rf "$HOME/Library/Caches/$BUNDLE_ID" 2>/dev/null
    echo "Previous install removed."
fi

# Install
echo "Copying Speak.app to /Applications..."
cp -R "$SCRIPT_DIR/$APP_NAME" "/Applications/$APP_NAME"
xattr -cr "/Applications/$APP_NAME"

echo ""
echo "Opening Speak..."
open "/Applications/$APP_NAME"

echo ""
echo "=============================="
echo "  Done!"
echo "=============================="
echo ""
echo "On first launch, grant these permissions when prompted:"
echo "  1. Speech Recognition"
echo "  2. Microphone"
echo "  3. Accessibility (System Settings > Privacy & Security > Accessibility)"
echo ""
