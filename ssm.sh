#!/bin/bash

username="anonymous"
password=""

rootdir="$( cd "$( dirname ${BASH_SOURCE[0]} )" && pwd )"
backupdir="$rootdir/backup"
config="$rootdir/config.json"
gamedir="$rootdir/games"
steamcmd="$rootdir"

maxbackups=5
maxwait=10
verbose=false

# Checking / Utility Functions

are_you_sure()
{
    while true; do
        printf "[ \e[0;32mStatus\e[m ] - Are you sure? ( y/n ): "
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
        message "Error" "You must specify at least one App"
        exit
    fi
}

do_all()
{
    servers=$( jq ".[$index].servers | keys" $config | awk -F\" '{print $2}' )

    for server in $servers; do
        for k in ${@}; do
            $k $server
        done
    done
}

flag_check()
{
    if [[ "$1" =~ -.* ]]; then
        flags=$( echo $1 | cut -d '-' -f 2 | grep -o . )

        for flag in $flags; do
            if [[ "$flag" =~ [dfirs] ]]; then
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

game_info()
{
    unset index name appid server
    number="^[0-9]+([.][0-9]+)?$"
    local length=$( jq ". | length - 1" $config )


    if [[ $1 =~ $number ]]; then
        for i in $( seq 0 $length ); do
            appid=$( jq -r ".[$i].appid" $config )

            if [ "$1" == "$appid" ]; then
                name=$( jq -r ".[$i].name" $config )
                index=$i
                break
            fi
        done

    else
        for i in $( seq 0 $length ); do
            name=$( jq -r ".[$i].name" $config )
            servercheck=$( jq -r ".[$i].servers.$1" $config )

            if [ "$1" == "$name" ]; then
                appid=$( jq -r ".[$i].appid" $config )
                index=$i

                if [ "null" != "$servercheck"  ]; then
                    server=$1
                fi

                break

            elif [ "null" != "$servercheck" ]; then
                appid=$( jq -r ".[$i].appid" $config )
                index=$i
                server=$1
                break
            fi
        done

    fi

    if [ -z "$index" ]; then
        message "Error" "Invalid App"
        exit
    fi
}

info()
{
    message "------"

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

    if [[ "$1" == "Name" || "$1" == "App ID" || "$1" == "F-Name" ]]; then
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

requirment_check()
{
    local requirments="find jq md5sum screen tar wget"

    for i in $requirments; do
        if [ -z $( which $i ) ]; then
            missing+="$i "
        fi
    done

    if [ -n "$missing" ]; then
        message "Error" "Missing required programs"
        message "Error" "$missing"
        exit
    fi
}

root_check()
{
    if [ $( whoami ) == "root" ]; then
        message "Error" "Do not run as root"
        exit
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
    if [ ! -s $steamcmd/steamcmd.sh ]; then
        message "Error" "SteamCMD not installed"
        steamcmd_install
    fi
}

steamcmd_filter()
{
    read input

    if [ -n "$( echo "$input" | grep "Success" )" ]; then
        message "Status" "$( echo "$input" | cut -d ' ' -f2- )"
    elif [ -n "$( echo "$input" | grep "ERROR" )" ]; then
        message "Error" "$( echo "$input" | cut -d ' ' -f2- )"
    elif [ -n "$( echo "$input" | grep "Update complete" )" ]; then
        message "Status" "SteamCMD Updated"
    elif [ -n "$( echo "$input" | grep "Failed\|" )" ]; then
        message "Error" "$( echo "$input" | cut -d ']' -f2- )"
    fi
}

stop_run_start()
{
    for server in $( session_check "\-$name" ); do
        servers+="$server "
        server_stop
    done

    if [ -z "$error" ]; then
        unset server
        info
        $1
    else
        message "Error" "A server would not stop"
        break
    fi

    if [ "$option" != "s" ]; then
        for server in $servers; do
            info
            server_start
        done
    fi
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
    backup="$backupdir/$name/$( date +%Y-%m-%d-%H%M%S ).tar.xz"
    tar c${v}Jf "$backup" --exclude "$backupdir" -C "$gamedir" $name

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
    if [ -n "$( ls $backupdir/$name )" ]; then
        local backups=($( ls -t $backupdir/$name ))
        local length=$(( ${#backups[@]} - 1 ))

        while true; do
            for i in $( seq 0 $length ); do
                message "$(( $i + 1 ))" "${backups[i]}"
            done

            printf "[ \e[0;32mStatus\e[m ] - Choose one: "
            read answer
            answer=$(( $answer - 1 ))

            if [[ -n "${backups[answer]}" && "$answer" != -1 ]]; then
                backup="$backupdir/$name/${backups[answer]}"
                break
            else
                message "Error" "Invalid Selection"
                message "------"
            fi
        done

        if [ -d "$gamedir/$name" ]; then
            local hash1=$( ls -la --full-time "$gamedir/$name" | md5sum )
        fi

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

    if [ "$verbose" == true  ]; then
        $steamcmd/./steamcmd.sh +login $username $password +force_install_dir \
            $gamedir/$name +app_update $appid +quit
    else
        $steamcmd/./steamcmd.sh +login $username $password +force_install_dir \
            $gamedir/$name +app_update $appid +quit | \
            grep "Success!\|ERROR!" | steamcmd_filter
    fi
}

game_validate()
{
    message "Status" "Validating"

    if [ "$verbose" == true  ]; then
        $steamcmd/./steamcmd.sh +login $username $password +force_install_dir \
            $gamedir/$name +app_update $appid -validate +quit
    else
        $steamcmd/./steamcmd.sh +login $username $password +force_install_dir \
            $gamedir/$name +app_update $appid -validate +quit \
            grep "Success!\|ERROR!" | steamcmd_filter
    fi
}

server_start()
{
    local dir="$( jq -r ".[$index].dir" $config )"
    local exec="$( jq -r ".[$index].exec" $config )"
    local length=$( jq ".[$index].servers.$server | length - 1" $config )

    for i in $( seq 0 $length ); do
        local tmp="$( jq -r ".[$index].servers.$server[$i]" $config )"
        gameoptions+="$tmp "
    done

    if [ "null" != "$dir" ]; then
        cd "$gamedir/$name/$dir"
    else
        cd "$gamedir/$name/"
    fi

    if [ "$option" == "d" ]; then
        message "Status" "Debugging"
        "./$exec" "$gameoptions"
    else
        message "Status" "Starting"
        screen -dmS "$server-$name" "./$exec" "$gameoptions"
    fi


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
    message "Status" "SteamCMD Installing"

    wget -N${v-q} http://media.steampowered.com/installer/steamcmd_linux.tar.gz \
        -P "$steamcmd"
    tar x${v}f steamcmd_linux.tar.gz -C "$steamcmd"

    if [ -s $steamcmd/steamcmd.sh ]; then
        message "Status" "SteamCMD Installed"
    else
        message "Error" "SteamCMD was not installed"
        exit
    fi

    message "Status" "SteamCMD Updating"

    if [ "$verbose" == true ]; then
        $steamcmd/./steamcmd.sh +quit
    else
        $steamcmd/./steamcmd.sh +quit | grep "Update complete\|Fatal Error" | \
            steamcmd_filter
    fi

    message "------"
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
            info
            server_start
        else
            game_backup
        fi
    fi
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
}

command_install()
{
    steamcmd_check
    info

    if [ ! -d "$gamedir/$name" ]; then
        if [ "$option" == "i" ]; then
            game_update
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
}

command_restore()
{
    info

    if [ -n "$( session_check "\-$name" )" ]; then
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
            info
            server_start
        else
            game_restore
        fi
    fi
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
}

command_status()
{
    if [ -n "$server" ]; then
        if [ "$server" != "$name" ]; then
            info
        else
            do_all info
        fi
    else
        do_all info
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
            info
            server_start
        else
            game_update
        fi
    fi
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
            info
            server_start
        else
            game_validate
        fi
    fi
}

command_setup()
{
    if [ -s $steamcmd/steamcmd.sh ]; then
        message "Error" "SteamCMD is already installed"
        while true; do
            printf "[ \e[0;32mStatus\e[m ] - Would you like to reinstall it? ( y/n ): "
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

requirment_check
root_check

case "$1" in
    backup)
        argument_check $2
        for i in ${@:2}; do
            flag_check $i
            game_info $i
            command_backup
        done
        ;;
    backup-all)
        flag_check $2 0
        for i in $( ls $gamedir ); do
            game_info $i
            command_backup
        done
        ;;
    console)
        argument_check $2
        game_info $2
        server_check
        command_console
        ;;
    install)
        argument_check $2
        for i in ${@:2}; do
            flag_check $i
            game_info $i
            command_install
        done
        ;;
    install-all)
        flag_check $2 0
        length=$( jq ". | length - 1" $config )
        for i in $( seq 0 $length ); do
            name=$( jq -r ".[$i].name" $config )
            appid=$( jq -r ".[$i].appid" $config )
            command_install
        done
        ;;
    list)
        for i in $( ls $gamedir ); do
            game_info $i
            fname=$( jq -r ".[$index].comment" $config )

            message "F-Name" "$fname"
            message "Name" "$name"
            message "App ID" "$appid"
            message "------"
        done
        ;;
    list-all)
        length=$( jq ". | length - 1" $config )

        for i in $( seq 0 $length ); do
            fname=$( jq -r ".[$i].comment" $config )
            name=$( jq -r ".[$i].name" $config )
            appid=$( jq -r ".[$i].appid" $config )

            message "F-Name" "$fname"
            message "Name" "$name"
            message "App ID" "$appid"
            message "------"
        done
        ;;
    remove)
        argument_check $2
        for i in ${@:2}; do
            flag_check $i
            game_info $i
            command_remove
        done
        ;;
    remove-all)
        are_you_sure
        flag_check $2 0
        for i in $( ls $gamedir ); do
            game_info $i
            command_remove
        done
        ;;
    restart)
        for i in ${@:2}; do
            game_info $i
            command_stop
            command_start
        done
        ;;
    restart-all)
        if [ -z "$2" ]; then
            for i in $( ls $gamedir ); do
                game_info $i
                do_all command_stop command_start
            done
        else
            for i in ${@:2}; do
                game_info $i
                do_all command_stop command_start
            done
        fi
        ;;
    restore)
        argument_check $2
        for i in ${@:2}; do
            flag_check $i
            game_info $i
            command_restore
        done
        ;;
    restore-all)
        are_you_sure
        flag_check $2 0
        for i in $( ls $gamedir ); do
            game_info $i
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
            flag_check $i
            game_info $i
            server_check
            command_start
        done
        ;;
    start-all)
        if [ -z "$2" ]; then
            for i in $( ls $gamedir ); do
                game_info $i
                do_all command_start
            done
        else
            for i in ${@:2}; do
                game_info $i
                do_all command_start
            done
        fi
        ;;
    status)
        if [ -z "$2" ]; then
            for i in $( ls $gamedir ); do
                game_info $i
                command_status
            done
        else
            for i in ${@:2}; do
                game_info $i
                command_status
            done
        fi
        ;;
    stop)
        argument_check $2
        for i in ${@:2}; do
            game_info $i
            server_check
            command_stop
        done
        ;;
    stop-all)
        if [ -z "$2" ]; then
            for i in $( ls $gamedir ); do
                game_info $i
                do_all command_stop
            done
        else
            for i in ${@:2}; do
                game_info $i
                do_all command_stop
            done
        fi
        ;;
    update)
        argument_check $2
        for i in ${@:2}; do
            flag_check $i
            game_info $i
            command_update
        done
        ;;
    update-all)
        flag_check $2 0
        for i in $( ls $gamedir ); do
            game_info $i
            command_update
        done
        ;;
    validate)
        argument_check $2
        for i in ${@:2}; do
            flag_check $i
            game_info $i
            command_validate
        done
        ;;
    validate-all)
        flag_check $2 0
        for i in $( ls $gamedir ); do
            game_info $i
            command_validate
        done
        ;;
    *)
        if [ -z "$1" ]; then
            message "Error" "Must specify a command"
        else
            message "Error" "Invalid command"
        fi
esac

if [ -n "$error" ]; then
    message "Errors" "$error"
else
    message "Done"
fi
