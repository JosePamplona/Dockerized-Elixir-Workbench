# Lorem Ipsum

![version - 0.0.0](https://img.shields.io/badge/version-0.0.0-white.svg?style=flat-sector&color=lightgray)

> **Lorem Ipsum** uses a framework to create, develop, and deploy an application on `localhost` with a specific service architecture using Docker containers, without the need to install anything other than [Docker Desktop](https://www.docker.com/products/docker-desktop/). Ensuring an application deployment just like it would run in a network-mounted production environment, with the exception that it is deployed on the local machine.<br/><br/>
> Once created the project, in order to start the server without the framework as normally, navigate to the `./src` directory and consult the application [README.md](./src/README.md) file.

## Table of Contents

- [1. Application](#1-application)
  - [1.1. Documentation](#11-documentation)
  - [1.2. Changelog](#12-changelog)
- [2. Framework](#2-framework)
  - [2.1. Arquitecture](#21-arquitecture)
  - [2.2. Development](#22-development)
    - [2.2.1. Create a brand new project](#221-create-a-brand-new-project)
    - [2.2.2. Custom commands](#222-custom-commands)
    - [2.2.3. Set version](#223-set-version)
  - [2.3. Deployment](#23-deployment)
    - [2.3.1. Deploy in prod](#231-deploy-in-prod)
    - [2.3.2. Deploy in dev](#232-deploy-in-dev)
  - [2.4. Docker](#24-docker)
    - [2.4.1. Login to Docker](#241-login-to-docker)
    - [2.4.2. Prune Docker](#242-prune-docker)

## 1. Application

### 1.1 Documentation

To consult the application documentation, refer to the [./src/README.md](./src/README.md) file.

### 1.2 Changelog

To consult the application changelogs, refer to the [./src/CHANGELOG.md](./src/CHANGELOG.md) file.

## 2. Framework

In order to use the framework, install [Docker Desktop](https://www.docker.com/products/docker-desktop/) in your system and make sure the installed application is running.

### 2.1. Arquitecture

| Service | URL                                 | Description                | DEV enviroment only |
| :------ | :---------------------------------- | :----------------------------------------- | :-: |
| app | [localhost:4000](http://localhost:4000) | API-REST server                            |     |
| app | [localhost:4000/dev/dashboard](http://localhost:4000/dev/dashboard) | Phoenix Live Dashboard | ✔️  |
| app | [localhost:4000/dev/mailbox](http://localhost:4000/dev/mailbox) | Swoosh mailbox             | ✔️  |
| database | [localhost:5432](http://localhost:5432) | PostgreSQL database server            |     |
| pgadmin  | [localhost:5050](http://localhost:5050) | PGAdmin server                        |     |

<p align="center"><img alt="arquitecture diagram" src=".framework/arq.svg"></p>

### 2.2. Development

#### 2.2.1. Create a brand new project

1. Edit the `config.conf` to set the configuration of how the framework will behave and how the project will be created. This is not mandatory.

1. Is needed to set a name for a new project. Run the following command replacing `PROJECT_NAME` with the desired name (Use capital casing with spaces):

    ```sh
    ./app name PROJECT_NAME
    ```

1. In order to create a new Phoenix project, run the following command:

    ```sh
    ./app new
    ```

    This will generate all the files and apply specific configurations.
    It can accept all option flags from the task `mix phx.new` like `--no-html` or `--no-esbuild` (Full task [phx.new](https://hexdocs.pm/phoenix/Mix.Tasks.Phx.New.html) documentation).

1. Edit the `schemas.sh` file in order to create a migration generation script. Once saved, run the following command:

    ```sh
    ./app schemas
    ```

    This generate schemas, changesets and contexts functions, tests and migration files and configures `servers.json` & `pgpass` files with credentials for PGAdmin.

#### 2.2.2. Custom commands

There is the possibility of deploying the service by executing custom server initialization commands. For example, to run the elixir interactive console: `iex -S mix phx.server`.

Execute the following command, replacing `[COMMAND...]` with the command(s) to be executed:

```sh
./app run [COMMAND...]
```

#### 2.2.3. Set version

Set application version on `src/mix.exs` file and `README.md` version badge.

```sh
./app set-version 0.0.0
```

### 2.3. Deployment

### 2.3.1 Deploy in `prod`

1. This step is only required when deploying the service for the first time, a database reset is needed or the database container is detroyed. This command drops the project database (if any), creates a new one and run a seeding script:

    ```sh
    ./app db-reset
    ```

1. Once having a configured database, run the following command to deploy the service along with its configured required services and tools in a (local) production enviroment.

    ```sh
    ./app up
    ```

### 2.3.2 Deploy in `dev`

1. Execute the same commands used in `prod`, just add the `--dev` option to both commands:

    ```sh
    ./app db-reset --dev
    ./app up --dev
    ```

    By default, each enviroment have their own database. Remember it when changing enviroments.

### 2.4. Docker

#### 2.4.1. Login to Docker

In order to download private github registry images, you need to login to GitHub using a username and a token (classic, not fine-grained) and have access to the resource. To do this, execute the following command:

```sh
./app login GITHUB_USER ACCESS_TOKEN
```

How to generate token: [Personal Access Token (classic)](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-personal-access-token-classic)

#### 2.4.2. Prune Docker

Stops all containers and prune Docker.

```sh
./app prune
```
