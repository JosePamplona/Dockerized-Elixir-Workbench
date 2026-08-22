<!-- markdownlint-disable MD033 -->

# Dockerized Elixir Workbench <!-- omit in toc -->

![v0.6.0](https://img.shields.io/badge/version-0.6.0-white.svg?style=flat-square&color=lightgray)
[![License](https://img.shields.io/github/license/JosePamplona/Dockerized-Elixir-Workbench?style=flat-square)](https://github.com/JosePamplona/Dockerized-Elixir-Workbench/blob/main/LICENSE.md)
[![Last Updated](https://img.shields.io/github/last-commit/JosePamplona/Dockerized-Elixir-Workbench.svg?style=flat-square)](https://github.com/JosePamplona/Dockerized-Elixir-Workbench/commits/main)

This is a workbench for creating [Elixir](https://elixir-lang.org/) projects with the [Phoenix](https://www.phoenixframework.org/) framework and deploying them on `localhost` using a specific service architecture with Docker containers. It eliminates the need to install anything other than [Docker Desktop](https://www.docker.com/products/docker-desktop/) to create, develop, and deploy the project in either a development or production mode.

- [Arquitecture](#arquitecture)
- [How it works](#how-it-works)
- [Configuration](#configuration)
- [Create a new project](#create-a-new-project)
- [Features](#features)
- [Deployment](#deployment)
  - [Custom entrypoint](#custom-entrypoint)
- [Delete project](#delete-project)
- [Maintenance](#maintenance)
  - [Private Github Registry Images](#private-github-registry-images)
  - [Demo](#demo)
  - [Reset Docker](#reset-docker)
  - [Help](#help)
- [License](#license)

---

## Arquitecture

<p align="center"><img alt="arquitecture diagram" src="assets/arq.svg"></p>

| Service | URL | Description |
| :-- | :-- | :-- |
| Elixir App | <http://localhost:4000> | API-REST, GraphiQL and/or Web server |
| Postgres DB | <http://localhost:5432> | Relational database server |
| pgAdmin | <http://localhost:5050> | Database management tool |
| Auth0 | <https://dev-tenant.us.auth0.com:433> | Identity management platform |
| Open AI | <https://api.openai.com/v1:433> | AI Assistant service |
| Stripe | <https://api.stripe.com:433> | Payment service provider |

## How it works

The workbench has two parts:

- **`wb.sh`**: a thin Docker wrapper. It builds the development image, runs the containers, and drives the project lifecycle (`new`, `setup`, `up`, `delete`…). It never edits Elixir code.
- **`igniter/`**: the `workbench_igniter` Elixir package. It holds one installer task per feature (`mix workbench.install.healthcheck`, `.rest`, `.exdoc`, `.auth0`…) plus the `mix workbench.setup` umbrella task that composes them from the `config.conf` flags. All changes are applied as a single atomic patch set over the project's AST, and every installer is idempotent.

During project creation the workbench directory is mounted read-only at `/app/workbench` inside the containers, and a conditional dependency is registered in the generated `mix.exs`: when the workbench is mounted the igniter tasks are available; when it is not, the project is completely self-contained.

```text
workbench/                  ← this directory, permanent
├── wb.sh                   ← Docker wrapper script
├── config.conf             ← project & containers configuration
├── scripts/                ← entrypoint, compose & Dockerfile templates
├── igniter/                ← workbench_igniter package (tasks & templates)
└── _workspace/             ← WORKSPACE_PATH: the generated project
```

---

## Configuration

1. Give execution permissions to the `./wb.sh` file (This step only needs to be performed once):

    ```sh
    sudo chmod +x wb.sh
    ```

1. Modify the `./config.conf` file in order to configure the project name, the workspace project and the features specifications to be applied upon creation.
  The project will be generated into a specific target directory (`WORKSPACE_PATH`).

  For complete configuration instruccions consult: [Configuration File](./CONFIG.md).
  
1. Make sure [Docker Desktop](https://www.docker.com/products/docker-desktop/) is running before running any script command.

## Create a new project

1. Run the following command:

    ```sh
    ./wb.sh new
    ```

    This command generates a new Phoenix project in the workspace directory and runs `mix workbench.setup` inside the container, which applies the configuration and installs the features enabled in `config.conf`: schemas, changesets, context functions, controllers, routes, tests, migration files and documentation, when applicable.

    It can accept all option flags from the task `mix phx.new` like `--no-html` or `--no-ecto` (Full task [phx.new](https://hexdocs.pm/phoenix/Mix.Tasks.Phx.New.html) documentation).

## Features

Features can be installed at any time on the existing project — not only at creation:

```sh
./wb.sh add [FEATURE] [OPTIONS]
```

Replace `[FEATURE]` with one of the workbench installers:
  
- `healthcheck`
- `rest`
- `graphql`
- `coveralls`
- `exdoc`
- `enhancements`
- `auth0`
- `openai`
- `credo`
- `githooks`
- `exmachina`
- `mock`
- `exdebug`
- `psql_extras`
- `osmon`.
  
Optional `[OPTIONS]` are passed to the corresponding `mix workbench.install.FEATURE` task. For example:

```sh
./wb.sh add healthcheck --endpoint /status
```

Every installer is idempotent: running it on a project that already has the feature is a safe no-op.

## Deployment

1. This step is only required when deploying the service for the first time, a database reset is needed or the database container is detroyed. This command drops the project database (if any), creates a new one and run a seeding script:

    ```sh
    ./wb.sh setup [-e, --env ENV]
    ```

1. Once having a configured database, run the following command to deploy the service along with its configured required services and tools.

    ```sh
    ./wb.sh up [-e, --env ENV]
    ```

In both commands the flag `[-e, --env ENV]` is optional. The argument `ENV` can be **dev**, **prod** or other, it corresponds to the desired enviroment configuration to be deployed, by default is **dev**.

### Custom entrypoint

There is the possibility of deploying the application by executing custom server initialization commands:

```sh
./wb.sh run [ARGS...]
```

Replace `[ARGS...]` with the command(s) to be executed. For example, to run an elixir interactive console:

```sh
./wb.sh run iex -S mix phx.server
```

## Delete project

Use this command for deleting all workspace project files and the Docker compose project:

```sh
./wb.sh delete
```

> ⚠️ **Warning**: This action is destructive. Once executed, the workspace project files will be deleted, and neither the files nor the docker containers can be recovered. The workbench itself is never touched. Before proceeding, make sure you are absolutely certain that you want to remove them.

## Maintenance

### Private Github Registry Images

In order to download private github registry images, you need to login to GitHub using a username and a token (classic, not fine-grained) and have the rquired access level to the resource. To do this, execute the following command:

```sh
./wb.sh login [GITHUB_USER] [ACCESS_TOKEN]
```

Replace `[GITHUB_USER]` and `[ACCESS_TOKEN]` with your corresponding user name and token. How to generate a token: [Personal Access Token (classic)](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-personal-access-token-classic)

### Demo

This command runs the **new**, **setup**, **up**, and **delete** commands consecutively for demonstration purposes:

```sh
./wb.sh demo [-e, --env ENV]
```

The flag `[-e, --env ENV]` is optional. The argument `ENV` can be **dev**, **prod** or other, it corresponds to the desired enviroment configuration to be deployed, by default is **dev**.

> ⚠️ **Warning**: This action is destructive. Once executed, the workspace project files (if any) will be deleted, new ones will be created and finally deleted again and cannot be recovered. Before proceeding, make sure is safe to remove them if there is any.

### Reset Docker

Use this command in order to stop all containers and prune Docker. It's like a Docker data brute-force reset:

```sh
./wb.sh prune
```

> ⚠️ **Warning**: This action is destructive. Once executed, all Docker resources (not just the project's resources, but ALL resources in Docker) images, containers, volumes, networks, cache, etc.) will no longer exist and cannot be recovered, only rebuilt. Before proceeding, make sure you are absolutely certain that you want to remove them.

### Help

Shows the workbech script help section:

```sh
./wb.sh help
```

## License

This software is released under the [MIT](https://mit-license.org/) license.

Permission is granted to use, copy, modify, and distribute the code in both commercial and non-commercial projects. It only requires that the copyright notice and permission statement be maintained in all copies. No warranties are provided and the authors bear no liability.

Copyright © 2024 José Luis Pamplona Stoever.
