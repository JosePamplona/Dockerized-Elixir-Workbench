# Lorem Ipsum Project

![version - 0.0.0](https://img.shields.io/badge/version-0.0.0-white.svg?style=flat-sector&color=lightgray)

# Development

## Set project name

Modify  README.md       - line 1,
        app             - lines 3, 11, 31
        Dockerfile.prod - line 86

## Create project

```sh
./app init
```

## Configures project, generate schema and migration files and DB initialization

```sh
./app setup
```

## Runs custom command intitialization

```sh
./app run [<COMMAND>...]
```

## Set version

Sets version on mix file and readme badge

```sh
./app set-version
```

# Use

## Deploy on localhost

```sh
./app up
```

# Docker

## Login to Docker

Github user and token classic

```sh
./app login
```

## Prune Docker

```sh
./app prune
```
