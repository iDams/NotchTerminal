#!/usr/bin/env bash

# notch-wrap-npm.sh
# A Smart CLI Wrapper that intercepts npm output and sends IPC events to NotchTerminal

SOCKET_PATH="/tmp/notchterminal.sock"
CMD="npm"

# Identify what the user is doing
ACTION="running"
MESSAGE="npm $*"
PROGRESS=""

# Try to parse the intention
if [[ "$1" == "install" || "$1" == "i" ]]; then
    MESSAGE="Installing packages..."
elif [[ "$1" == "run" && -n "$2" ]]; then
    MESSAGE="npm run $2"
fi

# Send "running" event to the Notch
if [ -S "$SOCKET_PATH" ]; then
    echo "{\"tool\": \"npm\", \"status\": \"running\", \"message\": \"$MESSAGE\"}" | nc -q 0 -U "$SOCKET_PATH" >/dev/null 2>&1 || true
fi

# Find the ACTUAL npm path, ignoring our own alias
REAL_NPM=$(command -v npm | grep -v "notch-wrap-npm" | head -n 1)

if [ -z "$REAL_NPM" ]; then
    # Fallback to standard locations if the alias completely masks it in this subshell
    for path in "/opt/homebrew/bin/npm" "/usr/local/bin/npm" "$HOME/.nvm/versions/node/*/bin/npm" "$HOME/.volta/bin/npm"; do
        if ls $path 1> /dev/null 2>&1; then
            REAL_NPM=$(ls $path | head -n 1)
            break
        fi
    done
fi

if [ -z "$REAL_NPM" ]; then
    echo "notch-wrap-error: could not find real npm executable"
    exit 1
fi

"$REAL_NPM" "$@"
EXIT_CODE=$?

# Analyze the result
if [ $EXIT_CODE -eq 0 ]; then
    SUCCESS_MSG="npm finished successfully"
    if [[ "$1" == "install" || "$1" == "i" ]]; then
        SUCCESS_MSG="Installation complete"
    fi
    if [ -S "$SOCKET_PATH" ]; then
        echo "{\"tool\": \"npm\", \"status\": \"success\", \"message\": \"$SUCCESS_MSG\"}" | nc -q 0 -U "$SOCKET_PATH" >/dev/null 2>&1 || true
    fi
else
    if [ -S "$SOCKET_PATH" ]; then
        echo "{\"tool\": \"npm\", \"status\": \"error\", \"message\": \"npm failed (exit $EXIT_CODE)\"}" | nc -q 0 -U "$SOCKET_PATH" >/dev/null 2>&1 || true
    fi
fi

exit $EXIT_CODE
