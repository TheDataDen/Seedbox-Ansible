#!/bin/bash

set -e

PLAYBOOK_CMD="ansible-playbook playbook.yml -vvv"


APT_UPDATED=false

# Install Ansible if not already installed
if ! command -v ansible &> /dev/null; then
    sudo apt-get update
    sudo apt-get install -y ansible
    APT_UPDATED=true
fi

# Install tmux if not already installed
if ! command -v tmux &> /dev/null; then
    if ! $APT_UDPDATED; then
        sudo apt-get update
        APT_UPDATED=true
    fi
    sudo apt-get install -y tmux
fi

if ! tmux has-session -t dummy_session 2>/dev/null; then
    tmux new-session -d -s dummy_session
    tmux kill-session -t dummy_session
fi

# Set up tmux
TMUX_CONF=~/.tmux.conf
cat <<EOF > "$TMUX_CONF"
# Enable mouse support
set -g mouse on

# Use 256 colors
set -g default-terminal "screen-256color"

# Other useful configurations
set -g history-limit 10000
EOF

tmux source-file ~/.tmux.conf

SESSION_NAME="Seedbox-Ansible"

tmux new-session -d -s "$SESSION_NAME" "
  $PLAYBOOK_CMD;
  if [ \$? -eq 0 ]; then
    echo 'Playbook completed successfully. Press Enter to exit.';
  else
    echo 'Playbook failed. Check the above output for errors. Make sure to check the vars/main.yml for any typos. If you are still receiving the error create a new issue on the Github repo. Press Enter to exit.';
  fi
  read
"

tmux attach-session -t "$SESSION_NAME"