status is-interactive; or exit

# the following functions are here instead of in the functions directory
# because they utilize event handlers which autoloading does not support

# auto run onefetch if inside git repo
# --on-variable is a fish builtin that changes whenever the directory changes
# so this function will run whenever the directory changes
function auto_pwd --on-variable PWD

    # check if .git/ exists and is a git repo and if onefetch is installed
    if test -d .git && git rev-parse --git-dir >/dev/null 2>&1
        onefetch
    end
end