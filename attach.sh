#!/bin/bash
set -e

SESSION_NAME="Seedbox-Ansible"
FLAG_FILE="/tmp/ansible-running.flag"
LOG_FILE="/tmp/ansible-run.log"

# Check if playbook is supposed to be running
if [[ -f "$FLAG_FILE" ]]; then
    # Check if tmux session exists
    if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        # Normal case: session exists, just attach
        echo "Attaching to existing session..."
        tmux attach-session -t "$SESSION_NAME"
    else
        # Post-reboot case: playbook running but no session
        echo "Playbook appears to be running, but no tmux session found."
        echo "Creating new session to monitor log..."
        
        # Create new session tailing the log
        tmux new-session -d -s "$SESSION_NAME" "tail -f $LOG_FILE"
        tmux attach-session -t "$SESSION_NAME"
    fi
else
    echo "No running playbook detected (no flag file found)."
    echo "Flag file: $FLAG_FILE"
    exit 1
fi