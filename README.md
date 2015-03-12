# SteamCMDer

A simple Bash script to make managing your SteamCMD easier.

## Usage

`./steamcmder.sh <command> [option] [<app> ...]`

## Options

`-r`

- If the App is running then stop it, run the command, and then start it.

`-s`

- If the App is running then stop it and then run the command.

## Commands

`backup [option] <app> ...`

- Backup the chosen application.

`backup-all [option]`

- Backup all the installed applications.

`console <app>`

- Attach to the applications screen session.

`install <app> ...`

- Install the selected application.

`install-all <app> ...`

- Install all applications.

`list`

- List the installed applications.

`list-all`

- List all the installable applications.

`remove [option] <app> ...`

- Deletes the files for the selected application.

`remove-all [option]`

- Deletes the files for all your installed applications.

`restart <app> ...`

- Restart the selected application.

`restart-all`

- Restart all installed applications.

`restore [option] <app> ...`

- Restore the selected application from the newest backup.

`restore-all [option]`

- Restores all your applications from there newest backups.

`setup`

- Installs SteaCMD.

`start <app> ...`

- Start application.

`start-all`

- Start all applications.

`status [<app> ...]`

- Check status of an application or all applications if none are specified.

`stop <app> ...`

- Stop an application.

`stop-all`

- Stop all installed applications.

`update [option] <app> ...`

- Update the chosen applications.

`update-all [option]`

- Update all the installed applications.

`validate [option] <app> ...`

- Validate the chosen application.

`validate-all [option]`

- Validate all the installed applications.
