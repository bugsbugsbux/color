#see: ./LICENSE

#TODO: check on change: if number and description in $HELPTEXT match
ASSERTION_ERR=10 # bug in the program; not a user error
NOT_IMPLEMENTED_ERR=20 # given command or option is not implemented yet
ARG_ERR=30 # generic error due to the given (or missing) arguments
UNKNOWN_ARG_ERR=31 # a given argument is invalid: it is not known
COLOR_ERR=32 # given color does not follow expected format
OPT_COMBI_ERR=40 # given options cannot be used in same invocation
CMD_COMBI_ERR=50 # given commands cannot be used in same invocation
MOD_SET_AND_RESET_ERR=51 # must not set and reset same modifier in same invocation
COLOR_SET_AND_RESET_ERR=52 # must not set and reset a fg or bg color in same invocation
ONLY_RESET_ALL_ALLOWED_ERR=53 # only commands reset or reset-all (once) allowed

HELPTEXT='USAGE: color [options] [commands]

Options:
    -h | --help     print this help text and exit
    -p | --prompt   appends "\]" (useful in bash prompts)
    -n | --newline  prints the escape sequence followed by a newline

    Only one of the following options may be used, if none is used
    the escape sequence starts with "\e[":
        -E              starts the escape sequence with "\E["
        --hex           starts the escape sequence with "\x1b["
        --oct           starts the escape sequence with "\033["
        --unicode       starts the escape sequence with "\x001b["

Commands:
    Foreground colors are set with one of the following commands
        red
        green
        blue
        yellow
        magenta
        cyan
        white
        black

        or one of the above commands prepended with "hi-" (stands for
        high-intensity) to get a bright version of the color,

        or an 8bit color code which is prefixed with "8bit-" or "256-",

        or an 24bit color as a triplet of 3 numbers in the range
        [0,255] separated with arbitrary symbols and prefixed with
        "24bit-" or "tc-" (stands for true color),

        or an 24bit color as RGB hex number triplet separated with
        arbitrary symbols and prefixed with "rgb-" or "hex-".

    Background colors are simply foreground colors prefixed with "bg-".

    The following modifier commands are available:
        bold strong fat
        dim dimmed faint
        italic cursive
        under underline underlined
        blink blinking
        invert inverted inverse inversed reverse reversed
        hide hidden invisible
        strike strikethrough struck

    To undo modifiers prefix them with "reset-".

    To reset fg- or bg-colors to their default, use
        reset-fg
        reset-bg
    or
        fg-default
        bg-default

    To undo all modifiers and restore the default colors at once, use
        reset
    or
        reset-all

Error codes:
    This does not output anything on error. Check the error code:
        10  bug in the program; not a user error
        20  given command or option is not implemented yet
        30  generic error due to the given (or missing) arguments
        31  a given argument is invalid: it is not known
        32  given color does not follow expected format
        40  given options cannot be used in same invocation
        50  given commands cannot be used in same invocation
        51  must not set and reset same modifier in same invocation
        52  must not set and reset a fg or bg color in same invocation
        53  only commands reset or reset-all (once) allowed
'

_mod_set() {
    if $only_options; then return $ONLY_RESET_ALL_ALLOWED_ERR; fi

    local -n var="$1"
    local code="$2"
    if [[ -z "$var" ]]; then
        var=true
        modifiers="${modifiers:+$modifiers;}$code"
    elif ! $var; then
        return $MOD_SET_AND_RESET_ERR
    fi
}

_mod_reset() {
    if $only_options; then return $ONLY_RESET_ALL_ALLOWED_ERR; fi

    local -n var="$1"
    local code="$2"
    if [[ -z "$var" ]]; then
        var=false
        modifiers="${modifiers:+$modifiers;}$code"
    elif $var; then
        return $MOD_SET_AND_RESET_ERR
    fi
}

_set_color() {
    if [[ fg != "$1" && bg != "$1" ]]; then return $ASSERTION_ERR; fi
    if $only_options; then return $ONLY_RESET_ALL_ALLOWED_ERR; fi

    local -n var="$1"
    local code="$2"
    if [[ -n "$var" ]]; then return $CMD_COMBI_ERR; fi
    var="$code"
}

_set_8bit_color() {
    if [[ fg != "$1" && bg != "$1" ]]; then return $ASSERTION_ERR; fi
    local color="${arg#*-}"
    if [[ bg == "$1" ]]; then color="${color#*-}"; fi
    if [[ "$color" == $INT ]] && ((color >= 0 && color <= 255)); then
        if [[ fg == "$1" ]];
        then _set_color fg "38;5;$color" || return $?
        else _set_color bg "48;5;$color" || return $?
        fi
    else return $COLOR_ERR
    fi
}

