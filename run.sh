#!/bin/bash

set -e

sudo apt-get update
sudo apt-get install -y ansible tmux

# Set up tmux
echo "set -g mouse on" > ~/.tmux.conf
echo "set -g utf8 on" >> ~/.tmux.conf
echo "set -g status-utf8 on" >> ~/.tmux.conf
echo "set -g default-terminal 'screen-256color'" >> ~/.tmux.conf

tmux source-file ~/.tmux.conf


SESSION_NAME="Seedbox-Ansible"

tmux new-session -d -s "$SESSION_NAME" "
  ansible-playbook playbook.yml -vvv;
  if [ \$? -eq 0 ]; then
    echo 'Playbook completed successfully. Press Enter to exit.';
  else
    echo 'Playbook failed. Check the above output for errors. Make sure to check the vars/main.yml for any typos. If you are still receiving the error create a new issue on the Github repo. Press Enter to exit.';
  fi
  read
"

tmux attach-session -t "$SESSION_NAME"