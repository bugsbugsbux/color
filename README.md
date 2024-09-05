See: ./LICENSE

Examples:

```bash
source ./colors.sh

# colors from your colorscheme
echo -e "$(
    color bold red bg-cyan
)foo$(
    color reset-bold reset-bg
)bar$(
    color reset)"

# rgb colors in hex notation
R=$(color bg-rgb-ff0000 black )
G=$(color bg-rgb-00ff00 black )
B=$(color bg-rgb-0000ff white )
X=$(color reset )
echo -e "${R}R${G}G${B}B$X colors"
```

For more features see `color --help` or the bash source code.
