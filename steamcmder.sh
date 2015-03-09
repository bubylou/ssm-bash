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
        message "Error" "You must specify at least one App Name"
        exit
    fi
}

do_all()
{
    for j in $(ls $gamedir); do
        if [[ "$1" == "game_start" || "$1" == "game_stop" || "$1" == "game_status" ]]; then
            game_config $j
            game_check
            local servers=$(jq ".[$index]" $startcfg | grep '\[' | grep -o '".*"')
            for k in ${servers}; do
                server="$k"
                $1 $k
            done
        else
            game_config $j
            game_check $j
            $1 $j
        fi
    done
}

game_check()
{
    if [ -z "$(ls "$gamedir" | grep "^$name$")" ]; then
        status=2
    elif [ -n "$(screen_check)" ]; then
        status=1
    else
        status=0
    fi
}

game_config()
{
    unset index name appid server
    local length=$(jq ". | length" $startcfg)

    for i in $(seq 0 $length); do
        if [ "$1" == "$(jq -r ".[$i].name" $startcfg)" ]; then
            index=$i
            if [ "null" != "$(jq -r ".[$i].$1" $startcfg)" ]; then
                server=$1
            fi
            break
        elif [ "null" != "$(jq -r ".[$i].$1" $startcfg)" ]; then
            index=$i
            server=$1
            break
        fi
    done

    if [ -n "$index" ]; then
        name=$(jq -r ".[$index].name" $startcfg)
        appid=$(jq -r ".[$index].appid" $startcfg)
    else
        message "Name" "$1"
        message "Error" "Invalid App Name"
        exit
    fi
}

message()
{
    if [ -n "$1" ]; then
        printf '[ '
        printf '%-6s' "$1"
        printf " ]"
        if [ -n "$2" ]; then
            printf " - $2"
        fi
        printf '\n'
    fi
}

info()
{
    if [ -n "$server" ]; then
        message "Name" "$server"
    elif [ -n "$name" ]; then
        message "Name" "$name"
    fi

    if [ -n "$appid" ]; then
        message "App ID" "$appid"
    fi

    if [ $status == 2 ]; then
        message "Status" "Not Installed"
    else
        message "Status" "Installed"
    fi

    if [ $status == 1 ]; then
        message "Status" "Running"
    else
        message "Status" "Not Running"
    fi

    message "$1" "$2"
    message "------"
}

server_check()
{
    if [ -z $server ]; then
        message "Name" "$1"
        message "Error" "Invalid Server Name"
        exit
    fi
}

screen_check()
{
    if [ -z $server ]; then
        session="$appid"
    else
        session="$server"
    fi

    screen -ls | grep '(' | grep -o "$session"
}

steamcmd_check()
{
    if [ ! -e $steamcmd ]; then
        message "Error" "SteamCMD not installed"
        steamcmd_install
    fi
}

game_backup()
{
    if [ $status == 2 ]; then
        info "Error" "App is not installed"
        error+=" $name"
    elif [ $status == 1 ]; then
        info "Error" "Stop server before backup"
        error+=" $name"
    else
        info "Status" "Backing Up"
        mkdir -p "$backupdir/$name"
        tar cvJf "$backupdir/$name/$(date +%Y-%m-%d-%H%M%S).tar.xz" \
            --exclude "$backupdir" -C "$gamedir" $name
    fi
}

game_remove()
{
    if [ $status == 2 ]; then
        info "Error" "App is not installed"
        error+=" $name"
    elif [ $status == 1 ]; then
        info "Error" "Stop server before removing"
        error+=" $name"
    else
        info "Status" "Removing"
        rm -r "$gamedir/$name"
    fi
}

game_restore()
{
    if [ $status == 2 ]; then
        info "Error" "App is not installed"
        error+=" $name"
    elif [ $status == 1 ]; then
        info "Error" "Stop server before restoring"
        error+=" $name"
    else
        info "Status" "Restoring"
        tar vxf "$backupdir/$name/$(ls -t "$backupdir/$name/" | head -1)" \
            -C "$gamedir"
    fi
}

game_start()
{
    server_check $1

    if [ $status == 2 ]; then
        info "Error" "App is not Installed"
        error+=" $name"
    elif [ $status == 1 ]; then
        info "Error" "Server is already running"
        error+=" $server"
    else
        info "Status" "Starting"

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
    server_check $1

    if [ $status == 2 ]; then
        continue
    elif [ $status == 1 ]; then
        info
    else
        info
    fi
}

