#!/bin/bash

username="anonymous"
password=""
rootdir="$( cd "$( dirname ${BASH_SOURCE[0]} )" && pwd )"
gamedir="$rootdir/games"
backupdir="$rootdir/backup"
steamcmd="$rootdir/steamcmd.sh"
startcfg="$rootdir/startcfg.json"

# Checking / Utility Functions

argument_check()
{
    if [ -z "$1" ]; then
        message "Error" "You must specify at least one App Name"
        exit
    fi
}

do_all()
{
    for i in $( ls $gamedir ); do
        game_check $i
        servers=$( jq ".[$index]" $startcfg | grep '\[' | awk -F\" '{print $2}' )
        for server in $servers; do
            for k in ${@}; do
                $k $j
                message "------"
            done
        done
    done
}

game_check()
{
    unset index name appid server
    number="^[0-9]+([.][0-9]+)?$"
    local length=$( jq ". | length - 1" $startcfg )

    for i in $( seq 0 $length ); do
        name=$( jq -r ".[$i].name" $startcfg )
        appid=$( jq -r ".[$i].appid" $startcfg )

        if [[ $1 =~ $number ]]; then
            if [ "$1" == "$appid" ]; then
                index=$i
                break
            fi
        else
            if [ "$1" == "$name" ]; then
                index=$i
                if [ "null" != "$( jq -r ".[$i].$1" $startcfg )" ]; then
                    server=$1
                fi
                break
            elif [ "null" != "$( jq -r ".[$i].$1" $startcfg )" ]; then
                index=$i
                server=$1
                break
            fi
        fi
    done

    if [ -z "$index" ]; then
        message "Error" "Invalid App Name"
        exit
    fi

    if [ ! -d "$gamedir/$name" ]; then
        status=2
    elif [ -n "$( session_check )" ]; then
        status=1
    else
        status=0
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
}

message()
{
    printf '[ '
    printf '%-6s' "$1"
    printf " ]"
    if [ -n "$2" ]; then
        printf " - $2"
    fi
    printf '\n'
}

server_check()
{
    if [ -z "$server" ]; then
        message "Error" "Invalid Server Name"
        exit
    fi
}

session_check()
{
    if [ -z "$server" ]; then
        local session="$appid"
    else
        local session="$server-$appid"
    fi

    screen -ls | grep '(' | grep "$session" | cut -d '.' -f 2 | cut -f 1
}

steamcmd_check()
{
    if [ ! -e $steamcmd ]; then
        message "Error" "SteamCMD not installed"
        steamcmd_install
    fi
}

# Normal Functions

game_backup()
{
    message "Status" "Backing Up"
    mkdir -p "$backupdir/$name"
    tar cvJf "$backupdir/$name/$( date +%Y-%m-%d-%H%M%S ).tar.xz" \
        --exclude "$backupdir" -C "$gamedir" $name
}

game_remove()
{
    message "Status" "Removing"
    rm -r "$gamedir/$name"
}

game_restore()
{
    message "Status" "Restoring"
    tar vxf "$backupdir/$name/$( ls -t "$backupdir/$name/" | head -1 )" \
        -C "$gamedir"
}

game_update()
{
    message "Status" "$1"
    bash $steamcmd +login "$username" "$password" +force_install_dir \
        "$gamedir/$name" +app_update "$appid" +quit
}

game_validate()
{
    message "Status" "Validating"
    bash $steamcmd +login "$username" "$password" +force_install_dir \
        "$gamedir/$name" +app_update "$appid" -validate +quit
}

server_start()
{
    local exec=$( jq -r ".[$index].exec" $startcfg )
    local length=$( jq ".[$index].$server | length - 1" $startcfg )

    for i in $( seq 0 $length ); do
        local tmp=$( jq -r ".[$index].$server[$i]" $startcfg )
        gameoptions+=" $tmp"
    done

    message "Status" "Starting"
    screen -dmS "$server-$appid" sh "$gamedir/$name/$exec" $gameoptions
}

server_stop()
{
    message "Status" "Stopping"
    screen -S "$server-$appid" -X "quit"

    while [ -n "$( session_check )" ]; do
        message "Status" "Stopping"
        sleep 2
    done

    message "Status" "Stopped"
}

steamcmd_install()
{
    message "Status" "Installing SteamCMD"
    wget -N http://media.steampowered.com/installer/steamcmd_linux.tar.gz
    tar xvf steamcmd_linux.tar.gz -C "$rootdir"
}

# Command Functions

command_backup()
{
    info

    if [ $status == 2 ]; then
        message "Error" "App is not installed"
        error+="$name "
    elif [ $status == 1 ]; then
        message "Error" "Stop server before backup"
        error+="$name "
    else
        game_backup
    fi
}

command_console()
{
    info

    if [ $status == 2 ]; then
        message "Error" "App is not installed"
        error+="$name "
    elif [ $status == 1 ]; then
        message "Status" "Attaching"
        screen -r "$server-$appid"
    else
        message "Error" "Server is not running"
        error+="$server "
    fi
}

command_install()
{
    steamcmd_check
    info

    if [ $status == 2 ]; then
        mkdir -p "$gamedir"
        game_update "Installing"
    elif [ $status == 1 ]; then
        message "Error" "Stop server before updating"
        error+="$name "
    else
        message "Error" "App is already installed"
        error+="$name "
    fi
}

command_remove()
{
    info

    if [ $status == 2 ]; then
        message "Error" "App is not installed"
        error+="$name "
    elif [ $status == 1 ]; then
        message "Error" "Stop server before removing"
        error+="$name "
    else
        game_remove
    fi
}

command_restore()
{
    info

    if [ $status == 2 ]; then
        message "Error" "App is not installed"
        error+="$name "
    elif [ $status == 1 ]; then
        message "Error" "Stop server before restoring"
        error+="$name "
    else
        game_restore
    fi
}

command_start()
{
    info

    if [ $status == 2 ]; then
        message "Error" "App is not Installed"
        error+="$name "
    elif [ $status == 1 ]; then
        message "Error" "Server is already running"
        error+="$server "
    else
        server_start
    fi
}

command_status()
{
    if [ $status != 2 ]; then
        info
        message "------"
    fi
}

command_stop()
{
    info

    if [ $status == 2 ]; then
        message "Error" "App is not Installed"
        error+="$name "
    elif [ $status == 1 ]; then
        server_stop
    else
        message "Error" "Server is not Running"
        error+="$server "
    fi
}

command_update()
{
    steamcmd_check
    info

    if [ $status == 2 ]; then
        message "Error" "App is not installed"
        error+="$name "
    elif [ $status == 1 ]; then
        message "Error" "Stop server before updating"
        error+="$name "
    else
        game_update "Updating"
    fi
}

command_validate()
{
    steamcmd_check
    info

    if [ $status == 2 ]; then
        message "Error" "App is not installed"
        error+="$name "
    elif [ $status == 1 ]; then
        message "Error" "Stop server before validating"
        error+="$name "
    else
        game_validate
    fi
}

command_setup()
{
    if [ -e "$steamcmd" ]; then
        message "Error" "SteamCMD is already installed"
        message "Status" "Would you like to reinstall it? ( y/n )"
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

if [ $( whoami ) == "root" ]; then
    message "Error" "Do not run as root"
    exit
fi

case "$1" in
    backup)
        argument_check $2
        for i in ${@:2}; do
            game_check $i
            command_backup
        done
        ;;
    backup-all)
        for i in $( ls $gamedir ); do
            game_check $i
            command_backup
        done
        ;;
    console)
        argument_check $2
        game_check $2
        server_check
        command_console
        ;;
    install)
        argument_check $2
        for i in ${@:2}; do
            game_check $i
            command_install
        done
        ;;
    list)
        for i in $( ls $gamedir ); do
            game_check $i
            info | head -2
            message "------"
        done
        ;;
    list-all)
        length=$( jq ". | length - 1" $startcfg )
        for i in $( seq 0 $length ); do
            name=$( jq -r ".[$i].name" $startcfg )
            appid=$( jq -r ".[$i].appid" $startcfg )
            status=0
            info | head -2
            message "------"
        done
        ;;
    remove)
        argument_check $2
        for i in ${@:2}; do
            game_check $i
            command_remove
        done
        ;;
    remove-all)
        for i in $( ls $gamedir ); do
            game_check $i
            command_remove
        done
        ;;
    restart)
        for i in ${@:2}; do
            game_check $i
            command_stop
            command_start
        done
        ;;
    restart-all)
        do_all command_stop command_start
        ;;
    restore)
        argument_check $2
        for i in ${@:2}; do
            game_check $i
            command_restore
        done
        ;;
    restore-all)
        for i in $( ls $gamedir ); do
            game_check $i
            command_restore
        done
        ;;
    setup)
        command_setup
        ;;
    start)
        argument_check $2
        for i in ${@:2}; do
            game_check $i
            server_check
            command_start
        done
        ;;
    start-all)
        do_all command_start
        ;;
    status)
        if [ -z "$2" ]; then
            do_all command_status
        else
            for i in ${@:2}; do
                game_check $i
                server_check
                command_status
            done
        fi
        ;;
    stop)
        argument_check $2
        for i in ${@:2}; do
            game_check $i
            server_check
            command_stop $i
        done
        ;;
    stop-all)
        do_all command_stop
        ;;
    update)
        argument_check $2
        for i in ${@:2}; do
            game_check $i
            command_update
        done
        ;;
    update-all)
        for i in $( ls $gamedir ); do
            game_check $i
            command_update
        done
        ;;
    validate)
        argument_check $2
        for i in ${@:2}; do
            game_check $i
            command_validate $i
        done
        ;;
    validate-all)
        for i in $( ls $gamedir ); do
            game_check $i
            command_validate
        done
        ;;
    *)
        message "Error" "Invalid Command"
esac

if [ -n "$error" ]; then
    message "Errors" "$error"
else
    message "Done"
fi
