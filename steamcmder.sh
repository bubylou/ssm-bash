#!/bin/bash

username="anonymous"
password=""
rootdir="$(cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd )"
gamedir="$rootdir/games"
backupdir="$rootdir/backup"
steamcmd="$rootdir/steamcmd.sh"

appid_check() {
    number="^[0-9]+([.][0-9]+)?$"

    if ! [[ $1 =~ $number ]]; then
        echo "$1 - Invalid App ID"
        exit
    fi
}

argument_check() {
    if [ -z "$1" ]; then
        echo "You must specify at least one App ID"
        exit
    fi
}

do_all() {
    for appid in $(basename "$(ls $gamedir)"); do
        $1 $appid
    done
}

game_backup() {
    appid_check $1
    mkdir -p "$backupdir/$1"
    tar cvJf "$backupdir/$1/$(date +%Y-%m-%d-%H%M%S).tar.xz" \
        --exclude "$backupdir" -C "$gamedir" $1
}

game_remove() {
    appid_check $1
    rm -rv "$gamedir/$1"
}

game_restore() {
    appid_check $1
    tar vxf "$backupdir/$1/$(ls -t "$backupdir/$1/" | head -1)" -C "$gamedir"
}

game_update() {
    steamcmd_check
    appid_check $1
    mkdir -p "$gamedir/$1"
    bash $steamcmd +login "$username" "$password" +force_install_dir "$gamedir/$1" \
        +app_update "$1" +quit

}

game_validate() {
    steamcmd_check
    appid_check $1
    bash $steamcmd +login "$username" "$password" +force_install_dir "$gamedir/$1" \
        +app_update "$1" -validate +quit
}

steamcmd_check() {
    if ! [ -e "$steamcmd" ]; then
        steamcmd_install
    fi
}

steamcmd_install() {
    wget -N http://media.steampowered.com/installer/steamcmd_linux.tar.gz
    tar xvzf steamcmd_linux.tar.gz -C "$rootdir"
}

steamcmd_setup() {
    if [ -e "$steamcmd" ]; then
        echo "SteamCMD is already installed. Would you like to reinstall it? (y/n)"
        while true; do
            read answer
            case "$answer" in
                Y|y)
                    steamcmd_install
                    ;;
                N|n)
                    exit
                    ;;
                *)
                    echo "Invalid answer. Try again."
            esac
        done
    else
        steamcmd_install
    fi
}

case "$1" in
    backup)
        argument_check $2
        for appid in "${@:2}"; do
            game_backup $appid
        done
        ;;
    backup-all)
        do_all game_backup
        ;;
    games)
        for appid in $(ls $gamedir); do
            appid_check $appid
            echo "$appid - Installed"
        done
        ;;
    remove)
        argument_check $2
        for appid in "${@:2}"; do
            game_remove $appid
        done
        ;;
    remove-all)
        do_all game_remove
        ;;
    restore)
        argument_check $2
        for appid in "${@:2}"; do
            game_restore $appid
        done
        ;;
    restore-all)
        do_all game_restore
        ;;
    setup)
        steamcmd_setup
        ;;
    update)
        argument_check $2
        for appid in "${@:2}"; do
            game_update $appid
        done
        ;;
    update-all)
        do_all game_update
        ;;
    validate)
        argument_check $2
        for appid in "${@:2}"; do
            game_validate $appid
        done
        ;;
    validate-all)
        do_all game_validate
        ;;
    *)
        echo "\"$1\" is not a valid command"
esac
