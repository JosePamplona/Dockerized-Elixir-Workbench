# The console's image: the workbench's own toolchain (Elixir, Phoenix's
# generator, git) plus the Docker CLI and the compose plugin, since the
# console drives the host's Docker through its socket, mounted by
# `./wb.sh console`. Static binaries from Docker's own downloads, pinned
# by wb.sh to the host's versions, so the CLI in here and the daemon out
# there speak the same API.
ARG TOOLCHAIN=workbench:1.19.2-28.1
FROM ${TOOLCHAIN}
ARG DOCKER_VERSION=28.1.1
ARG COMPOSE_VERSION=2.35.1

USER root
RUN apt-get update -y && \
    apt-get install -y curl && \
    apt-get clean && \
    rm -f /var/lib/apt/lists/*_* && \
    curl -fsSL "https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_VERSION}.tgz" | \
      tar -xz -C /usr/local/bin --strip-components=1 docker/docker && \
    mkdir -p /usr/local/lib/docker/cli-plugins && \
    curl -fsSL -o /usr/local/lib/docker/cli-plugins/docker-compose \
      "https://github.com/docker/compose/releases/download/v${COMPOSE_VERSION}/docker-compose-linux-x86_64" && \
    chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
USER elixir

# Development mode: the source is mounted, the server reloads on change.
CMD ["sh", "-c", "mix deps.get && mix phx.server"]
