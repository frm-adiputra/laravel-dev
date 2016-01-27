# How to use

## Configurations

Configurations will be read from `Makefile` that resides in the same directory as `Makefile.sample`.
You can just copy the `Makefile.sample`, and edit the configurations to suit your needs.

## Commands

### `make start`

Starts all the services. You should run this command before you use any other command.

This command will initialize the environment if it is not already initialized.
After initializing, the following services will be started:
- db
- web
- db-admin

### `make info`

This command will display informations about the environment, it also includes informations about the URL of each services.

### `make app-shell`

This command will open a shell in your app web server container.

### `make db-shell`

This command will open a shell in your database container.

### `make mysql-shell`

This command will open a MariaDB shell in your database container.
