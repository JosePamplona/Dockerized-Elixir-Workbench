# The console's image: the workbench's own toolchain (Elixir, Phoenix's
# generator, git) plus the Docker CLI with its buildx and compose
# plugins, since the console drives the host's Docker through its
# socket, mounted by `./wb.sh console`. The three come from Docker's own
# apt repository for this Debian, the CLI without the daemon: the
# client negotiates its API with whatever engine answers the socket,
# so nothing here need match the host's versions. They used to be
# static binaries pinned to the host's, and buildx was not among them,
# which sent every build from in here through the deprecated legacy
# builder, warning as it went.
ARG TOOLCHAIN=workbench:1.19.2-28.1
FROM ${TOOLCHAIN}

USER root
RUN apt-get update -y && \
    apt-get install -y ca-certificates curl && \
    install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc && \
    . /etc/os-release && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc]" \
      "https://download.docker.com/linux/debian ${VERSION_CODENAME} stable" \
      > /etc/apt/sources.list.d/docker.list && \
    apt-get update -y && \
    apt-get install -y docker-ce-cli docker-buildx-plugin docker-compose-plugin && \
    apt-get clean && \
    rm -f /var/lib/apt/lists/*_*
# The console compiles into its own two volumes. It is the one project
# here that still needs Mix pointed at them: its source is mounted at
# the workbench's own host path, which no image can know, so there is
# no directory in this image for a fresh volume to take its ownership
# from. A workspace has one (/app/src) and needs none of this — its
# volumes simply cover its _build and deps, and Mix is told nothing.
# The workspace rides in this container too, at /app/src, with the
# workbench's own build volume and the deps it shares with the app
# service over _build and deps: the resident — the project's BEAM
# beside the console — and the mix that wb.sh runs in here compile
# into that build, never into the app's. Which is why `Console.Resident`
# and wb.sh clear these two for those runs: inherited, they would send
# the workspace's compilation into the console's build instead.
RUN mkdir -p /app/console/build /app/console/deps && chown -R elixir:elixir /app/console
ENV MIX_BUILD_ROOT=/app/console/build \
    MIX_DEPS_PATH=/app/console/deps
USER elixir

# Development mode: the source is mounted, the server reloads on change.
CMD ["sh", "-c", "mix deps.get && mix phx.server"]
