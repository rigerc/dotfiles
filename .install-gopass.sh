#!/bin/bash

# exit immediately if password-manager-binary is already in $PATH asd
type bw >/dev/null 2>&1 && exit

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