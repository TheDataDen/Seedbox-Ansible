#!/bin/bash

set -e

sudo apt-get update
sudo apt-get install -y ansible

ansible-galaxy collection install community.general

ansible-playbook playbook.yml -vv