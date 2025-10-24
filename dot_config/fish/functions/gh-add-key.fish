function gh-add-key
    set -l ssh_dir ~/.ssh
    set -l keys (find $ssh_dir -name "*.pub" -type f 2>/dev/null)
    
    if test (count $keys) -eq 0
        echo "Error: No SSH public keys found in $ssh_dir"
        return 1
    end
    
    for key in $keys
        set -l key_name (basename $key .pub)
        set -l title (hostname)-$key_name-(date +%Y%m%d)
        echo "Adding key: $key"
        gh ssh-key add $key --title $title
    end
end