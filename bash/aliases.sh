alias ls='ls --color=auto'

alias pacrepo='sudo reflector -l 20 -f 10 --save /etc/pacman.d/mirrorlist'
alias journalctl='sudo journalctl'
alias pacu='sudo pacman -Syu --noconfirm'
alias auru='yaourt -Syua --noconfirm'
alias systemctl='sudo systemctl'
alias se='ls /usr/bin | grep'

alias fuck='COMMAND=$(history -p \!\!); echo sudo $COMMAND; sudo $COMMAND'


# Use xdg-open in a subshell, derived output and detached
open() {
    (nohup xdg-open "$1" >/dev/null 2>&1 &)
}
