#!/bin/bash

username="anonymous"
password=""

maxbackups=5
maxwait=10
verbose=false

ssmdir="$( cd "$( dirname ${BASH_SOURCE[0]} )" && pwd )"
steamcmddir="$ssmdir/steamcmd"

backupdir="$ssmdir/backup"
gamedir="$ssmdir/games"

appjson="$ssmdir/applications.json"
examplejson="$ssmdir/example.json"
serverjson="$ssmdir/servers.json"

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
    if [ -z "$apps" ]; then
        message "Error" "You must specify at least one App"
        exit
    fi
}

do_all()
{
    servers=$( jq ".[$index].servers | keys" $serverjson | awk -F\" '{print $2}' )

    for server in $servers; do
        for k in ${@}; do
            $k $server
        done
    done
}

flag_set()
{
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
}

game_info()
{
    unset index name appid
    number="^[0-9]+([.][0-9]+)?$"
    local length=$( jq ". | length - 1" $appjson )


    if [[ $1 =~ $number ]]; then
        for i in $( seq 0 $length ); do
            appid=$( jq -r ".[$i].appid" $appjson )

            if [ "$1" == "$appid" ]; then
                name=$( jq -r ".[$i].name" $appjson )
                index=$i
                break
            fi
        done

    else
        for i in $( seq 0 $length ); do
            name=$( jq -r ".[$i].name" $appjson )

            if [ "$1" == "$name" ]; then
                appid=$( jq -r ".[$i].appid" $appjson )
                index=$i
                break
            fi
        done

    fi

    if [ -z "$index" ]; then
        server_info $1

        if [ -n "$name" ]; then
            game_info $name
        else
            message "Error" "Invalid App Name or App ID"
            exit
        fi
    fi
}

info()
{
    message "------"

    if [ -n "$server" ]; then
        message "Name" "$server"
    elif [ -n "$name" ]; then
        message "Name" "$name"
        message "App ID" "$appid"
    fi

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

server_info()
{
    unset index name server
    local length=$( jq ". | length - 1" $serverjson )

    for i in $( seq 0 $length ); do
        name=$( jq -r ".[$i].name" $serverjson )
        servercheck=$( jq -r ".[$i].servers.$1" $serverjson )

        if [ "null" != "$servercheck" ]; then
            server=$1
            index=$i
            break
        fi
    done

    if [ -z "$index" ]; then
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
    if [ ! -s "$steamcmddir/steamcmd.sh" ]; then
        message "Error" "SteamCMD not installed"
        steamcmd_install
    fi
}

steamcmd_filter()
{
    while read line; do
        if [ -n "$( echo "$line" | grep "Success" )" ]; then
            message "Status" "$( echo "$line" | cut -d ' ' -f2- )"
        elif [ -n "$( echo "$line" | grep "ERROR\|Failed" )" ]; then
            message "Error" "$( echo "$line" | cut -d ' ' -f2- )"
        elif [ -n "$( echo "$line" | grep "launching Steam" )" ]; then
            message "Status" "SteamCMD Updated"
        fi
    done
}

stop_run_start()
{
    if [ "$option" != "i" ]; then
        for server in $( session_check "\-$name" ); do
            servers+="$server "
            info
            server_stop
        done
    else
        if [ -z "$server" ]; then
            server_info $name
        fi

        servers="$server"
    fi

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
            server_info $server
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
        message "------"

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

        message "------"
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
        $steamcmddir/./steamcmd.sh +login $username $password +force_install_dir \
            $gamedir/$name +app_update $appid +quit
    else
        $steamcmddir/./steamcmd.sh +login $username $password +force_install_dir \
            $gamedir/$name +app_update $appid +quit | steamcmd_filter
    fi
}

game_validate()
{
    message "Status" "Validating"

    if [ "$verbose" == true  ]; then
        $steamcmddir/./steamcmd.sh +login $username $password +force_install_dir \
            $gamedir/$name +app_update $appid -validate +quit
    else
        $steamcmddir/./steamcmd.sh +login $username $password +force_install_dir \
            $gamedir/$name +app_update $appid -validate +quit | steamcmd_filter
    fi
}

server_start()
{
    local length=$( jq ".[$index].servers.$server | length - 1" $serverjson )

    for i in $( seq 0 $length ); do
        local tmp="$( jq -r ".[$index].servers.$server[$i]" $serverjson )"
        gameoptions+="$tmp "
    done

    game_info $name
    local dir="$( jq -r ".[$index].dir" $appjson )"
    local exec="$( jq -r ".[$index].exec" $appjson )"

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
    message "------"
    message "Status" "SteamCMD Installing"

    wget -N${v-q} http://media.steampowered.com/installer/steamcmd_linux.tar.gz \
        -P "$steamcmddir"
    tar x${v}f "$steamcmddir/steamcmd_linux.tar.gz" -C "$steamcmddir"

    if [ -s $steamcmddir/steamcmd.sh ]; then
        message "Status" "SteamCMD Installed"
    else
        message "Error" "SteamCMD was not installed"
        exit
    fi

    message "Status" "SteamCMD Updating"

    if [ "$verbose" == true ]; then
        $steamcmddir/./steamcmd.sh +quit
    else
        $steamcmddir/./steamcmd.sh +quit | steamcmd_filter
    fi
}

# Command Functions

command_backup()
{
    if [[ "$option" =~ [firs] ]]; then
        if [ "$option" == "f" ]; then
            info
            game_backup
        else
            stop_run_start game_backup
        fi
    else
        info

        if [ ! -d "$gamedir/$name" ]; then
            message "Error" "App is not installed"
            error+="\"$name\" "
        elif [ -n "$( session_check "\-$name" )" ]; then
            message "Error" "Stop server before backup"
            error+="\"$name\" "
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

    if [ "$option" == "i" ]; then
        stop_run_start game_restore
    else
        info

        if [ ! -d "$gamedir/$name" ]; then
            game_update
        elif [ -n "$( session_check "\-$name" )" ]; then
            message "Error" "Stop server before installing"
            error+="\"$name\" "
        else
            message "Error" "App is already installed"
            error+="\"$name\" "
        fi
    fi
}

command_remove()
{
    if [[ "$option" =~ [firs] ]]; then
        if [ "$option" == "f" ]; then
            info
            game_remove
        else
            stop_run_start game_remove
        fi
    else
        info

        if [ ! -d "$gamedir/$name" ]; then
            message "Error" "App is not installed"
            error+="\"$name\" "
        elif [ -n "$( session_check "\-$name" )" ]; then
            message "Error" "Stop server before removing"
            error+="\"$name\" "
        else
            game_remove
        fi
    fi
}

command_restore()
{
    if [[ "$option" =~ [firs] ]]; then
        if [ "$option" == "f" ]; then
            info
            game_restore
        else
            stop_run_start game_restore
        fi
    else
        info

        if [ -n "$( session_check "\-$name" )" ]; then
            message "Error" "Stop server before restoring"
            error+="\"$name\" "
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

    if [[ "$option" =~ [firs] ]]; then
        if [ "$option" == "f" ]; then
            info
            game_update
        else
            stop_run_start game_update
        fi
    else
        info

        if [ ! -d "$gamedir/$name" ]; then
            message "Error" "App is not installed"
            error+="\"$name\" "
        elif [ -n "$( session_check "\-$name" )" ]; then
            message "Error" "Stop server before updating"
            error+="\"$name\" "
        else
            game_update
        fi
    fi
}

command_validate()
{
    steamcmd_check

    if [[ "$option" =~ [firs] ]]; then
        if [ "$option" == "f" ]; then
            info
            game_validate
        else
            stop_run_start game_validate
        fi
    else
        info

        if [ ! -d "$gamedir/$name" ]; then
            message "Error" "App is not installed"
            error+="\"$name\" "
        elif [ -n "$( session_check "\-$name" )" ]; then
            message "Error" "Stop server before validating"
            error+="\"$name\" "
        else
            game_validate
        fi
    fi
}

command_setup()
{
    if [ -s "$steamcmddir/steamcmd.sh" ]; then
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

if [ ! -e $serverjson ]; then
    cp "$examplejson" "$serverjson"
    message "Error" "No Server Config"
    message "Status" "Copying Example"
fi

for i in $@; do
    if [[ "$i" =~ ^-.* ]]; then
        flag_set $i
    elif [ -z "$command" ]; then
        command="$i"
    else
        apps+="$i "
    fi
done

case "$command" in
    backup)
        argument_check
        for i in $apps; do
            game_info $i
            command_backup
        done
        ;;
    backup-all)
        for i in $( ls $gamedir ); do
            game_info $i
            command_backup
        done
        ;;
    console)
        argument_check
        server_info $apps
        command_console
        ;;
    install)
        argument_check
        for i in $apps; do
            game_info $i
            command_install
        done
        ;;
    install-all)
        length=$( jq ". | length - 1" $appjson )
        for i in $( seq 0 $length ); do
            name=$( jq -r ".[$i].name" $appjson )
            appid=$( jq -r ".[$i].appid" $appjson )
            command_install
        done
        ;;
    list)
        for i in $( ls $gamedir ); do
            game_info $i
            fname=$( jq -r ".[$index].comment" $appjson )

            message "F-Name" "$fname"
            message "Name" "$name"
            message "App ID" "$appid"
            message "------"
        done
        ;;
    list-all)
        length=$( jq ". | length - 1" $appjson )

        for i in $( seq 0 $length ); do
            fname=$( jq -r ".[$i].comment" $appjson )
            name=$( jq -r ".[$i].name" $appjson )
            appid=$( jq -r ".[$i].appid" $appjson )

            message "F-Name" "$fname"
            message "Name" "$name"
            message "App ID" "$appid"
            message "------"
        done
        ;;
    remove)
        argument_check
        for i in $apps; do
            game_info $i
            command_remove
        done
        ;;
    remove-all)
        are_you_sure
        for i in $( ls $gamedir ); do
            game_info $i
            command_remove
        done
        ;;
    restart)
        for i in $apps; do
            server_info $i
            command_stop
            command_start
        done
        ;;
    restart-all)
        if [ -z "$apps" ]; then
            for i in $( ls $gamedir ); do
                server_info $i
                do_all command_stop command_start
            done
        else
            for i in $apps; do
                server_info $i
                do_all command_stop command_start
            done
        fi
        ;;
    restore)
        argument_check
        for i in $apps; do
            game_info $i
            command_restore
        done
        ;;
    restore-all)
        are_you_sure
        for i in $( ls $gamedir ); do
            game_info $i
            command_restore
        done
        ;;
    setup)
        command_setup
        ;;
    start)
        argument_check
        for i in $apps; do
            server_info $i
            command_start
        done
        ;;
    start-all)
        if [ -z "$apps" ]; then
            for i in $( ls $gamedir ); do
                server_info $i
                do_all command_start
            done
        else
            for i in $apps; do
                server_info $i
                do_all command_start
            done
        fi
        ;;
    status)
        if [ -z "$apps" ]; then
            for i in $( ls $gamedir ); do
                server_info $i
                command_status
            done
        else
            for i in $apps; do
                server_info $i
                command_status
            done
        fi
        ;;
    stop)
        argument_check
        for i in $apps; do
            server_info $i
            command_stop
        done
        ;;
    stop-all)
        if [ -z "$apps" ]; then
            for i in $( ls $gamedir ); do
                server_info $i
                do_all command_stop
            done
        else
            for i in $apps; do
                server_info $i
                do_all command_stop
            done
        fi
        ;;
    update)
        argument_check
        for i in $apps; do
            game_info $i
            command_update
        done
        ;;
    update-all)
        for i in $( ls $gamedir ); do
            game_info $i
            command_update
        done
        ;;
    validate)
        argument_check
        for i in $apps; do
            game_info $i
            command_validate
        done
        ;;
    validate-all)
        for i in $( ls $gamedir ); do
            game_info $i
            command_validate
        done
        ;;
    *)
        if [ -z "$command" ]; then
            message "Error" "Must specify a command"
        else
            message "Error" "Invalid command"
        fi
esac

message "------"

if [ -n "$error" ]; then
    message "Errors" "$error"
else
    message "Done"
fi
