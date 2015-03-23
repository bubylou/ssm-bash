# SteamCMD Server Manager ( SSM )

A Bash script for managing your SteamCMD servers.

## Getting Started

### Install Dependencies

- Install all the dependencies for SteamCMD and SSM.

#### Debian / Ubuntu 32 bit

`aptitude install jq screen unzip`

#### Debian / Ubuntu 64 bit

`aptitude install lib32gcc1 jq screen unzip`

- RedHat and CentOS do not have "jq" in there repositories by default.
- You will have to get it from another repository or manually install it.

#### RedHat / CentOS 32 bit

`yum install glibc libstdc++ jq screen unzip`

#### RedHat / CentOS 64 bit

`yum install glibc.i686 libstdc++.i686 jq screen unzip`

### Setup Account

- Create a unpriveleged user account to use for SSM.

#### Debian / Ubuntu

`adduser ssm`

#### RedHat / CentOS

`adduser ssm`

`passwd ssm`

### Install SSM

- Log in to the new account.

`su - ssm`

- Download and unzip SSM.

`wget https://github.com/bubylou/ssm/archive/master.zip`

`unzip master.zip`

- Change to the new directory and make the script executable.

`cd ssm-master`

`chmod +x ssm.sh`

### Install Game

- First install SteamCMD

`./ssm.sh setup`

- Install a game

`./ssm.sh install <app>`

### Configuration

- At the top of `steacmder.sh` there are a number of settings you can change.
    - `username` and `password` for Steam which is required to download some applications.
    - `rootdir` which is only used as a reference point for other directory settings.
    - By defaults all files and directories are placed under the `rootdir` but can be changed.
    - `maxbackups` for the max number of backups that are kept for each application.
    - `maxwait` is for the max amount of time in seconds to wait for a server to start or stop.
    - `verbose` toggles whether or not the script is verbose by default. ( true / false )

- Inside `config.json` is your application and server settings.
    - `comment` is just the application's full name for reference and can be changed.
    - `name` is what is actually used when using SSM and it can be changed if desired.
    - If you have that application already installed or backed up those directories must also be renamed.
    - `appid` is each applications unique id assigned by Steam and should not changed.
    - `dir` is a relative path from its install location when `exec` is run and should not be changed.
    - This setting is only required by some applications because dont run from the main directory.
    - `exec` is the file the is executed in order to start the server and should not change.
    - Next is individual server configurations. You can add as many of these as you would like.
    - No server can have the same name as any other one in the entire file.
    - Inside each server configuration are the servers arguments which can be changed.
    - These depend on what engine your server is running which can be identified by its `exec` option.
    - If there are any quotes or double quotes in the server arguments they must be escaped.
    - You can escape the characters by putting a '\' in front of them. Just like the hostname examples.

- Here are some links where you can find additional server arguments.
    - [Source](https://developer.valvesoftware.com/wiki/Command_Line_Options#Source_Dedicated_Server) (srcds_run)
    - [Half Life](https://developer.valvesoftware.com/wiki/Command_Line_Options#Half-Life_Dedicated_Server) (hlds_run)

### Start Server

- Now you can start the server.

`./ssm.sh start <server>`

## Usage

`./ssm.sh <command> [options] [<app> ...]`

## Options

`-d`

- Debug server startup.

`-f`

- Run the command even if the application has a server running. NOT RECOMMENDED

`-i`

- Run the command and then start the server.

`-r`

- If there are any servers running for an application stop them, run the command, and then start them again.

`-s`

- If there are any servers running for an application stop them and then run the command.

`-v`

- Make the output of the command more verbose.

## Commands

`backup [options] <app|server> ...`

- Backup the selected application.

`backup-all [options]`

- Backup all the installed applications.

`console <server>`

- Attach to the server's screen session.

`install <app> ...`

- Install the selected application.

`install-all`

- Install all the available applications.

`list`

- List all the installed applications.

`list-all`

- List all the installable applications.

`remove [options] <app|server> ...`

- Deletes the files for the selected application.

`remove-all [options]`

- Deletes the files for all your installed applications.

`restart <server> ...`

- Restart the selected server.

`restart-all [<app|server> ...]`

- Restart all servers.

`restore [options] <app|server> ...`

- Restore the selected application from the newest backup.

`restore-all [options]`

- Restores all your applications from there newest backups.

`setup`

- Installs SteaCMD.

`start [options] <server> ...`

- Start the selected server.

`start-all [<app|server> ...]`

- Start all servers.

`status [<app|server> ...]`

- Check status of a server or all servers if none are specified.

`stop <server> ...`

- Stop a server.

`stop-all [<app|server> ...]`

- Stop all servers.

`update [options] <app|server> ...`

- Update the selected applications.

`update-all [options]`

- Update all the installed applications.

`validate [options] <app|server> ...`

- Validate the selected application.

`validate-all [options]`

- Validate all the installed applications.
