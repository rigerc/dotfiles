#!/bin/bash

source "utils/common.sh.tmpl"

set -uo pipefail

echo "Current directory contents:" 
ls -la .

if command_exists bw; then
    bw_login
fi