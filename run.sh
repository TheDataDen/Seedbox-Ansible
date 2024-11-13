#!/bin/bash

set -e

sudo apt-get update
sudo apt-get install -y ansible

ansible-playbook playbook.yml -vvv