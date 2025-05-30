#!/bin/bash

CONFIG_FILE="$HOME/.bashrc"

# Alias
echo "
alias k=kubectl
alias tf=terraform
" >> $CONFIG_FILE