_set_24bit_color() {
    if [[ fg != "$1" && bg != "$1" ]]; then return $ASSERTION_ERR; fi
    local colors="${arg#*-}"
    if [[ bg == "$1" ]]; then colors="${colors#*-}"; fi
    colors="${colors//[^0-9]/;}"
    if [[ "$colors" == $INT\;$INT\;$INT ]] && ((
        "${colors//;/"<=255 && "}<=255" &&
        "${colors//;/">=0 && "}>=0"
    )) then
        if [[ fg == "$1" ]];
        then _set_color fg "38;2;$colors" || return $?
        else _set_color bg "48;2;$colors" || return $?
        fi
    else return $COLOR_ERR
    fi
}

_set_rgb_hex_color() {
    if [[ fg != "$1" && bg != "$1" ]]; then return $ASSERTION_ERR; fi
    local -i r g b
    local colors="${arg#*-}"
    if [[ bg == "$1" ]]; then colors="${colors#*-}"; fi
    if [[ 6 == "${#colors}" && "$colors" == +([0-9a-fA-F]) ]]; then
        r="0x${colors:0:2}"
        g="0x${colors:2:2}"
        b="0x${colors:4:2}"
        if [[ fg == "$1" ]];
        then _set_color fg "38;2;$r;$g;$b" || return $?
        else _set_color bg "48;2;$r;$g;$b" || return $?
        fi
    else return $COLOR_ERR
    fi
}

_set_prefix() {
    if $no_prefix_options; then return $OPT_COMBI_ERR; fi
    no_prefix_options=true
    prefix="$1"
}

