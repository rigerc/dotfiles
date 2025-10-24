#!/data/data/com.termux/files/usr/bin/bash
#!/bin/bash

source "utils/common.sh"

echo "Current directory contents:" 
ls -la .

if command_exists bw; then
    bw_login
fi