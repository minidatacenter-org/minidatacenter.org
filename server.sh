#!/bin/bash

# --- Configuration Variables (Minimal Essentials) ---
URL="$1"              # Git Repository URL
DIR="$2"              # Destination Directory
STARTSCRIPT="$3"      # Script to execute upon update
TEMPDIR="/tmp/git_clone_temp_update"
RESTART_DELAY=60      # Check frequency in seconds
SESSION_NAME="app_session" # Tmux session name

# Check if required arguments are provided and ensure tmux is installed
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <GIT_URL> <DEST_DIR> <START_SCRIPT_NAME>"
    exit 1
fi

if ! command -v tmux &> /dev/null; then
    echo "Error: tmux is not installed. Please install it to use this script."
    exit 1
fi

# Ensure destination directory exists
mkdir -p "$DIR"

# Function to manage service state via tmux
manage_service() {
    ACTION=$1
    if [ "$ACTION" == "stop" ]; then
        if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
            echo "Terminating existing tmux session: $SESSION_NAME"
            tmux kill-session -t "$SESSION_NAME"
        fi
    elif [ "$ACTION" == "start" ]; then
        echo "Launching start script in detached tmux session: $SESSION_NAME"
        tmux new-session -d -s "$SESSION_NAME" "cd $DIR && ./$STARTSCRIPT"
    fi
}

# Main loop to run indefinitely
while true; do
    echo "Starting update check loop..."

    # 1. Clean up and clone the repository into a temporary directory
    rm -rf "$TEMPDIR"
    mkdir -p "$TEMPDIR"

    if ! git clone "$URL" "$TEMPDIR"; then
        echo "Error: Git clone failed. Retrying in $RESTART_DELAY seconds..."
        sleep "$RESTART_DELAY"
        continue
    fi

    # 2. Compare if $TEMPDIR contains the EXACT SAME FILES as $DIR
    if ! diff -rq "$TEMPDIR" "$DIR" > /dev/null; then
        echo "Differences found. Updating files and restarting program."

        # 3. Stop running service
        manage_service stop

        # 4. Sync new files using rsync
        echo "Syncing files..."
        rsync -a --delete "$TEMPDIR/" "$DIR/"

        # 5. Start new service in tmux
        manage_service start
    else
        echo "No differences found. Keeping current program running."
    fi

    # Clean up the temp directory and wait for next check
    rm -rf "$TEMPDIR"
    echo "Waiting $RESTART_DELAY seconds before the next update check..."
    sleep "$RESTART_DELAY"
done
