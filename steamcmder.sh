#!/bin/bash

username="anonymous"
password=""
rootdir="$(cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd )"
gamedir="$rootdir/games"
backupdir="$rootdir/backup"
steamcmd="$rootdir/steamcmd.sh"
startcfg="$rootdir/startcfg.json"

argument_check()
{
    if [ -z "$1" ]; then
        echo "You must specify at least one App Name"
        exit
    fi
}

do_all()
{
    if [[ "$1" == "game_start" || "$1" == "game_stop" || "$1" == "game_status" ]]; then
        local servers=$(jq ".[]" $startcfg | grep '\[' | cut -d '"' -f 2)
        for i in ${servers}; do
            $1 $i
        done
    else
        for j in $(ls $gamedir); do
            $1 $j
        done
    fi
}

game_config()
{
    unset index name appid server
    local length=$(jq ". | length" $startcfg)

    for i in $(seq 0 $length); do
        if [ "$1" == "$(jq -r ".[$i].name" $startcfg)" ]; then
            index=$i
            if [ "null" != "$(jq -r ".[$i].$1[0]" $startcfg)" ]; then
                server=$1
            fi
            break
        elif [ "null" != "$(jq -r ".[$i].$1[0]" $startcfg)" ]; then
            index=$i
            server=$1
            break
        fi
    done

    if [ -n "$index" ]; then
        name=$(jq -r ".[$index].name" $startcfg)
        appid=$(jq -r ".[$index].appid" $startcfg)
    else
        message $1 "Invalid App Name"
        exit
    fi
}

message()
{
    printf "[ "
    printf '%-6s' "$1"
    printf " ] - $2"
    printf '\n'
}

server_check()
{
    if [ -z $server ]; then
        message $1 "Invalid Server Name"
        exit
    fi
}

screen_check()
{
    ls -aR /var/run/screen | cut -d "." -f 2 | grep "$1$"
}

steamcmd_check()
{
    if [ ! -e $steamcmd ]; then
        steamcmd_install
    fi
}

game_backup()
{
    game_config $1

    if [ -z "$(ls "$gamedir" | grep "^$name$")" ]; then
        message $name "Not Installed"
        error+=" $name"
    elif [ -n  "$(screen_check "$appid")" ]; then
        message $name "Running"
        error+=" $name"
    else
        message $name "Backing Up"
        mkdir -p "$backupdir/$name"
        tar cvJf "$backupdir/$name/$(date +%Y-%m-%d-%H%M%S).tar.xz" \
            --exclude "$backupdir" -C "$gamedir" $name
    fi
}

game_remove()
{
    game_config $1

    if [ -z "$(ls "$gamedir" | grep "^$name$")" ]; then
        message $name "Not Installed"
        error+=" $name"
    elif [ -n  "$(screen_check "$appid")" ]; then
        message $name "Running"
        error+=" $name"
    else
        message $name "Removing"
        rm -r "$gamedir/$name"
    fi
}

game_restore()
{
    game_config $1

    if [ -z "$(ls "$gamedir" | grep "^$name$")" ]; then
        message $name "Not Installed"
        error+=" $name"
    elif [ -n  "$(screen_check "$appid")" ]; then
        message $name "Running"
        error+=" $name"
    else
        message $name "Restoring"
        tar vxf "$backupdir/$name/$(ls -t "$backupdir/$name/" | head -1)" \
            -C "$gamedir"
    fi
}

game_start()
{
    game_config $1
    server_check $1

    if [ -z "$(ls "$gamedir" | grep "^$name$")" ]; then
        message $server "Not Installed"
        error+=" $server"
    elif [ -n  "$(screen_check "$server-$appid")" ]; then
        message $server "Already Running"
        error+=" $server"
    else
        message $server "Starting"

        local exec=$(jq -r ".[$index].exec" $startcfg)
        local length=$(jq ".[$index].$server | length" $startcfg)

        for i in $(seq 0 $length); do
            local tmp=$(jq -r ".[$index].$server[$i]" $startcfg)
            gameoptions+=" $tmp"
        done

        screen -dmS "$server-$appid" sh "$gamedir/$name/$exec" $gameoptions
    fi
}

game_status()
{
    game_config $1
    server_check $1

    if [ -n  "$(screen_check "$server-$appid")" ]; then
        message $server "Running"
    else
        message $server "Not Running"
    fi
}

