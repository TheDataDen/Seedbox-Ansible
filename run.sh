#!/bin/bash

set -e

echo "THERE HAVE BEEN SOME MAJOR CHANGES TO THIS PROJECT RECENTLY. PLEASE READ THE 'README.md' FILE AND CHECK THE CONTENTS OF THE 'vars/main.yml' FILE BEFORE RUNNING THIS SCRIPT."
echo -e "\n"
echo "PRESS ENTER TO IF YOU ARE READY TO RUN THE PLAYBOOK OTHERWISE PRESS CTRL+C TO EXIT."
read

PLAYBOOK_CMD="ansible-playbook playbook.yml -vvv"
SESSION_NAME="Seedbox-Ansible"
FLAG_FILE="/tmp/ansible-running.flag"
LOG_FILE="/tmp/ansible-run.log"

APT_UPDATED=false

# Install Ansible if not already installed
if ! command -v ansible &> /dev/null; then
    sudo apt-get update
    sudo apt-get install -y ansible
    APT_UPDATED=true
    ansible-galaxy install -r requirements.yml
fi

# Install tmux if not already installed
if ! command -v tmux &> /dev/null; then
    if ! $APT_UDPDATED; then
        sudo apt-get update
        APT_UPDATED=true
    fi
    sudo apt-get install -y tmux
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

# Create flag file to indicate playbook is running
echo "Ansible playbook started at $(date)" > "$FLAG_FILE"

# Clean up any existing log file
> "$LOG_FILE"


tmux new-session -d -s "$SESSION_NAME" "
echo 'Starting Ansible playbook...' | tee -a '$LOG_FILE';
  echo 'Log file: $LOG_FILE' | tee -a '$LOG_FILE';
  echo '========================' | tee -a '$LOG_FILE';
  
  $PLAYBOOK_CMD 2>&1 | tee -a '$LOG_FILE';
  
  # Capture exit code
  EXIT_CODE=\${PIPESTATUS[0]};
  
  # Clean up flag file
  rm -f '$FLAG_FILE';
  
  if [ \$EXIT_CODE -eq 0 ]; then
    echo 'Playbook completed successfully. Press Enter to exit.' | tee -a '$LOG_FILE';
  else
    echo 'Playbook failed. Check the above output for errors. Make sure to check the vars/main.yml for any typos. If you are still receiving the error create a new issue on the Github repo. Press Enter to exit.' | tee -a '$LOG_FILE';
  fi
  read
"

tmux attach-session -t "$SESSION_NAME"
