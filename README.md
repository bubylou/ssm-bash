# SteamCMDer

A Bash script for managing your SteamCMD servers.


## Requirments

The following programs are required for the script to run.

`find jq md5sum screen tar wget`

## Usage

`./steamcmder.sh <command> [options] [<app> ...]`

## Options

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

`start <server> ...`

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
