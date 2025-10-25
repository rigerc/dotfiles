function check_directory_for_new_repository
    # Early exit if no .git directory exists
    if not test -d .git
        set -gx last_repository ""
        return
    end
    
    set current_repository (git rev-parse --show-toplevel 2> /dev/null)
    
    if [ "$current_repository" ] && \
        [ "$current_repository" != "$last_repository" ]
        
        onefetch
        
    end
    
    set -gx last_repository $current_repository
    
end
