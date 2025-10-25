function cd --wraps=z --wraps==cd

    builtin cd $argv || return
    
    check_directory_for_new_repository
    
end

function z --wraps=cd --wraps==z

    builtin z $argv || return
    
    check_directory_for_new_repository
    
end
