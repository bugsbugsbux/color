#!/usr/bin/env bash

# takes length as argument
length=${1:-50}

up=({0..255})
down=({255..0})
updown=({0..255} {255..0})
downup=({255..0} {0..255})

echo Truecolor supported if this shows as gradiant:
for ((pos=0; pos<length; pos++)); do

    i=$(( 255 * pos / (length%256)))

    r="${downup[i*2]}"
    g="${down[i]}"
    b="${updown[i*2]}"

    # print piece of rainbow
    printf '\e[48;2;%s;%s;%sm ' "$r" "$g" "$b"
done

# reset colors
echo -e '\e[0m'
