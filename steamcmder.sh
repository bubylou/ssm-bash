#!/bin/bash

username="anonymous"
password=""
number="^[0-9]+([.][0-9]+)?$"
gamedir="games"
backupdir="backup"

backup() {
    mkdir -p "$backupdir/$1"
    tar cvzf "$backupdir/$1/$(date +%Y-%m-%d-%H%M%S).tar.gz" \
        --exclude "$backupdir" -C "$gamedir" $1 
}

do_all() {
    for i in $gamedir/*; do
        $1 $(basename $i)
    done
}

game_install() {
    mkdir -p "$gamedir/$1"
    ./steamcmd.sh +login "$username" "$password" +force_install_dir "$gamedir/$1" \
        +app_update "$1" +quit

}

game_validate() {
    ./steamcmd.sh +login "$username" "$password" +force_install_dir "$gamedir/$1" \
        +app_update "$1" -validate +quit
}

steamcmd_install() {
    if [ -e "steamcmd_linux.tar.gz" ]; then
        rm steamcmd_linux.tar.gz
    fi

    wget http://media.steampowered.com/installer/steamcmd_linux.tar.gz
    tar xvzf steamcmd_linux.tar.gz
}

case "$1" in
    backup)
        for i in "$@"; do
            if [[ $i =~ $number ]]; then
                backup $i
            fi
        done
        ;;
    backup-all)
        do_all backup
        ;;
    install)
        for i in "$@"; do
            if [[ $i =~ $number ]]; then
                game_install $i
            fi
        done
        ;;
    setup)
        steamcmd_install
        ;;
    update)
        for i in "$@"; do
            if [[ $i =~ $number ]]; then
                game_install $i
            fi
        done
        ;;
    update-all)
        do_all game_install
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
