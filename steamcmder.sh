#!/bin/bash

username="anonymous"
password=""

rootdir="$( cd "$( dirname ${BASH_SOURCE[0]} )" && pwd )"
backupdir="$rootdir/backup"
gamedir="$rootdir/games"
startcfg="$rootdir/startcfg.json"
steamcmd="$rootdir/steamcmd.sh"

maxbackups=5
maxwait=10
verbose=false

# Checking / Utility Functions

are_you_sure()
{
    while true; do
        printf "[ Status ] - Are you sure? ( y/n ): "
        read answer
        case "$answer" in
            Y|y)
                break
                ;;
            N|n)
                exit
                ;;
            *)
                message "Error" "Invalid answer. Try again."
        esac
    done
}

argument_check()
{
    if [ -z "$1" ]; then
        message "Error" "You must specify at least one App Name"
        exit
    fi
}

do_all()
{
    servers=$( jq ".[$index]" $startcfg | grep '\[' | awk -F\" '{print $2}' )

    for server in $servers; do
        for k in ${@}; do
            $k $server
        done
    done
}

game_check()
{
    unset index name appid server
    number="^[0-9]+([.][0-9]+)?$"
    local length=$( jq ". | length - 1" $startcfg )


    if [[ $1 =~ $number ]]; then
        for i in $( seq 0 $length ); do
            appid=$( jq -r ".[$i].appid" $startcfg )

            if [ "$1" == "$appid" ]; then
                index=$i
                break
            fi
        done

        name=$( jq -r ".[$i].name" $startcfg )
    else
        for i in $( seq 0 $length ); do
            name=$( jq -r ".[$i].name" $startcfg )

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
        done

        appid=$( jq -r ".[$i].appid" $startcfg )
    fi

    if [ -z "$index" ]; then
        message "Error" "Invalid App Name"
        exit
    fi
}

info()
{
    if [ -n "$server" ]; then
        message "Name" "$server"
    elif [ -n "$name" ]; then
        message "Name" "$name"
    fi

    message "App ID" "$appid"

    if [ -n "$server" ]; then
        local session="$server-$name"
    else
        local session="$name"
    fi

    if [ -n "$( session_check "$session" )" ]; then
        message "Status" "Running"
    else
        message "Status" "Not Running"
    fi
}

message()
{
    printf '[ '

    if [[ "$1" == "Name" || "$1" == "App ID" ]]; then
        printf '\e[0;33m%-6s\e[m' "$1"
    elif [[ "$1" == "Status" || "$1" == "Done" ]]; then
        printf '\e[0;32m%-6s\e[m' "$1"
    elif [[ "$1" == "Error" || "$1" == "Errors" ]]; then
        printf '\e[0;31m%-6s\e[m' "$1"
    else
        printf '%-6s' "$1"
    fi

    printf " ]"

    if [ -n "$2" ]; then
        printf " - $2"
    fi

    printf '\n'
}

flag_check()
{
    if [[ "$1" =~ -.* ]]; then
        flags=$( echo $1 | cut -d '-' -f 2 | grep -o . )

        for flag in $flags; do
            if [[ "$flag" =~ [firs] ]]; then
                option="$flag"
            elif [ "$flag" == "v" ]; then
                verbose=true
                v="v"
            fi
        done

        if [ "$2" != 0 ]; then
            continue
        fi
    fi
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
    screen -ls | grep '(' | grep "$1" | cut -d '.' -f 2 | cut -d '-' -f 1
}

steamcmd_check()
{
    if [ ! -s $steamcmd ]; then
        message "Error" "SteamCMD not installed"
        steamcmd_install
    fi
}

stop_run_start()
{
    for server in $( session_check "\-$name" ); do
        servers+="$server "
        message "------"
        info
        server_stop
    done

    if [ -z "$error" ]; then
        unset server
        message "------"
        info
        $1
    else
        message "Error" "A server would not stop"
        break
    fi

    if [ "$option" != "s" ]; then
        for server in $servers; do
            message "------"
            info
            server_start
        done
    fi
}

success_check()
{
    while read line ; do
        if [ ! "$verbose" == true ]; then
            if [ -n "$( echo "$line" | grep "Success" )" ]; then
                message "Status" "${1}ed"
            elif [ -n "$( echo "$line" | grep "Fail" )" ]; then
                message "Error" "${1}ing Failed"
                message "Error" "$line"
            fi
        else
            echo $line
        fi
    done
}

# Normal Functions

game_backup()
{
    mkdir -p "$backupdir/$name"

    if [ -n "$( find "$backupdir/$name" -name "*.tar.xz" )" ]; then
        local backups=$( ls -1 "$backupdir/$name/"*.tar.xz | wc -l )

        if (( $backups >= $maxbackups )); then
            for i in $( seq $maxbackups $backups ); do
                message "Status" "Removing Old Backup"
                rm "$( ls -rt "$backupdir/$name/"*.tar.xz | head -1 )"
            done
        fi
    fi

    message "Status" "Backing Up"
    tar c${v}Jf "$backupdir/$name/$( date +%Y-%m-%d-%H%M%S ).tar.xz" \
        --exclude "$backupdir" -C "$gamedir" $name

    if [ -s "$backup" ]; then
        message "Status" "Backup Complete"
    else
        message "Error" "Backup Failed"
    fi
}

game_remove()
{
    message "Status" "Removing"
    rm -r${v} "$gamedir/$name"

    if [ ! -d "$gamedir/$name" ]; then
        message "Status" "Remove Complete"
    else
        message "Error" "Remove Failed"
    fi
}

game_restore()
{
    if [ -d "$backupdir/$name" ]; then
        backup=$( ls -t "$backupdir/$name/"*.tar.xz | head -1 )
    fi

    if [ -s "$backup" ]; then
        local hash1=$( ls -la --full-time "$gamedir/$name" | md5sum )

        message "Status" "Restoring"
        tar x${v}f "$backup" -C "$gamedir"

        local hash2=$( ls -la --full-time "$gamedir/$name" | md5sum )

        if [ "$hash1" != "$hash2" ]; then
            message "Status" "Restore Complete"
        else
            message "Error" "Restore Failed"
        fi
    else
        message "Error" "There are no backups"
    fi
}

game_update()
{
    if [ -d "$gamedir/$name" ]; then
        message "Status" "Updating"
    else
        mkdir -p "$gamedir"
        message "Status" "Installing"
    fi

    bash $steamcmd +login $username $password +force_install_dir \
        $gamedir/$name +app_update $appid +quit | success_check "Updat"
}

game_validate()
{
    message "Status" "Validating"
    bash $steamcmd +login $username $password +force_install_dir \
        $gamedir/$name +app_update $appid -validate +quit | success_check "Validat"
}

server_start()
{
    local exec="./$( jq -r ".[$index].exec" $startcfg )"
    local length=$( jq ".[$index].$server | length - 1" $startcfg )

    for i in $( seq 0 $length ); do
        local tmp="$( jq -r ".[$index].$server[$i]" $startcfg )"
        gameoptions+=" $tmp"
    done

    message "Status" "Starting"
    cd "$gamedir/$name/"
    screen -dmS "$server-$name" "$gamedir/$name/$exec" "$gameoptions"

    for i in $( seq 0 $maxwait ); do
        if [ -n "$( session_check "$server-$name" )" ]; then
            message "Status" "Started"
            break
        elif [ $i == 10 ]; then
            message "Error" "Start Failed"
            error+="\"$server\" "
            break
        fi

        sleep 1
    done
}

server_status()
{
    info
    message "------"
}

server_stop()
{
    message "Status" "Stopping"
    screen -S "$server-$name" -X "quit"

    for i in $( seq 0 $maxwait ); do
        if [ -z "$( session_check "$server-$name" )" ]; then
            message "Status" "Stopped"
            break
        elif [ $i == 10 ]; then
            message "Error" "Stop Failed"
            error+="\"$server\" "
            break
        fi

        sleep 1
    done
}

steamcmd_install()
{
    if [ -z "$v" ]; then
        q="q"
    fi

    message "Status" "Installing SteamCMD"
    wget -N${q} http://media.steampowered.com/installer/steamcmd_linux.tar.gz \
        -P "$rootdir"

    tar x${v}f steamcmd_linux.tar.gz -C "$rootdir"

    if [ -s $steamcmd ]; then
        message "Status" "SteamCMD was installed"
    else
        message "Error" "SteamCMD was not installed"
    fi
}

# Command Functions

command_backup()
{
    info

    if [ ! -d "$gamedir/$name" ]; then
        message "Error" "App is not installed"
        error+="\"$name\" "
    elif [ -n "$( session_check "\-$name" )" ]; then
        if [[ "$option" == "r" || "$option" == "s" ]]; then
            stop_run_start game_backup
        elif [ "$option" == "f" ]; then
            game_backup
        else
            message "Error" "Stop server before backup"
            error+="\"$name\" "
        fi
    else
        if [ "$option" == "i" ]; then
            game_backup
            message "------"
            info
            server_start
        else
            game_backup
        fi
    fi

    message "------"
}

command_console()
{
    info

    if [ ! -d "$gamedir/$name" ]; then
        message "Error" "App is not installed"
        error+="\"$name\" "
    elif [ -n "$( session_check "$server-$name" )" ]; then
        message "Status" "Attaching"
        screen -r "$server"
    else
        message "Error" "Server is not running"
        error+="\"$server\" "
    fi

    message "------"
}

command_install()
{
    steamcmd_check
    info

    if [ ! -d "$gamedir/$name" ]; then
        if [ "$option" == "i" ]; then
            game_update
            message "------"
            info
            server_start
        else
            game_update
        fi
    elif [ -n "$( session_check "\-$name" )" ]; then
        message "Error" "Stop server before installing"
        error+="\"$name\" "
    else
        message "Error" "App is already installed"
        error+="\"$name\" "
    fi

    message "------"
}

command_remove()
{
    info

    if [ ! -d "$gamedir/$name" ]; then
        message "Error" "App is not installed"
        error+="\"$name\" "
    elif [ -n "$( session_check "\-$name" )" ]; then
        if [[ "$option" == "r" || "$option" == "s" ]]; then
            stop_run_start game_remove
        elif [ "$option" == "f" ]; then
            game_remove
        else
            message "Error" "Stop server before removing"
            error+="\"$name\" "
        fi
    else
        game_remove
    fi

    message "------"
}

command_restore()
{
    info

    if [ ! -d "$gamedir/$name" ]; then
        message "Error" "App is not installed"
        error+="\"$name\" "
    elif [ -n "$( session_check "\-$name" )" ]; then
        if [[ "$option" == "r" || "$option" == "s" ]]; then
            stop_run_start game_restore
        elif [ "$option" == "f" ]; then
            game_restore
        else
            message "Error" "Stop server before restoring"
            error+="\"$name\" "
        fi
    else
        if [ "$option" == "i" ]; then
            game_restore
            message "------"
            info
            server_start
        else
            game_restore
        fi
    fi

    message "------"
}

command_start()
{
    info

    if [ ! -d "$gamedir/$name" ]; then
        message "Error" "App is not Installed"
        error+="\"$name\" "
    elif [ -n "$( session_check "$server-$name" )" ]; then
        message "Error" "Server is already running"
        error+="\"$server\" "
    else
        server_start
    fi

    message "------"
}

command_status()
{
    if [ -n "$server" ]; then
        if [ "$server" != "$name" ]; then
            server_status
        else
            do_all server_status
        fi
    else
        do_all server_status
    fi
}

command_stop()
{
    info

    if [ ! -d "$gamedir/$name" ]; then
        message "Error" "App is not Installed"
        error+="\"$name\" "
    elif [ -n "$( session_check "$server-$name" )" ]; then
        server_stop
    else
        message "Error" "Server is not Running"
        error+="\"$server\" "
    fi

    message "------"
}

command_update()
{
    steamcmd_check
    info

    if [ ! -d "$gamedir/$name" ]; then
        message "Error" "App is not installed"
        error+="\"$name\" "
    elif [ -n "$( session_check "\-$name" )" ]; then
        if [[ "$option" == "r" || "$option" == "s" ]]; then
            stop_run_start game_update
        elif [ "$option" == "f" ]; then
            game_update
        else
            message "Error" "Stop server before updating"
            error+="\"$name\" "
        fi
    else
        if [ "$option" == "i" ]; then
            game_update
            message "------"
            info
            server_start
        else
            game_update
        fi
    fi

    message "------"
}

command_validate()
{
    steamcmd_check
    info

    if [ ! -d "$gamedir/$name" ]; then
        message "Error" "App is not installed"
        error+="\"$name\" "
    elif [ -n "$( session_check "\-$name" )" ]; then
        if [[ "$option" == "r" || "$option" == "s" ]]; then
            stop_run_start game_validate
        elif [ "$option" == "f" ]; then
            game_validate
        else
            message "Error" "Stop server before validating"
            error+="\"$name\" "
        fi
    else
        if [ "$option" == "i" ]; then
            game_validate
            message "------"
            info
            server_start
        else
            game_validate
        fi
    fi

    message "------"
}

command_setup()
{
    if [ -s "$steamcmd" ]; then
        message "Error" "SteamCMD is already installed"
        while true; do
            printf "[ Status ] - Would you like to reinstall it? ( y/n ): "
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
            flag_check $i
            game_check $i
            command_backup
        done
        ;;
    backup-all)
        flag_check $2 0
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
    install-all)
        length=$( jq ". | length - 1" $startcfg )
        for i in $( seq 0 $length ); do
            name=$( jq -r ".[$i].name" $startcfg )
            appid=$( jq -r ".[$i].appid" $startcfg )
            command_install
        done
        ;;
    list)
        for i in $( ls $gamedir ); do
            game_check $i
            status=0
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
            flag_check $i
            game_check $i
            command_remove
        done
        ;;
    remove-all)
        are_you_sure
        flag_check $2 0
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
        if [ -z "$2" ]; then
            for i in $( ls $gamedir ); do
                game_check $i
                do_all command_stop command_start
            done
        else
            for i in ${@:2}; do
                game_check $i
                do_all command_stop command_start
            done
        fi
        ;;
    restore)
        argument_check $2
        for i in ${@:2}; do
            flag_check $i
            game_check $i
            command_restore
        done
        ;;
    restore-all)
        are_you_sure
        flag_check $2 0
        for i in $( ls $gamedir ); do
            game_check $i
            command_restore
        done
        ;;
    setup)
        flag_check $2 0
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
        if [ -z "$2" ]; then
            for i in $( ls $gamedir ); do
                game_check $i
                do_all command_start
            done
        else
            for i in ${@:2}; do
                game_check $i
                do_all command_start
            done
        fi
        ;;
    status)
        if [ -z "$2" ]; then
            for i in $( ls $gamedir ); do
                game_check $i
                command_status
            done
        else
            for i in ${@:2}; do
                game_check $i
                command_status
            done
        fi
        ;;
    stop)
        argument_check $2
        for i in ${@:2}; do
            game_check $i
            server_check
            command_stop
        done
        ;;
    stop-all)
        if [ -z "$2" ]; then
            for i in $( ls $gamedir ); do
                game_check $i
                do_all command_stop
            done
        else
            for i in ${@:2}; do
                game_check $i
                do_all command_stop
            done
        fi
        ;;
    update)
        argument_check $2
        for i in ${@:2}; do
            flag_check $i
            game_check $i
            command_update
        done
        ;;
    update-all)
        flag_check $2 0
        for i in $( ls $gamedir ); do
            game_check $i
            command_update
        done
        ;;
    validate)
        argument_check $2
        for i in ${@:2}; do
            flag_check $i
            game_check $i
            command_validate
        done
        ;;
    validate-all)
        flag_check $2 0
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
