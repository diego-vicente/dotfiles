alias ls='ls --color=auto'
alias pacrepo='sudo reflector -l 20 -f 10 --save /etc/pacman.d/mirrorlist'
alias pacman='sudo pacman'
alias journalctl='sudo journalctl'
alias pacu='sudo pacman -Syu --noconfirm'
alias auru='yaourt -Syua --noconfirm'
alias se='ls /usr/bin | grep'

export QT_STYLE_OVERRIDE=gtk
export QT_SELECT=qt5

if [[ $LANG = '' ]]; then
	export LANG=en_US.UTF-8
fi

# Custom
alias ls-services="systemctl --type=service --no-pager"
alias wifi-menu='sudo wifi-menu -o'
alias update-grub='sudo grub-mkconfig -o /boot/grub/grub.cfg'
alias e='emacsclient -c'
alias yt_pip="mpv --really-quiet --volume=50 --autofit=30% --geometry=-10-15 --ytdl --ytdl-format='mp4[height<=?720]' -ytdl-raw-options=playlist-start=1"
alias fuck='COMMAND=$(history -p \!\!); echo sudo $COMMAND; sudo $COMMAND'

# Use xdg-open in a subshell, derived output and detached
open() {
    (nohup xdg-open "$1" >/dev/null 2>&1 &)
}
