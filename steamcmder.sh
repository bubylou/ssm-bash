#!/bin/bash

username="anonymous"
password=""
number="^[0-9]+([.][0-9]+)?$"
rootdir="$(cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd )"
gamedir="$rootdir/games"
backupdir="$rootdir/backup"
steamcmd="$rootdir/steamcmd.sh"

do_all() {
    for i in $gamedir/*; do
        $1 $(basename $i)
    done
}

game_backup() {
    mkdir -p "$backupdir/$1"
    tar cvzf "$backupdir/$1/$(date +%Y-%m-%d-%H%M%S).tar.gz" \
        --exclude "$backupdir" -C "$gamedir" $1
}

game_update() {
    mkdir -p "$gamedir/$1"
    bash $steamcmd +login "$username" "$password" +force_install_dir "$gamedir/$1" \
        +app_update "$1" +quit

}

game_validate() {
    bash $steamcmd +login "$username" "$password" +force_install_dir "$gamedir/$1" \
        +app_update "$1" -validate +quit
}

steamcmd_install() {
    if [ -e "$steamcmd" ]; then
        echo "SteamCMD is already installed. Would you like to reinstall it? (y/n)"

        read answer
        case "$answer" in
            Y|y)
                wget -N http://media.steampowered.com/installer/steamcmd_linux.tar.gz
                tar xvzf steamcmd_linux.tar.gz -C "$rootdir"
                ;;
            N|n)
                exit
                ;;
            *)
                echo "$answer Didn't match anything"
        esac
    fi

}

case "$1" in
    backup)
        for i in "$@"; do
            if [[ $i =~ $number ]]; then
                game_backup $i
            fi
        done
        ;;
    backup-all)
        do_all game_backup
        ;;
    setup)
        steamcmd_install
        ;;
    update)
        for i in "$@"; do
            if [[ $i =~ $number ]]; then
                game_update $i
            fi
        done
        ;;
    update-all)
        do_all game_update
        ;;
    validate)
        for i in "$@"; do
            if [[ $i =~ $number ]]; then
                game_validate $i
            fi
        done
        ;;
    validate-all)
        do_all game_validate
        ;;
    *)
        echo "\"$1\" is not a valid option"
esac
