# SteamCMDer

A simple Bash script to make managing your SteamCMD easier.

## Usage

`./steamcmder.sh <command> [option] [<app> ...]`

## Options

`-f`

- Run the command even if the application has a server running. NOT RECOMMENDED

`-i`

- Run the command and then start the server.

`-r`

- If there are any servers running for an application stop them, run the command, and then start them again.

`-s`

- If there are any servers running for an application stop them and then run the command.

## Commands

`backup [option] <app> ...`

- Backup the selected application.

`backup-all [option]`

- Backup all the installed applications.

`console <app>`

- Attach to the server's screen session.

`install <app> ...`

- Install the selected application.

`install-all <app> ...`

- Install all the available applications.

`list`

- List the installed applications.

`list-all`

- List all the installable applications.

`remove [option] <app> ...`

- Deletes the files for the selected application.

`remove-all [option]`

- Deletes the files for all your installed applications.

`restart <app> ...`

- Restart the selected server.

`restart-all [<app> ...]`

- Restart all servers.

`restore [option] <app> ...`

- Restore the selected application from the newest backup.

`restore-all [option]`

- Restores all your applications from there newest backups.

`setup`

- Installs SteaCMD.

`start <app> ...`

- Start the selected server.

`start-all [<app> ...]`

- Start all servers.

`status [<app> ...]`

- Check status of a server or all servers if none are specified.

`stop <app> ...`

- Stop a server.

`stop-all [<app> ...]`

- Stop all servers.

`update [option] <app> ...`

- Update the selected applications.

`update-all [option]`

- Update all the installed applications.

`validate [option] <app> ...`

- Validate the selected application.

`validate-all [option]`

- Validate all the installed applications.
