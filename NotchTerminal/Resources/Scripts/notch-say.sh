#!/usr/bin/env bash

# notch-say.sh
# Sends JSON payloads to NotchTerminal's Unix socket
# Usage: notch-say.sh --tool "npm" --status "running" --message "Building..."

SOCKET_PATH="/tmp/notchterminal.sock"
TOOL="custom"
STATUS="running"
MESSAGE=""
PROGRESS=""

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --tool|-t) TOOL="$2"; shift ;;
        --status|-s) STATUS="$2"; shift ;;
        --message|-m) MESSAGE="$2"; shift ;;
        --progress|-p) PROGRESS="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

if [ -z "$PROGRESS" ]; then
    JSON_PAYLOAD="{\"tool\": \"$TOOL\", \"status\": \"$STATUS\", \"message\": \"$MESSAGE\"}"
else
    JSON_PAYLOAD="{\"tool\": \"$TOOL\", \"status\": \"$STATUS\", \"message\": \"$MESSAGE\", \"progress\": $PROGRESS}"
fi

if [ -S "$SOCKET_PATH" ]; then
    echo "$JSON_PAYLOAD" | nc -q 0 -U "$SOCKET_PATH" >/dev/null 2>&1
    # Fallback to socat if nc fails
    if [ $? -ne 0 ]; then
        if command -v socat &>/dev/null; then
             echo "$JSON_PAYLOAD" | socat - UNIX-CONNECT:"$SOCKET_PATH" >/dev/null 2>&1
        fi
    fi
fi
