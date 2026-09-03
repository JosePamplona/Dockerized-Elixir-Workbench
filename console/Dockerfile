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
# The console compiles into its own two volumes, apart from the
# toolchain's /app/build and /app/deps: those two are the *workspace's*
# volumes here, mounted at the same paths the app service sees them,
# so the resident — the project's BEAM beside the console — finds what
# the app compiled and never recompiles it for a path that moved.
RUN mkdir -p /app/console/build /app/console/deps && chown -R elixir:elixir /app/console
ENV MIX_BUILD_ROOT=/app/console/build \
    MIX_DEPS_PATH=/app/console/deps
USER elixir

# Development mode: the source is mounted, the server reloads on change.
CMD ["sh", "-c", "mix deps.get && mix phx.server"]
