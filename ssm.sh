#!/bin/bash

username="anonymous"
password=""

compression="gz"
maxbackups=5
maxwait=10
verbose=false

ssmdir="$( cd "$( dirname ${BASH_SOURCE[0]} )" && pwd )"
steamcmddir="$ssmdir/steamcmd"

backupdir="$ssmdir/backups"
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
    if [ -z "$args" ]; then
        message "Error" "You must specify at least one app or server"
        exit
    fi
}

config_check()
{
    if [ ! -e $serverjson ]; then
        message "Error" "No server config"
        message "Status" "Copying example"
        cp "$examplejson" "$serverjson"
    fi
}

game_info()
{
    unset index name appid fname config
    local number="^[0-9]+([.][0-9]+)?$"
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
        message "Error" "Invalid app name or app id"
        exit
    fi

    fname=$( jq -r ".[$index].fname" $appjson )
    config=$( jq -r ".[$index].config" $appjson )

    if [ "$config" == "null" ]; then
        unset config
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
        local session="server"
    else
        local session="name"
    fi

    if [ -n "$( session_check $session )" ]; then
        message "Status" "Running"
    else
        message "Status" "Not running"
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
            local missing+="$i "
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

run()
{
    server_info $name

    if [ "$option" == "r" ] || [ "$option" == "s" ]; then
        for server in $( session_check name ); do
            local servers+="$server "
            server_info $name
            info
            server_stop
        done
    elif [ "$option" == "i" ]; then
        local servers=$( jq ".[$index].servers | keys" $serverjson | awk -F\" '{print $2}' )
    fi

    info
    $1

    if [ "$option" == "r" ] || [ "$option" == "i" ]; then
        for server in $servers; do
            server_info $server
            info
            server_start
        done
    fi
}

server_all()
{
    local servers=$( jq ".[$index].servers | keys" $serverjson | awk -F\" '{print $2}' )

    for server in $servers; do
        for k in "${@}"; do
            server_info $server
            $k $server
        done
    done
}

server_check()
{
    if [ -z "$server" ]; then
        message "Error" "Invalid server name"
        exit
    fi
}

server_info()
{
    config_check

    unset index name server
    local length=$( jq ". | length - 1" $serverjson )

    for i in $( seq 0 $length ); do
        name=$( jq -r ".[$i].name" $serverjson )

        if [ "null" != "$( jq -r ".[$i].servers.$1" $serverjson )" ]; then
            server=$1
            index=$i
            break
        elif [ "$1" == "$name" ]; then
            index=$i
            break
        fi
    done

    if [ -z "$index" ]; then
        message "Error" "Invalid server name"
        exit
    fi
}

session_check()
{
    if [ "$1" == "server" ]; then
        local session="$name-$server"
    elif [ "$1" == "name" ]; then
        local session="$name\-"
    fi

    screen -ls | grep '(' | grep "$session" | cut -d '.' -f 2 | cut -d '-' -f 1
}

steamcmd_check()
{
    if [ ! -s "$steamcmddir/steamcmd.sh" ]; then
        message "------"
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
            message "Status" "SteamCMD updated"
        fi
    done
}

# Normal Functions

game_backup()
{
    mkdir -p "$backupdir/$name"

    if [ $compression ]; then
        local extension=".$compression"
    fi

    local backups=$( ls -1 "$backupdir/$name/" | wc -l )

    if (( $backups >= $maxbackups )); then
        message "Status" "Removing old backups"
        for i in $( seq $maxbackups $backups ); do
            rm "$backupdir/$name/$( ls -rt "$backupdir/$name/" | head -1 )"
        done
    fi

    message "Status" "Backing up"

    local backup="$backupdir/$name/$( date +%Y-%m-%d-%H%M%S ).tar$extension"
    tar ac${v}f "$backup" --exclude "$backupdir" -C "$gamedir" $name

    if [ -s "$backup" ]; then
        message "Status" "Backup complete"
    else
        message "Error" "Backup failed"
    fi
}

game_remove()
{
    message "Status" "Removing"
    rm -r${v} "$gamedir/$name"

    if [ ! -d "$gamedir/$name" ]; then
        message "Status" "Remove complete"
    else
        message "Error" "Remove failed"
    fi
}

game_restore()
{
    message "------"

    if [ -n "$( ls $backupdir/$name )" ]; then
        local backups=($( ls -t $backupdir/$name ))
        local length=$(( ${#backups[@]} - 1 ))

        while true; do
            for i in $( seq 0 $length ); do
                message "$(( $i + 1 ))" "${backups[i]}"
            done

            printf "[ \e[0;32mStatus\e[m ] - Choose one: "
            read answer
            local answer=$(( $answer - 1 ))

            if [[ -n "${backups[answer]}" && "$answer" != -1 ]]; then
                local backup="$backupdir/$name/${backups[answer]}"
                break
            else
                message "Error" "Invalid selection"
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
            message "Status" "Restore complete"
        else
            message "Error" "Restore failed"
        fi
    else
        message "Error" "There are no backups"
    fi
}

game_update_check()
{
    local buildid_steam=$( $steamcmddir/./steamcmd.sh +login anonymous +app_info_update 1 \
        +app_info_print $appid +quit | grep -m 1 "buildid" | cut -d '"' -f 4 )

    local buildid_local=$( cat "$gamedir/$name/steamapps/appmanifest_$appid.acf" | \
        grep -m 1 "buildid" | cut -d '"' -f 4 )

    if [ $buildid_local == buildid_steam ]; then
        return 0
    else
        return 1
    fi
}

game_update()
{
    if [ ! -d "$gamedir/$name" ]; then
        mkdir -p "$gamedir"
        message "Status" "Installing"
    else
        message "Status" "Checking for updates"

        if [ $( game_update_check ) ]; then
            message "Status" "Update available"
            message "Status" "Updating"
        else
            message "Status" "Already up to date"
            return
        fi
    fi

    if [ -n "$config" ]; then
        config="+app_set_config $appid $config"
    fi

    if [ "$verbose" == true  ]; then
        $steamcmddir/./steamcmd.sh +login $username $password +force_install_dir \
            $gamedir/$name +app_update $appid $config +quit
    else
        $steamcmddir/./steamcmd.sh +login $username $password +force_install_dir \
            $gamedir/$name +app_update $appid $config +quit | steamcmd_filter
    fi
}

game_validate()
{
    message "Status" "Validating"

    if [ -n "$config" ]; then
        config="+app_set_config $appid $config"
    fi

    if [ "$verbose" == true  ]; then
        $steamcmddir/./steamcmd.sh +login $username $password +force_install_dir \
            $gamedir/$name +app_update $appid $config -validate +quit
    else
        $steamcmddir/./steamcmd.sh +login $username $password +force_install_dir \
            $gamedir/$name +app_update $appid $config -validate +quit | steamcmd_filter
    fi
}

server_kill()
{
    message "Status" "Killing"
    screen -S "$name-$server" -X "quit"

    for i in $( seq 0 $maxwait ); do
        if [ -z "$( session_check server )" ]; then
            message "Status" "Stopped"
            break
        elif [ $i == $maxwait ]; then
            message "Error" "Kill failed"
            error+="\"$server\" "
            break
        fi

        sleep 1
    done
}

server_monitor()
{
    while true; do
        for app in $@; do
            server_info $app

            if [ -n "$server" ]; then
                local session="server"
            else
                local session="name"
            fi

            for server in $( session_check $session ); do
                local length=$(( ${#servers[@]} - 1 ))

                for i in $( seq 0 $length ); do
                    if [ "${servers[i]}" == "$server" ]; then
                        continue 2
                    fi
                done

                info
                local servers[$(( $length + 1))]=$server
            done
        done

        local length=$(( ${#servers[@]} - 1 ))

        for j in $( seq 0 $length ); do
            server_info ${servers[j]}

            if [ -z $( session_check server ) ]; then
                info

                if [ "$option" == "r" ]; then
                    server_start
                    info
                else
                    unset servers[$j]
                    local servers=( ${servers[@]} )
                fi

                break
            fi
        done

        sleep 1
    done
}

server_send()
{
    message "Status" "Command sent"
    screen -S "$name-$server" -X "stuff" "$1 $(echo -ne '\r')"
}

server_start()
{
    local length=$( jq ".[$index].servers.$server.start | length - 1" $serverjson )

    for i in $( seq 0 $length ); do
        local tmp="$( jq -r ".[$index].servers.$server.start[$i]" $serverjson )"
        local serveroptions+="$tmp "
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
        "./$exec" "$serveroptions"
    else
        message "Status" "Starting"
        screen -dmS "$name-$server" "./$exec" "$serveroptions"
    fi

    for i in $( seq 0 $maxwait ); do
        if [ -n "$( session_check server )" ]; then
            message "Status" "Started"
            break
        elif [ $i == $maxwait ]; then
            message "Error" "Start failed"
            error+="\"$server\" "
            break
        fi

        sleep 1
    done
}

server_status()
{
    if [ -n "$server" ]; then
        if [ "$server" != "$name" ]; then
            info
        else
            server_all info
        fi
    else
        server_all info
    fi
}

server_stop()
{
    message "Status" "Stopping"
    local length=$( jq ".[$index].servers.$server.stop | length - 1" $serverjson )

    for i in $( seq 0 $length ); do
        local tmp="$( jq -r ".[$index].servers.$server.stop[$i]" $serverjson )"
        screen -S "$name-$server" -X "stuff" "$tmp $(echo -ne '\r')"
    done

    for i in $( seq 0 $maxwait ); do
        if [ -z "$( session_check server )" ]; then
            message "Status" "Stopped"
            break
        elif [ $i == 10 ]; then
            message "Error" "Stop failed"
            error+="\"$server\" "
            server_kill
            break
        fi

        sleep 1
    done
}

steamcmd_install()
{
    message "Status" "SteamCMD installing"

    wget -N${v-q} http://media.steampowered.com/installer/steamcmd_linux.tar.gz \
        -P "$steamcmddir"
    tar x${v}f "$steamcmddir/steamcmd_linux.tar.gz" -C "$steamcmddir"

    if [ -s $steamcmddir/steamcmd.sh ]; then
        message "Status" "SteamCMD installed"
    else
        message "Error" "SteamCMD was not installed"
        exit
    fi

    message "Status" "SteamCMD updating"

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
            run game_backup
        fi
    else
        info

        if [ ! -d "$gamedir/$name" ]; then
            message "Error" "App is not installed"
            error+="\"$name\" "
        elif [ -n "$( session_check name )" ]; then
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
    elif [ -n "$( session_check server )" ]; then
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

    if [ "$option" == "i" ]; then
        run game_restore
    else
        info

        if [ ! -d "$gamedir/$name" ]; then
            game_update
        elif [ -n "$( session_check name )" ]; then
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
            run game_remove
        fi
    else
        info

        if [ ! -d "$gamedir/$name" ]; then
            message "Error" "App is not installed"
            error+="\"$name\" "
        elif [ -n "$( session_check name )" ]; then
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
            run game_restore
        fi
    else
        info

        if [ -n "$( session_check name )" ]; then
            message "Error" "Stop server before restoring"
            error+="\"$name\" "
        else
            game_restore
        fi
    fi
}

command_send()
{
    server_check
    info

    if [ ! -d "$gamedir/$name" ]; then
        message "Error" "App is not installed"
        error+="\"$name\" "
    elif [ -n "$( session_check server )" ]; then
        server_send $1
    else
        message "Error" "Server is not Running"
        error+="\"$server\" "
    fi
}

command_start()
{
    server_check
    info

    if [ ! -d "$gamedir/$name" ]; then
        message "Error" "App is not installed"
        error+="\"$name\" "
    elif [ -n "$( session_check server )" ]; then
        message "Error" "Server is already running"
        error+="\"$server\" "
    else
        server_start
    fi
}

command_stop()
{
    server_check
    info

    if [ ! -d "$gamedir/$name" ]; then
        message "Error" "App is not installed"
        error+="\"$name\" "
    elif [ -n "$( session_check server )" ]; then
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
            run game_update
        fi
    else
        info

        if [ ! -d "$gamedir/$name" ]; then
            message "Error" "App is not installed"
            error+="\"$name\" "
        elif [ -n "$( session_check name )" ]; then
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
            run game_validate
        fi
    else
        info

        if [ ! -d "$gamedir/$name" ]; then
            message "Error" "App is not installed"
            error+="\"$name\" "
        elif [ -n "$( session_check name )" ]; then
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
        message "------"
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
        message "------"
        steamcmd_install
    fi
}

requirment_check
root_check
args=()

for i in $@; do
    if [[ "$i" =~ ^-.* ]]; then
        flag=$( echo $i | cut -d '-' -f 2 | grep -o . )

        if [[ "$flag" =~ [dfirs] ]]; then
            option="$flag"
        elif [ "$flag" == "u" ] || [ -z "$username" ]; then
            printf "[ \e[0;32mStatus\e[m ] - Username: "
            read username
            printf "[ \e[0;32mStatus\e[m ] - Password: "
            read -s password
        elif [ "$flag" == "v" ]; then
            verbose=true
            v="v"
        fi
    elif [ -z "$command" ]; then
        command="$i"
    else
        args+=($i)
    fi
done

case "$command" in
    backup)
        argument_check
        for i in ${args[@]}; do
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
        server_info $args
        command_console
        ;;
    edit)
        if [ $args == "config" ]; then
            message "Status" "Editing config"
            sensible-editor $ssmdir/ssm.sh
        elif [ $args == "servers" ]; then
            message "Status" "Editing servers"
            sensible-editor $serverjson
        fi
        ;;
    install)
        argument_check
        for i in ${args[@]}; do
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
        if [ -z $args ]; then
            for i in $( ls $gamedir ); do
                args+=($i)
            done
        fi

        for i in ${args[@]}; do
            game_info $i
            message "------"
            message "F-Name" "$fname"
            message "Name" "$name"
            message "App ID" "$appid"
        done
        ;;
    list-all)
        length=$( jq ". | length - 1" $appjson )

        for i in $( seq 0 $length ); do
            fname=$( jq -r ".[$i].fname" $appjson )
            name=$( jq -r ".[$i].name" $appjson )
            appid=$( jq -r ".[$i].appid" $appjson )

            message "------"
            message "F-Name" "$fname"
            message "Name" "$name"
            message "App ID" "$appid"
        done
        ;;
    monitor)
        if [ -z "$args" ]; then
            for i in $( ls $gamedir ); do
                args+=($i)
            done
            server_monitor ${args[@]}
        else
            server_monitor ${args[@]}
        fi
        ;;
    remove)
        argument_check
        for i in ${args[@]}; do
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
        for i in ${args[@]}; do
            server_info $i
            command_stop
            command_start
        done
        ;;
    restart-all)
        if [ -z "$args" ]; then
            for i in $( ls $gamedir ); do
                server_info $i
                server_all command_stop command_start
            done
        else
            for i in ${args[@]}; do
                server_info $i
                server_all command_stop command_start
            done
        fi
        ;;
    restore)
        argument_check
        for i in ${args[@]}; do
            game_info $i
            command_restore
        done
        ;;
    restore-all)
        are_you_sure
        for i in $( ls $backupdir ); do
            game_info $i
            command_restore
        done
        ;;
    send)
        for i in ${args[@]:1}; do
            server_info $i
            command_send ${args[0]}
        done
        ;;
    send-all)
        if [ -z ${args[1]} ]; then
            for i in $( ls $gamedir ); do
                server_info $i
                server_all "command_send ${args[0]}"
            done
        else
            for i in ${args[@]:1}; do
                server_info $i
                server_all "command_send ${args[0]}"
            done
        fi
        ;;
    setup)
        command_setup
        ;;
    start)
        argument_check
        for i in ${args[@]}; do
            server_info $i
            command_start
        done
        ;;
    start-all)
        if [ -z "$args" ]; then
            for i in $( ls $gamedir ); do
                server_info $i
                server_all command_start
            done
        else
            for i in ${args[@]}; do
                server_info $i
                server_all command_start
            done
        fi
        ;;
    status)
        if [ -z "$args" ]; then
            for i in $( ls $gamedir ); do
                server_info $i
                server_status
            done
        else
            for i in ${args[@]}; do
                server_info $i
                server_status
            done
        fi
        ;;
    stop)
        argument_check
        for i in ${args[@]}; do
            server_info $i
            command_stop
        done
        ;;
    stop-all)
        if [ -z "$args" ]; then
            for i in $( ls $gamedir ); do
                server_info $i
                server_all command_stop
            done
        else
            for i in ${args[@]}; do
                server_info $i
                server_all command_stop
            done
        fi
        ;;
    update)
        argument_check
        for i in ${args[@]}; do
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
        for i in ${args[@]}; do
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