game_stop()
{
    game_config $1
    server_check $1

    if [ -z "$(ls "$gamedir" | grep "^$name$")" ]; then
        message $server "Not Installed"
        error+=" $1"
    elif [ -n  "$(screen_check "$server-$appid")" ]; then
        message $server "Stopping"
        screen -S "$server-$appid" -X "quit"
    else
        message $server "Not Running"
        error+=" $1"
    fi
}

game_update()
{
    steamcmd_check
    game_config $1

    if [ -z "$(ls "$gamedir" | grep "^$name$")" ]; then
        message $name "Installing"
        mkdir -p "$gamedir/$name"
        bash $steamcmd +login "$username" "$password" +force_install_dir \
            "$gamedir/$name" +app_update "$appid" +quit
    elif [ -n  "$(screen_check "$appid")" ]; then
        message $name "Running"
        error+=" $server"
    else
        message $name "Updating"
        bash $steamcmd +login "$username" "$password" +force_install_dir \
            "$gamedir/$name" +app_update "$appid" +quit
    fi
}

game_validate()
{
    steamcmd_check
    game_config $1

    if [ -z "$(ls "$gamedir" | grep "^$name$")" ]; then
        message $name "Not Installed"
        error+=" $name"
    elif [ -n  "$(screen_check "$appid")" ]; then
        message $name "Running"
        error+=" $server"
    else
        message $name "Validating"
        bash $steamcmd +login "$username" "$password" +force_install_dir \
            "$gamedir/$name" +app_update "$appid" -validate +quit
    fi
}
screen_attach()
{
    game_config $1
    server_check $1

    if [ -z "$(ls "$gamedir" | grep "^$name$")" ]; then
        message $server "Not Installed"
        error+=" $name"
    elif [ -n  "$(screen_check "$server-$appid")" ]; then
        message $server "Attaching"
        screen -r "$server-$appid"
    else
        message $server "Not Running"
        error+=" $server"
    fi
}

steamcmd_install()
{
    wget -N http://media.steampowered.com/installer/steamcmd_linux.tar.gz
    tar xvf steamcmd_linux.tar.gz -C "$rootdir"
}

steamcmd_setup()
{
    if [ -e "$steamcmd" ]; then
        echo "SteamCMD is already installed"
        echo "Would you like to reinstall it? (y/n)"
        while true; do
            read answer
            case "$answer" in
                Y|y)
                    steamcmd_install
                    break
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

if [ "$(whoami)" == "root" ]; then
    message "Errors" "Do not run as root"
    exit
fi

case "$1" in
    backup)
        argument_check $2
        for arg in ${@:2}; do
            game_backup $arg
        done
        ;;
    backup-all)
        do_all game_backup
        ;;
    console)
        argument_check $2
        screen_attach $2
        ;;
    list)
        for arg in $(ls $gamedir); do
            message $arg "Installed"
        done
        ;;
    remove)
        argument_check $2
        for arg in ${@:2}; do
            game_remove $arg
        done
        ;;
    remove-all)
        do_all game_remove
        ;;
    restart)
        argument_check $2
        for arg in ${@:2}; do
            game_stop $arg
            game_start $arg
        done
        ;;
    restart-all)
        do_all game_stop
        do_all game_start
        ;;
    restore)
        argument_check $2
        for arg in ${@:2}; do
            game_restore $arg
        done
        ;;
    restore-all)
        do_all game_restore
        ;;
    setup)
        steamcmd_setup
        ;;
    start)
        argument_check $2
        for arg in ${@:2}; do
            game_start $arg
        done
        ;;
    start-all)
        do_all game_start
        ;;
    status)
        if [ -z "$2" ]; then
            do_all game_status
        else
            for arg in ${@:2}; do
                game_status $arg
            done
        fi
        ;;
    stop)
        argument_check $2
        for arg in ${@:2}; do
            game_stop $arg
        done
        ;;
    stop-all)
        do_all game_stop
        ;;
    update)
        argument_check $2
        for arg in ${@:2}; do
            game_update $arg
        done
        ;;
    update-all)
        do_all game_update
        ;;
    validate)
        argument_check $2
        for arg in ${@:2}; do
            game_validate $arg
        done
        ;;
    validate-all)
        do_all game_validate
        ;;
    *)
        echo "\"$1\" is not a valid command"
esac

if [ -n "$error" ]; then
    echo "[ Errors ] -$error"
else
    echo "[ Done   ]"
fi
