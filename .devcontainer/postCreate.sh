#!/bin/bash

echo "
alias tf='tofu'
alias k='kubectl'
alias d='doctl'
alias talos='talosctl'
alias t='talosctl'
" >> ~/.bashrc

# https://getvoicemode.com/
claude mcp add --scope user voicemode -- uvx --refresh voice-mode