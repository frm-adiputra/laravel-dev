# How to use

## Initialization

First, edit the USER CONFIG in the Makefile.
Make sure you are at the root directory of the tool chain.
Then initialize the tool chain using this command
```
make init
```

## Using the tool chain

To synchronize your source code (on docker host) and the source code
in the container use the following command
```
make sync
```

To open the development shell, run the following command
```
make shell
```

# Tecnical Specification

### Docker images

- {{AUTHOR}}/{{PROJECT}}-webdev
- {{AUTHOR}}/{{PROJECT}}-sync


### Docker containers

Ephemeral:
- {{PROJECT}}-webdev
- {{PROJECT}}-sync

Volumes:
- {{PROJECT}}-src
- {{PROJECT}}-mod
