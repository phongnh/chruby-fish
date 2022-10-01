set -e RUBY_AUTO_VERSION 2>/dev/null

function chruby_auto --on-variable PWD -d 'Auto switch ruby version'
    set -l dir (pwd)

    while true
        set -l ruby_version ''

        test -f "$dir/.ruby-version" ;and read -l ruby_version < "$dir/.ruby-version"
        set ruby_version (string trim "$ruby_version")

        if test -n "$ruby_version"
            if test "$ruby_version" = "$RUBY_AUTO_VERSION"
                return 0
            else
                set -gx RUBY_AUTO_VERSION "$ruby_version"
                chruby "$ruby_version"
                return $status
            end
        end

        test -z "$dir" -o "$dir" = "/" ;and break

        set dir (string split -m 1 -r -- / $dir)[1]
    end

    if test -n "$RUBY_AUTO_VERSION"
        chruby_reset
        set -e RUBY_AUTO_VERSION
    end
end

function __chruby_auto_init --on-event fish_prompt
    chruby_auto
    functions --erase __chruby_auto_init
end
