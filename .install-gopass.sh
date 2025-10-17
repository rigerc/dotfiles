#!/bin/bash

mkdir -p ".local/share/chezmoi/.tmp"

case "$(uname -s)" in
Darwin)
    # commands to install password-manager-binary on Darwin
    ;;
Linux)
# ...
    ;;
*)
    echo "unsupported OS"
    exit 1
    ;;
esac