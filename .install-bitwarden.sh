#!/bin/bash

# exit immediately if password-manager-binary is already in $PATH
type bw >/dev/null 2>&1 && exit

case "$(uname -s)" in
Darwin)
    # commands to install password-manager-binary on Darwin
    ;;
Linux)
    sudo pacman -S --quiet --noconfirm bitwarden-cli
    export BW_SESSION=$(bw login && bw unlock --raw) 
    ;;
*)
    echo "unsupported OS"
    exit 1
    ;;
esac