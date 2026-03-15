#!/bin/sh

set -eu

if [ "${CONFIGURATION:-}" != "Debug" ]; then
  exit 0
fi

if [ -z "${TARGET_BUILD_DIR:-}" ] || [ -z "${FULL_PRODUCT_NAME:-}" ]; then
  exit 0
fi

SOURCE_APP="${TARGET_BUILD_DIR}/${FULL_PRODUCT_NAME}"
DEST_APP="/Applications/NotchTerminal Dev.app"

if [ ! -d "$SOURCE_APP" ]; then
  echo "Dev install skipped: source app not found at $SOURCE_APP"
  exit 0
fi

echo "Installing Debug app to $DEST_APP"
/usr/bin/pkill -x "NotchTerminal Dev" || true
/bin/rm -rf "$DEST_APP"
/usr/bin/ditto "$SOURCE_APP" "$DEST_APP"

/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName NotchTerminal Dev" "$DEST_APP/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Set :CFBundleName NotchTerminal Dev" "$DEST_APP/Contents/Info.plist" 2>/dev/null || true
