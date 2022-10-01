set -g CHRUBY_VERSION '0.1.0'

set -ge RUBIES
test -d "$PREFIX/opt/rubies" ;and set -gx RUBIES $RUBIES "$PREFIX"/opt/rubies/*
test -d "$HOME/.rubies" ;and set -gx RUBIES $RUBIES "$HOME"/.rubies/*

function chruby_reset -d 'chruby_reset'
    test -z "$RUBY_ROOT" ;and return

    set PATH (string match -v "$RUBY_ROOT/bin" $PATH)
    test -n "$GEM_ROOT" ;and set PATH (string match -v "$GEM_ROOT/bin" $PATH)

    # Normal User
    if test (id -u) -ne 0
        test -n "$GEM_HOME" ;and set PATH (string match -v "$GEM_HOME/bin" $PATH)

        set -gx GEM_PATH $GEM_PATH
        test -n "$GEM_HOME" ;and set GEM_PATH (string match -v "$GEM_HOME" $GEM_PATH)
        test -n "$GEM_ROOT" ;and set GEM_PATH (string match -v "$GEM_ROOT" $GEM_PATH)

        set -e GEM_HOME
        test -z "$GEM_PATH" ;and set -e GEM_PATH
    end

    set -e RUBY_ROOT
    set -e RUBY_ENGINE
    set -e RUBY_VERSION
    set -e RUBYOPT
    set -e GEM_ROOT

    type hash >/dev/null 2>&1 ;and hash -r

    return 0
end

function chruby_use -d 'chruby_use'
    echo $argv | read -l ruby_path opts

    if not test -x "$ruby_path/bin/ruby"
        echo "chruby: $ruby_path/bin/ruby not executable" >&2
        return 1
    end

    test -n "$RUBY_ROOT" ;and chruby_reset

    set -gx RUBY_ROOT "$ruby_path"
    set -gx RUBYOPT "$opts"
    set -gx PATH "$RUBY_ROOT/bin" $PATH

    eval (env RUBYGEMS_GEMDEPS="" RUBYOPT="" "$RUBY_ROOT"/bin/ruby -e '
        puts <<-EOS
          set -gx RUBY_ENGINE #{Object.const_defined?(:RUBY_ENGINE) ? RUBY_ENGINE : "ruby"};
          set -gx RUBY_VERSION #{RUBY_VERSION};
        EOS
        begin
          require "rubygems"
          puts "set -gx GEM_ROOT #{Gem.default_dir.inspect};"
        rescue LoadError
        end
    ')

    test -n "$GEM_ROOT" -a -d "$GEM_ROOT/bin" ;and set -gx PATH "$GEM_ROOT/bin" $PATH

    # Normal User
    if test (id -u) -ne 0
        set -gx GEM_HOME "$HOME/.gem/$RUBY_ENGINE/$RUBY_VERSION"
        test -z "$GEM_PATH" ;and set -g GEM_PATH
        test -n "$GEM_ROOT" ;and set -gx GEM_PATH $GEM_ROOT $GEM_PATH
        set -gx GEM_PATH "$GEM_HOME" $GEM_PATH
        set -gx PATH "$GEM_HOME/bin" $PATH
    end

    type hash >/dev/null 2>&1 ;and hash -r

    return 0
end

function chruby -d 'chruby'
    if test (count $argv) -eq 0
        for ruby_path in $RUBIES
            if test "$ruby_path" = "$RUBY_ROOT"
                echo -n ' * '
            else
                echo -n '   '
            end
            echo (string split -m 1 -r -- / $ruby_path)[-1] $RUBYOPT
        end
        return 0
    end

    switch $argv[1]
    case '-h' '--help'
        echo 'usage: chruby [RUBY|VERSION|system] [RUBYOPT...]'
    case '-v' '--version' '-V'
        echo "chruby: $CHRUBY_VERSION"
    case 'system'
        chruby_reset
    case '*'
        echo $argv | read -l ruby_version opts

        set -l match ''

        for ruby_path in $RUBIES
            switch (string split -m 1 -r -- / $ruby_path)[-1]
            case "*$ruby_version*"
                set match "$ruby_path"
            end
        end

        if test -z "$match"
            echo "chruby: unknown Ruby: $ruby_version" >&2
            return 1
        end

        chruby_use "$match" "$opts"
    end
end
