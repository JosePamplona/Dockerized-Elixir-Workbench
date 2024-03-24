# Lorem Ipsum Project

![version - 0.0.0](https://img.shields.io/badge/version-0.0.0-white.svg?style=flat-sector&color=lightgray)

## Arquitecture 

<p align="center"><img src="arq.svg"></p>

## Use

### Database creation/reset

Custom ecto.reset for first time initialization or reset the database service.

```sh
./app db-reset
```

### Deploy service on localhost

Deploys the service along with its configured required services and **Workbench's** tools on localhost using Docker containers.

```sh
./app up
```

TODO: option --no-tools

## Development

### Set project name

TODO

Modify  README.md       - line 1,
        app             - lines 3, 11, 31
        Dockerfile.prod - line 86

### Create project and configures it

```sh
./app init
```

### Generate schema and migration files

```sh
./app schemas
```

### Runs custom intitialization command

```sh
./app run [<COMMAND>...]
```

### Set version

Sets version on mix file and readme badge

```sh
./app set-version
```

### Generate release file

TODO

```sh
./app release
```

## Docker

### Login to Docker

Github user and token classic.
Only necesary for private docker images.

```sh
./app login
```

### Prune Docker

```sh
./app prune
```