color() {

    # pattern for an integer: leading zeros not allowed unless all zeros
    # why? number staring with zero is interpreted as octal number
    local INT='@(+(0)|+([1-9])*([0-9]))'

    local fg bg modifiers
    local prefix='\e['
    local suffix='m'

    local newline=false
    local no_prefix_options=false
    local only_options=false

    # modifiers: null if not specified; true if set; false if reset
    local bold=
    local dim=
    local italic=
    local under=
    local blink=
    local invert=
    local hide=
    local strike=

    for arg; do
        [[ -n "$arg" ]] || return $ASSERTION_ERR
        case "$arg" in

            '-h'|'--help')
                echo "$HELPTEXT"
                return
            ;;

            '-n'|'--newline') newline=true ;;

            '-p'|'--prompt') suffix='m\]' ;;

            '-E') _set_prefix '\E[' || return $? ;;
            '--hex') _set_prefix '\x1b[' || return $? ;;
            '--oct') _set_prefix '\033[' || return $? ;;
            '--unicode') _set_prefix '\x001b[' || return $? ;;

            reset|reset-all) # \e[0m
                [[ -n "$fg$bg$modifiers" ]] && return $ONLY_RESET_ALL_ALLOWED_ERR
                # only add this modifier once:
                if ! $only_options; then
                    only_options=true # not combinable with other commands
                    modifiers="${modifiers:+$modifiers;}0"
                fi
            ;;

            bold|strong|fat) _mod_set bold 1 || return $? ;; # \e[1m
            reset-bold|reset-strong|reset-fat) _mod_reset bold 22 || return $? ;; # \e[22m # same as reset-dim

            dim|dimmed|faint) _mod_set dim 2 || return $? ;; # \e[2m
            reset-dim|reset-dimmed|reset-faint) _mod_reset dim 22 || return $? ;; # \e[22m # same as reset-bold

            italic|cursive) _mod_set italic 3 || return $? ;; # \e[3m
            reset-italic|reset-cursive) _mod_reset italic 23 || return $? ;; # \e[23m

            under|underline|underlined) _mod_set under 4 || return $? ;; # \e[4m
            reset-under|reset-underline|reset-underlined) _mod_reset under 24 || return $? ;; # \e[24m

            blink|blinking) _mod_set blink 5 || return $? ;; # \e[5m
            reset-blink|reset-blinking) _mod_reset blink 25 || return $? ;; # \e[25m

            invert|inverted|inverse|inversed|reverse|reversed) _mod_set invert 7 || return $? ;; # \e[7m
            reset-invert|reset-inverted|reset-inverse|reset-inversed|reset-reverse|reset-reversed) # \e[27m
                _mod_reset invert 27 || return $?
            ;;

            hide|hidden|invisible) _mod_set hide 8 || return $? ;; # \e[8m
            reset-hide|reset-hidden|reset-invisible) _mod_reset hide 28 || return $? ;; # \e[28m

            strike|struck|strikethrough) _mod_set strike 9 || return $? ;; # \e[9m
            reset-strike|reset-struck|reset-strikethrough) _mod_reset strike 29 || return $? ;; # \e[29m

            # The following option does not have a variant only named "default" because this sounds like
            # resetting everything to default, but it only resets the foreground color!
            reset-fg|fg-default) # \e[39m
                if $only_options; then return $ONLY_RESET_ALL_ALLOWED_ERR; fi
                if [[ -n "$fg" ]]; then return $COLOR_SET_AND_RESET_ERR; fi
                fg=39
            ;;
            reset-bg|bg-default) # \e[49m
                if $only_options; then return $ONLY_RESET_ALL_ALLOWED_ERR; fi
                if [[ -n "$bg" ]]; then return $COLOR_SET_AND_RESET_ERR; fi
                bg=49
            ;;

            black) _set_color fg 30 || return $? ;; # \e[30m
            hi-black) _set_color fg 90 || return $? ;; # \e[90m
            bg-black) _set_color bg 40 || return $? ;; # \e[40m
            bg-hi-black) _set_color bg 100 || return $? ;; # \e[100m

            white) _set_color fg 37 || return $? ;; # \e[37m
            hi-white) _set_color fg 97 || return $? ;; # \e[97m
            bg-white) _set_color bg 47 || return $? ;; # \e[47m
            bg-hi-white) _set_color bg 107 || return $? ;; # \e[107m

            red) _set_color fg 31 || return $? ;; # \e[31m
            hi-red) _set_color fg 91 || return $? ;; # \e[91m
            bg-red) _set_color bg 41 || return $? ;; # \e[41m
            bg-hi-red) _set_color bg 101 || return $? ;; # \e[101m

            green) _set_color fg 32 || return $? ;; # \e[32m
            hi-green) _set_color fg 92 || return $? ;; # \e[92m
            bg-green) _set_color bg 42 || return $? ;; # \e[42m
            bg-hi-green) _set_color bg 102 || return $? ;; # \e[102m

            blue) _set_color fg 34 || return $? ;; # \e[34m
            hi-blue) _set_color fg 94 || return $? ;; # \e[94m
            bg-blue) _set_color bg 44 || return $? ;; # \e[44m
            bg-hi-blue) _set_color bg 104 || return $? ;; # \e[104m

            yellow) _set_color fg 33 || return $? ;; # \e[33m
            hi-yellow) _set_color fg 93 || return $? ;; # \e[93m
            bg-yellow) _set_color bg 43 || return $? ;; # \e[43m
            bg-hi-yellow) _set_color bg 103 || return $? ;; # \e[103m

            magenta) _set_color fg 35 || return $? ;; # \e[35m
            hi-magenta) _set_color fg 95 || return $? ;; # \e[95m
            bg-magenta) _set_color bg 45 || return $? ;; # \e[45m
            bg-hi-magenta) _set_color bg 105 || return $? ;; # \e[105m

            cyan) _set_color fg 36 || return $? ;; # \e[36m
            hi-cyan) _set_color fg 96 || return $? ;; # \e[96m
            bg-cyan) _set_color bg 46 || return $? ;; # \e[46m
            bg-hi-cyan) _set_color bg 106 || return $? ;; # \e[106m

            8bit-*|256-*) _set_8bit_color fg || return $? ;; # \e[38;5;COLORm
            bg-8bit-*|bg-256-*) _set_8bit_color bg || return $? ;; # \e[48;5;COLORm

            # user provides r-g-b decimal number triplet
            tc-*|24bit-*) _set_24bit_color fg || return $? ;; #\e[38;2;R;G;Bm
            bg-tc-*|bg-24bit-*) _set_24bit_color bg || return $? ;; #\e[48;2;R;G;Bm

            # user provides hex number
            rgb-*|hex-*) _set_rgb_hex_color fg || return $? ;; #\e[38;2;R;G;Bm
            bg-rgb-*|bg-hex-*) _set_rgb_hex_color bg || return $? ;; #\e[48;2;R;G;Bm

            *) return $UNKNOWN_ARG_ERR
        esac
    done

    # no commands given
    [[ -z "$fg$bg$modifiers" ]] && return $ARG_ERR

    # join fg bg and modifiers
    local merged=""
    for v in fg bg modifiers; do
        # since value might be empty, should not always prepend ;
        if (( "${#merged}" > 0 )); then
            merged+="${!v:+;${!v}}"
        else
            merged=${!v}
        fi
    done

    # output escape sequence
    local result="${prefix}${merged}${suffix}"
    if $newline
    then echo "$result"
    else echo -n "$result"
    fi

}
