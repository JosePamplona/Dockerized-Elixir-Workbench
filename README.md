<!-- markdownlint-disable MD033 -->

# Dockerized Elixir Workbench <!-- omit in toc -->

![v0.7.0](https://img.shields.io/badge/version-0.7.0-white.svg?style=flat-square&color=lightgray)
[![License](https://img.shields.io/github/license/JosePamplona/Dockerized-Elixir-Workbench?style=flat-square)](https://github.com/JosePamplona/Dockerized-Elixir-Workbench/blob/main/LICENSE.md)
[![Last Updated](https://img.shields.io/github/last-commit/JosePamplona/Dockerized-Elixir-Workbench.svg?style=flat-square)](https://github.com/JosePamplona/Dockerized-Elixir-Workbench/commits/main)

This is a script for creating [Elixir](https://elixir-lang.org/) projects with the [Phoenix](https://www.phoenixframework.org/) framework and deploying them on `localhost` using a specific service architecture with Docker containers. It eliminates the need to install anything other than [Docker Desktop](https://www.docker.com/products/docker-desktop/) to create, develop, and deploy the project in either a development or production environment.

The workbench stays permanently in this directory. Projects are generated into the **workspace** directory (`WORKSPACE_PATH` in `config.conf`), each one owning its `docker-compose.yml` with its name, ports and images baked in — several workspaces can run simultaneously without conflicts. The Elixir configuration is delegated to the **workbench_igniter** package (`igniter/`), whose tasks run inside the containers.

- [Architecture](#architecture)
- [Configuration](#configuration)
- [Create a new project](#create-a-new-project)
- [Add features](#add-features)
- [Deployment](#deployment)
- [Daily development](#daily-development)
- [Delete project](#delete-project)
- [Maintenance](#maintenance)
  - [Private Github Registry Images](#private-github-registry-images)
  - [Demo](#demo)
  - [Help](#help)
- [License](#license)

## Architecture

<p align="center"><img alt="architecture diagram" src="assets/arq.svg"></p>

| Service | URL | Description |
| :-- | :-- | :-- |
| Elixir App | <http://localhost:4000> | API-REST, GraphiQL and/or Web server |
| pgAdmin | <http://localhost:5050> | Database management tool |
| Postgres DB | _not published_ | Relational database server, only reachable from inside its workspace |
| Auth0 | <https://dev-tenant.us.auth0.com:433> | Identity management platform |
| Open AI | <https://api.openai.com/v1:433> | AI Assistant service |
| Stripe | <https://api.stripe.com:433> | Payment service provider |

Host ports are assigned **per workspace** when the project is created: the first free ones starting from `4000` (application) and `5050` (pgAdmin). The `up` command prints the actual application URL.

## Configuration

1. Give execution permissions to the `./wb.sh` file (this step only needs to be performed once):

    ```sh
    sudo chmod +x wb.sh
    ```

1. Modify the `./config.conf` file in order to configure the project name and creation specifications.
  For complete configuration instruccions consult: [Configuration File](./CONFIG.md).

1. Make sure [Docker Desktop](https://www.docker.com/products/docker-desktop/) is running before running any script command.

## Create a new project

1. Run the following command:

    ```sh
    ./wb.sh new
    ```

    This command generates the project into the workspace, applies the configuration from `config.conf`, and bakes the workspace's own `docker-compose.yml` and `Dockerfile.local`.

    It can accept all option flags from the task `mix phx.new` like `--no-html` or `--no-ecto` (Full task [phx.new](https://hexdocs.pm/phoenix/Mix.Tasks.Phx.New.html) documentation).

## Add features

Workbench features can be installed on the existing project at any time:

```sh
./wb.sh add [FEATURE] [OPTIONS]
```

`[FEATURE]` is one of: **healthcheck**, **rest**, **graphql**, **coveralls**, **exdoc**, **enhancements**, **auth0**, **openai**, **credo**, **githooks**, **exmachina**, **mock**, **exdebug**, **psql_extras**, **osmon**. `[OPTIONS]` are the flags of the corresponding `mix workbench.install.FEATURE` task.

## Deployment

1. This step is only required when deploying the service for the first time, a database reset is needed or the database container is destroyed. This command drops the project database (if any), creates a new one and runs a seeding script:

    ```sh
    ./wb.sh setup [-e, --env ENV]
    ```

1. Once having a configured database, run the following command to deploy the service along with its configured required services and tools:

    ```sh
    ./wb.sh up [-e, --env ENV]
    ```

    The containers run **detached**: the terminal stays free and exiting it does not stop anything. The command prints the application URL.

In both commands the flag `[-e, --env ENV]` is optional. The argument `ENV` can be **dev**, **prod** or other, it corresponds to the desired enviroment configuration to be deployed, by default is **dev**.

The running system is managed with:

```sh
./wb.sh logs [SERVICE...] # Follow the containers logs (Ctrl+C detaches)
./wb.sh ps                # List the workspace containers
./wb.sh stop              # Stop the containers, keeping them for a fast restart
./wb.sh down              # Remove the containers (data volumes survive)
```

Images can be (re)built without deploying with `./wb.sh build [-e, --env ENV] [OPTIONS]` — the dev image from the project's `Dockerfile.local`, or the production release image with `-e prod` (`up -e prod` also rebuilds it on each deploy). `[OPTIONS]` are passed to `docker compose build`, e.g. `--no-cache`.

## Daily development

These commands run on the **running** app container (`exec`): they enter instantly and exiting them never stops the application.

```sh
./wb.sh iex          # Interactive Elixir shell on the project
./wb.sh mix [ARGS..] # Any mix task, e.g.: mix cover, mix docs, mix test
./wb.sh bash         # Shell inside the app container
```

`mix` also works with the system down: it falls back to a one-off container (starting the database dependency if needed), so tasks like `./wb.sh mix docs` do not require a full deployment.

## Delete project

Use this command for deleting all project files and the Docker compose project:

```sh
./wb.sh delete
```

> ⚠️ **Warning**: This action is destructive. Once executed, the current project files will be deleted, and neither the files nor the docker containers can be recovered. Before proceeding, make sure you are absolutely certain that you want to remove them.

## Maintenance

### Private Github Registry Images

In order to download private github registry images, you need to login to GitHub using a username and a token (classic, not fine-grained) and have the required access level to the resource. To do this, execute the following command:

```sh
./wb.sh login [GITHUB_USER] [ACCESS_TOKEN]
```

Replace `[GITHUB_USER]` and `[ACCESS_TOKEN]` with your corresponding user name and token. How to generate a token: [Personal Access Token (classic)](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-personal-access-token-classic)

### Demo

This command runs the **new**, **setup**, **up**, **logs** and **delete** commands consecutively for demonstration purposes. The logs block the demo while the application is tried out; Ctrl+C moves on to the teardown (gated by its own confirmation):

```sh
./wb.sh demo [-e, --env ENV]
```

The flag `[-e, --env ENV]` is optional. The argument `ENV` can be **dev**, **prod** or other, it corresponds to the desired enviroment configuration to be deployed, by default is **dev**.

> ⚠️ **Warning**: This action is destructive. Once executed, the current project files (if any) will be deleted, new ones will be created and finally deleted again and cannot be recovered. Before proceeding, make sure is safe to remove them if there is any.

### Help

Shows the workbench script help section:

```sh
./wb.sh help
```

## License

This software is released under the [MIT](https://mit-license.org/) license.

Permission is granted to use, copy, modify, and distribute the code in both commercial and non-commercial projects. It only requires that the copyright notice and permission statement be maintained in all copies. No warranties are provided and the authors bear no liability.

Copyright © 2024 José Luis Pamplona Stoever.
