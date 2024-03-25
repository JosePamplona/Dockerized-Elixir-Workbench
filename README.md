# Lorem Ipsum Project

![version - 0.0.0](https://img.shields.io/badge/version-0.0.0-white.svg?style=flat-sector&color=lightgray)

**Dockerized Workbench** es un framework para crear, desarrollar y desplegar applicaciones en la maquina local con una arquitectura de servicios específica usando contenedores de Docker, sin la necesidad de instalar nada más que [Docker Desktop](https://www.docker.com/products/docker-desktop/).


Garantizando un despliegue de aplicación justo como correría en un ambiente de producción montado en red, con la excepción de que se despliega en ambiente de *localhost*.

## Arquitecture 

| Service | Description | Tech | URL |
| :-- | :-- | :-- | :-- |
| app | API-REST server <br> Web server | Elixir 1.16.2 / OTP 26.2.3 | [localhost:4000](http://localhost:4000) |
| database | Database server | PostgreSQL 16.2 | [localhost:5432](http://localhost:5432) |
| pgadmin | PGAdmin server | PGAdmin 8.4 | [localhost:5050](http://localhost:5050) |

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

Modify  README.md (line 1), app (lines 3, 11, 31) & Dockerfile.prod (line 86)

```sh
./app set-name <PROJECT_NAME>
```

### Create project and configures it

  Tarball error will occur on Win11 using a XFAT drive for the repo on
  mix deps.get
  1. Generates a new Phoenix project
  1. Configures the elixir project
      1. Configuration to properly work with docker
      1. Generates .env file
      1. Set schema timestamps

```sh
./app init
```

### Generate schema and migration files

  Configures servers.json & pgpass files with credentials for PGAdmin.
  Generates schema, changesets, context functions, tests and migration files

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

## Docker

### Login to Docker

Github user and token classic.
Only necesary for private docker images.

```sh
./app login
```

### Prune Docker

Stops all containers and prune Docker.

```sh
./app prune
```