game_stop()
{
    server_check $1

    if [ $status == 2 ]; then
        info "Error" "App is not Installed"
        error+=" $name"
    elif [ $status == 1 ]; then
        info "Status" "Stopping"
        screen -S "$server-$appid" -X "quit"
    else
        info "Error" "Server is not Running"
        error+=" $server"
    fi
}

game_update()
{
    steamcmd_check

    if [ $status == 2 ]; then
        info "Status" "Installing"
        mkdir -p "$gamedir/$name"
        bash $steamcmd +login "$username" "$password" +force_install_dir \
            "$gamedir/$name" +app_update "$appid" +quit
    elif [ $status == 1 ]; then
        info "Error" "Stop server before updating"
        error+=" $name"
    else
        info "Status" "Updating"
        bash $steamcmd +login "$username" "$password" +force_install_dir \
            "$gamedir/$name" +app_update "$appid" +quit
    fi
}

game_validate()
{
    steamcmd_check

    if [ $status == 2 ]; then
        info "Error" "App is not installed"
        error+=" $name"
    elif [ $status == 1 ]; then
        info "Error" "Stop server before validating"
        error+=" $name"
    else
        info $name "Validating"
        bash $steamcmd +login "$username" "$password" +force_install_dir \
            "$gamedir/$name" +app_update "$appid" -validate +quit
    fi
}
screen_attach()
{
    server_check $1

    if [ $status == 2 ]; then
        info $server "App is not installed"
        error+=" $name"
    elif [ $status == 1 ]; then
        info $server "Attaching"
        screen -r "$server-$appid"
    else
        info $server "Server is not running"
        error+=" $server"
    fi
}

steamcmd_install()
{
    message "Status" "Installing SteamCMD"
    wget -N http://media.steampowered.com/installer/steamcmd_linux.tar.gz
    tar xvf steamcmd_linux.tar.gz -C "$rootdir"
}

steamcmd_setup()
{
    if [ -e "$steamcmd" ]; then
        message "Error" "SteamCMD is already installed"
        message "Status" "Would you like to reinstall it? (y/n)"
        while true; do
            read answer
            case "$answer" in
                Y|y)
                    steamcmd_install
                    break
                    ;;
                N|n)
                    break
                    ;;
                *)
                    message "Error" "Invalid answer. Try again."
            esac
        done
    else
        steamcmd_install
    fi
}

if [ "$(whoami)" == "root" ]; then
    message "Error" "Do not run as root"
    exit
fi

case "$1" in
    backup)
        argument_check $2
        for arg in ${@:2}; do
            game_config $arg
            game_check
            game_backup $arg
        done
        ;;
    backup-all)
        do_all game_backup
        ;;
    console)
        argument_check $2
        game_config $2
        game_check
        screen_attach $2
        ;;
    list)
        for arg in $(ls $gamedir); do
            game_config $arg
            game_check
            info | head -2
            message "------"
        done
        ;;
    remove)
        argument_check $2
        for arg in ${@:2}; do
            game_config $arg
            game_check
            game_remove $arg
        done
        ;;
    remove-all)
        do_all game_remove
        ;;
    restart)
        game_config $1

        for arg in ${@:2}; do
            game_config $arg
            game_check
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
            game_config $arg
            game_check
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
            game_config $arg
            game_check
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
                game_config $arg
                game_check
                game_status $arg
            done
        fi
        ;;
    stop)
        argument_check $2
        for arg in ${@:2}; do
            game_config $arg
            game_check
            game_stop $arg
        done
        ;;
    stop-all)
        do_all game_stop
        ;;
    update)
        argument_check $2
        for arg in ${@:2}; do
            game_config $arg
            game_check
            game_update $arg
        done
        ;;
    update-all)
        do_all game_update
        ;;
    validate)
        argument_check $2
        for arg in ${@:2}; do
            game_config $arg
            game_check
            game_validate $arg
        done
        ;;
    validate-all)
        do_all game_validate
        ;;
    *)
        message "Error" "Invalid Command"
esac

if [ -n "$error" ]; then
    echo "[ Errors ] -$error"
else
    message "Done"
fi
