#!/usr/bin/env bash

status=0

error () {
    echo "$@" >&2
    status=1
}

# takes an expected value and commands to pass to `color`, whose
# results must match expected value
assert_results () {
    local expected="$1"
    shift
    local index=1
    for cmd; do ((index++))
        local result
        result="$(color $cmd)" || {
            error "AssertionError: expected '$expected' but item $index failed with code $?"
            continue
        }
        if [[ "$result" != "$expected" ]]; then
            error "AssertionError: expected '$expected' but item $index is '$result'"
        fi
    done
}

# takes an expected theme color (0-7) and commands to pass to `color`, whose
# results must belong to the given theme color
assert_theme_color () {
    if [[ "$1" != [0-7] ]]; then
        echo Broken test! Aborting...
        exit 1
    fi

    local color="$1"
    shift
    local index=1
    for cmd; do ((index++))
        local result
        result="$(color $cmd)" || {
            error "AssertionError: item $index failed with code $?"
            continue
        }
        local expected='\e['
        case "$cmd" in
            bg-hi-*)expected+="$((color + 100))m" ;;
            bg-*)   expected+="$((color + 40))m" ;;
            hi-*)   expected+="$((color + 90))m" ;;
            *)      expected+="$((color + 30))m" ;;
        esac
        if [[ "$result" != "$expected" ]]; then
            error "AssertionError: expected '$expected' but item $index is '$result'"
        fi
    done
}


#
# check installation
#
if ! [[ "$(type -t color)" == "file" && -x $(which color) ]]; then
    echo "Not installed correctly!" >&2
    exit 1
fi

#
# check modifiers
#
assert_results '\e[1m' bold strong fat
assert_results '\e[22m' reset-bold reset-strong reset-fat

assert_results '\e[2m' dim dimmed faint
assert_results '\e[22m' reset-dim reset-dimmed reset-faint

assert_results '\e[3m' italic cursive
assert_results '\e[23m' reset-italic reset-cursive

assert_results '\e[4m' under underline underlined
assert_results '\e[24m' reset-under reset-underline reset-underlined

assert_results '\e[5m' blink blinking
assert_results '\e[25m' reset-blink reset-blinking

assert_results '\e[7m' invert inverted inverse inversed reverse reversed
assert_results '\e[27m' reset-invert reset-inverted reset-inverse reset-inversed reset-reverse reset-reversed

assert_results '\e[8m' hide hidden invisible
assert_results '\e[28m' reset-hide reset-hidden reset-invisible

assert_results '\e[9m' strike struck strikethrough
assert_results '\e[29m' reset-strike reset-struck reset-strikethrough

assert_results '\e[39m' reset-fg fg-default
assert_results '\e[49m' reset-bg bg-default

#
# check theme colors
#
assert_theme_color 0 black bg-black hi-black bg-hi-black
assert_theme_color 1 red bg-red hi-red bg-hi-red
assert_theme_color 2 green bg-green hi-green bg-hi-green
assert_theme_color 3 yellow bg-yellow hi-yellow bg-hi-yellow
assert_theme_color 4 blue bg-blue hi-blue bg-hi-blue
assert_theme_color 5 magenta bg-magenta hi-magenta bg-hi-magenta
assert_theme_color 6 cyan bg-cyan hi-cyan bg-hi-cyan
assert_theme_color 7 white bg-white hi-white bg-hi-white

#
# check 8bit colors
#

#
# check 24bit colors
#

#
# check hex colors
#

#
# check reset-all and color- and modifier-combinations
#

#
# check alternative prefixes
#

#
# check suffix and newline
#

exit $status
