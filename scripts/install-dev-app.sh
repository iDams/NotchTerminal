#!/bin/sh

set -eu

if [ "${CONFIGURATION:-}" != "Debug" ]; then
  exit 0
fi

if [ -z "${TARGET_BUILD_DIR:-}" ] || [ -z "${FULL_PRODUCT_NAME:-}" ]; then
  exit 0
fi

SOURCE_APP="${TARGET_BUILD_DIR}/${FULL_PRODUCT_NAME}"
DEST_APP="/Applications/NotchTerminal.app"

if [ ! -d "$SOURCE_APP" ]; then
  echo "Dev install skipped: source app not found at $SOURCE_APP"
  exit 0
fi

echo "Installing Debug app to $DEST_APP"
/usr/bin/pkill -x "NotchTerminal" || true
/bin/rm -rf "$DEST_APP"
/usr/bin/ditto "$SOURCE_APP" "$DEST_APP"

if [ -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" ] && [ "${EXPANDED_CODE_SIGN_IDENTITY}" != "-" ]; then
  echo "Re-signing installed app with ${EXPANDED_CODE_SIGN_IDENTITY_NAME:-Apple Development}"
  /usr/bin/codesign --force --deep --sign "$EXPANDED_CODE_SIGN_IDENTITY" "$DEST_APP"
fi
