# The console's image (dew-console:WORKBENCH-HASH): the workbench's
# image with the console compiled into it as a release,
# at /app/console/release. The image stays the workbench's because the
# console runs wb.sh in its own container — the mix and git of a job,
# the resident — so mix, the installer and the Docker CLI have to be
# there; what the release changes is how the console itself starts:
# nothing to fetch or compile, seconds, and no code compiled through the
# bind mount. Built by './wb.sh console' when the daemon has no image for
# the sources as they are: the tag carries the workbench's version and a
# hash of the context (.dockerignore says what that is), of the image
# below and of the path below, so a base or a source that changed is a
# new tag, and the old one goes. Which workbench image it was built on
# is in the label, for 'docker inspect'.
# The context is the workbench's root, not this directory, because the
# package is a path dependency beside it (../igniter): that is why the
# .dockerignore is there too. Two build arguments, no defaults on
# purpose, built from the root:
#
#   docker build --file console/Dockerfile \
#     --build-arg WORKBENCH_IMAGE=dew-ex1.19.6-erl28.5.0.7-node24-phx1.8.15:0.13.0 \
#     --build-arg WORKBENCH_PATH=/home/me/workbench .
#
# WORKBENCH_PATH is the workbench's absolute path on the host, and the
# sources are compiled *at that path*: the console mounts the workbench
# there at run time, and the package reads a cartridge's CHANGELOG.md
# and NEED.md at run time off the directory it was compiled in
# (WorkbenchIgniter.Feature, @cartridge_dir). Compiled anywhere else,
# every box would have no version and no need.
ARG WORKBENCH_IMAGE

# --- Build: the release, at the workbench's path -----------------------------

FROM ${WORKBENCH_IMAGE} AS build

ARG WORKBENCH_PATH
ENV MIX_ENV=prod \
    HOME=/home/elixir

USER root
RUN mkdir -p ${WORKBENCH_PATH}/console ${WORKBENCH_PATH}/igniter && \
    chown -R elixir:elixir ${WORKBENCH_PATH}
USER elixir

WORKDIR ${WORKBENCH_PATH}/console

# The dependencies first, on their own layer: a change to the sources
# below leaves it cached, and only mix.exs or mix.lock fetch again. The
# package is a path dependency, compiled with the sources, not here.
COPY --chown=elixir:elixir console/mix.exs console/mix.lock ./
COPY --chown=elixir:elixir igniter/mix.exs ../igniter/
RUN mix deps.get --only prod && \
    mix deps.compile --skip-local-deps

COPY --chown=elixir:elixir igniter ../igniter
COPY --chown=elixir:elixir console ./
RUN mix compile && \
    mix assets.deploy && \
    mix release

# --- Run: the workbench's image, the release in it ---------------------------

FROM ${WORKBENCH_IMAGE}

ARG WORKBENCH_IMAGE
ARG WORKBENCH_PATH
LABEL org.opencontainers.image.base.name="${WORKBENCH_IMAGE}"
COPY --from=build --chown=elixir:elixir \
    ${WORKBENCH_PATH}/console/_build/prod/rel/console /app/console/release

# No command of its own: './wb.sh console' starts the release, with
# PHX_SERVER and SECRET_KEY_BASE in the environment, and the workbench
# mounted where it was compiled.
