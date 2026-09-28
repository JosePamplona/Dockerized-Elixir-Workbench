#!/bin/bash
# Dockerized workbench script (Igniter edition)
# v0.12.0
#
# Thin Docker wrapper: project creation and Elixir configuration are
# delegated to the :workbench_igniter package (igniter/) via
# `mix workbench.setup` and `mix workbench.install.*` tasks.
#
# The workbench lives permanently in this directory; projects are generated
# into WORKSPACE_PATH (config.conf). Each workspace owns its three
# compose files — baked with real values (name, ports, images) at
# creation — which are the source of truth for its orchestration: several
# workspaces can run simultaneously without port conflicts. The workbench
# is mounted read-only at /app/workbench so the igniter tasks are available
# inside the containers.

# CONFIGURATION ================================================================

  # The workbench is wherever this script lives; run everything from here.
  # BASH_SOURCE and not $0, so the path holds when the script is sourced
  # instead of run. WORKBENCH_SELF is this file, absolute: the cd below
  # leaves a relative $0 pointing nowhere, and two readers open the
  # script itself — the version off line 3, the help's name off line 2.
  WORKBENCH_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
  WORKBENCH_SELF="$WORKBENCH_PATH/$( basename "${BASH_SOURCE[0]}" )"
  cd "$WORKBENCH_PATH" || exit 1

  # Environment overrides survive config.conf (e.g. WORKSPACE_PATH=./x ./wb.sh),
  # for a second workspace beside the configured one without editing it.
  WORKSPACE_PATH_OVERRIDE="$WORKSPACE_PATH"
  PROJECT_NAME_OVERRIDE="$PROJECT_NAME"

  # -y|--yes before the command answers every confirmation, for scripts
  # and for whatever drives the workbench without a terminal. Exported,
  # so 'demo' hands it to the commands it runs.
  if [[ "$1" == "-y" ]] || [[ "$1" == "--yes" ]]; then WB_YES=true; shift; fi
  export WB_YES="${WB_YES:-false}"

  SCRIPT_CONFIG_FILE="config.conf"
  # shellcheck source=config.conf disable=SC1091  # followed under -x; a plain run need not read the user's config
  source "./$SCRIPT_CONFIG_FILE"

  # Workbench configuration --------------------------------------------------

    WORKBENCH_VERSION=$( sed '3!d' "$WORKBENCH_SELF" | sed -n 's/^.*v\(.*\).*/\1/p' )
    PROJECT_NAME="${PROJECT_NAME_OVERRIDE:-$PROJECT_NAME}"

    # Workspace: directory where the project is generated (volume mount
    # point). Relative paths are resolved from the workbench directory.
    WORKSPACE_PATH="${WORKSPACE_PATH_OVERRIDE:-$WORKSPACE_PATH}"
    WORKSPACE_PATH="${WORKSPACE_PATH:-./_workspace}"
    case "$WORKSPACE_PATH" in
      /*) ;;
      *) WORKSPACE_PATH="$WORKBENCH_PATH/${WORKSPACE_PATH#./}" ;;
    esac

    # Directories - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    SCRIPTS_DIR="scripts"

    # Script files - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    # The project's dev dockerfile is LOCAL_DOCKERFILE, baked from its seed
    # into scripts/ on each `new`, then copied into the workspace under
    # the same name. The workbench's image is built straight from
    # WORKBENCH_DOCKERFILE, with the stack and the installer as build
    # arguments.
    PROD_DOCKERFILE="Dockerfile"
    PROD_COMPOSE_FILE="docker-compose.prod.yml"
    SCALED_COMPOSE_FILE="docker-compose.scaled.yml"
    # Replicas the scaled deployment starts unless --replicas says
    # otherwise; the balancer sits in front of them.
    DEFAULT_REPLICAS=4
    LOCAL_DOCKERFILE="Dockerfile.local"
    LOCAL_DOCKERFILE_SEED="Dockerfile.seed.local"
    WORKBENCH_DOCKERFILE="Dockerfile.workbench"
    COMPOSE_FILE="docker-compose.yml"
    # The entrypoint script runs from the mounted workbench (workdir /app).
    CONTAINER_ENTRYPOINT=(bash workbench/scripts/entrypoint.sh)
    # TTY flags only when running from an interactive terminal (CI-safe).
    if [ -t 0 ]
    then DOCKER_TTY_FLAGS=(--tty --interactive)
    else DOCKER_TTY_FLAGS=()
    fi
    # Colour without a terminal. The console runs this script on a pipe,
    # and there mix, hex, git and compose turn their colours off on their
    # own — while the console's page turns ANSI into spans and would
    # show them. WB_ANSI=always asks each of them for colour anyway:
    # Elixir by the option the VM reads before anything else, git by the
    # config it takes from the environment, compose by its own variable.
    # From a terminal, or unset, nothing changes. Docker's build output
    # stays plain: BuildKit colours only a real terminal.
    # Kept as NAME=VALUE pairs, like the git identity below: a container
    # gets each as --env ("${ARRAY[@]/#/--env=}"), and a run in this very
    # container (toolchain_env) gets them through env.
    if [[ "${WB_ANSI:-}" == "always" ]]
    then
      COLOR_ENV=("ELIXIR_ERL_OPTIONS=-elixir ansi_enabled true")
      GIT_COLOR_ENV=(GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=color.ui GIT_CONFIG_VALUE_0=always)
      export COMPOSE_ANSI=always
    else
      COLOR_ENV=()
      GIT_COLOR_ENV=()
    fi

    # Elixir project files - - - - - - - - - - - - - - - - - - - - - - - - - -
    # What a name comes to: the app and module of the Elixir project, the
    # compose project, the dev image. 'new' calls it again once --name
    # has been read, which is the only place a name is given at all
    # (2026-09-26): config.conf named the next project until then, and
    # went on naming it after the project existed and had a name of its
    # own.
    # A workspace with no project has no name either, and there is no
    # file naming the next one any more: the derived names fall back to
    # 'app' so that what is named after them stays a name a daemon
    # takes — the build volumes are "${ELIXIR_PROJECT_NAME}_build", and
    # empty made '_build', which Docker refuses (a volume starts with a
    # letter or a digit). It is the fallback the console already used.
    # PROJECT_NAME itself stays empty, which is what 'new' asks about.
    name_project() {
      LOWER_CASE=$( echo "${PROJECT_NAME:-app}" | tr '[:upper:]' '[:lower:]' )
      ELIXIR_PROJECT_NAME=$( echo "$LOWER_CASE" | tr ' ' '_' )
      APP_NAME=$( echo "$LOWER_CASE" | tr ' ' '-' )
      LOCAL_IMAGE="$APP_NAME:local"
    }
    name_project
    MIX_FILE="mix.exs"
    EXISTING_PROJECT=$(
      [ -f "$WORKSPACE_PATH/$MIX_FILE" ] && echo true || echo false
    )

  # Docker ---------------------------------------------------------------------

    # APP_NAME and LOCAL_IMAGE are name_project's, above: the workspace's
    # own dev image name, the app's, built from the project's
    # Dockerfile.local by its compose, with the workbench or without. The
    # workbench's own runs never use it (WORKBENCH_IMAGE).
    # The installer setting (config.conf), kept apart from the version
    # resolved below: the setting says what the NEXT project is generated
    # with, PHX_NEW_VERSION says what THIS workspace was. Only 'new'
    # reads the setting and nothing ever writes it back — the record of a
    # creation belongs to the workspace it created, not to a file that
    # names the next one. Empty is the ordinary case: hex decides.
    PHX_NEW_SETTING="$PHX_NEW_VERSION"
    PHX_NEW_VERSION=""
    # An existing workspace names itself: its compose carries the compose
    # project name and the dev image baked at creation, so every command
    # but the creating ones reads them from there — config.conf may since
    # have moved on to name the next project, and several workspaces can
    # be driven from one workbench.
    if [[ "$EXISTING_PROJECT" == true ]] && [ -f "$WORKSPACE_PATH/$COMPOSE_FILE" ] && \
       [ "$1" != "new" ]
    then
      ELIXIR_PROJECT_NAME=$(
        sed -n 's/^name: //p' "$WORKSPACE_PATH/$COMPOSE_FILE" | head -n 1
      )
      LOCAL_IMAGE=$(
        sed -n '/^  app:/,/^  [a-z]/{s/^    image: //p}' \
          "$WORKSPACE_PATH/$COMPOSE_FILE" | head -n 1
      )
      APP_NAME="${LOCAL_IMAGE%:local}"
      # …and for the Phoenix installer that generated it. There is no
      # setting for it: 'new' asks hex for the newest phx_new (or takes
      # --phx-new) and stamps it into the workspace's own
      # Dockerfile.local, which is read back here. It is the generator
      # the base cartridges take their delta with, so it can be neither
      # a moving target nor one global default shared by workspaces
      # created months apart.
      PHX_NEW_VERSION=$(
        sed -n 's/^ARG PHX_NEW="\(.*\)"$/\1/p' \
          "$WORKSPACE_PATH/$LOCAL_DOCKERFILE" 2> /dev/null | head -n 1
      )
    # A project with no compose was not created here — it is 'adopt''s
    # to take in — and names itself by its own mix.exs: the app is the
    # compose project and the image to be, never config.conf's name for
    # the next project.
    elif [[ "$EXISTING_PROJECT" == true ]] && [ "$1" != "new" ]; then
      PROJECT_APP=$(
        sed -n 's/^ *app: :\([a-z0-9_]*\),.*/\1/p' "$WORKSPACE_PATH/$MIX_FILE" | head -n 1
      )
      if [ -n "$PROJECT_APP" ]; then
        ELIXIR_PROJECT_NAME="$PROJECT_APP"
        APP_NAME="${PROJECT_APP//_/-}"
        LOCAL_IMAGE="$APP_NAME:local"
      fi
    fi
    # The workbench's image, where its own work on a workspace runs —
    # generation, cartridges, git, the catalog — and the console: shared
    # by every workspace of the same stack and installer. Named
    # dew-exELIXIR-erlOTP-nodeNODE-phxVERSION:WORKBENCH (since
    # 2026-09-15; Node in it since 2026-09-28, the one part of the
    # stack that is not hexpm's tag): the stack and the installer name
    # the repository, so 'docker images'
    # lists one line per pair, and the workbench's own version is the
    # tag, so a new workbench builds its own and an old one keeps what
    # it ran on. Another installer is another image, and a workspace
    # keeps the one that made its project. With no project to name one
    # — an empty workspace, or one made before the stamp — the image is
    # the installer config.conf names, or else the newest one this
    # daemon already has for the stack at this version: the one the
    # console runs on, and the catalog is read with, before 'new'
    # decides. None built yet, the name carries no installer and nothing
    # answers to it: 'console' and 'new' resolve one first.
    IMAGE_REPOSITORY="dew"
    IMAGE_STACK="ex${ELIXIR_VERSION}-erl${ERLANG_VERSION}-node${NODE_VERSION}"
    IMAGE_TAG="$WORKBENCH_VERSION"
    if [ -n "$PHX_NEW_VERSION" ]
    then WORKBENCH_IMAGE="$IMAGE_REPOSITORY-$IMAGE_STACK-phx$PHX_NEW_VERSION:$IMAGE_TAG"
    elif [ -n "$PHX_NEW_SETTING" ]
    then WORKBENCH_IMAGE="$IMAGE_REPOSITORY-$IMAGE_STACK-phx$PHX_NEW_SETTING:$IMAGE_TAG"
    else
      WORKBENCH_IMAGE=$(
        docker images --format '{{.Repository}}' "$IMAGE_REPOSITORY-$IMAGE_STACK-phx*:$IMAGE_TAG" 2> /dev/null | \
          sed -n "s/^$IMAGE_REPOSITORY-$IMAGE_STACK-phx//p" | sort -V | tail -n 1
      )
      if [ -n "$WORKBENCH_IMAGE" ]
      then WORKBENCH_IMAGE="$IMAGE_REPOSITORY-$IMAGE_STACK-phx$WORKBENCH_IMAGE:$IMAGE_TAG"
      else WORKBENCH_IMAGE="$IMAGE_REPOSITORY-$IMAGE_STACK:$IMAGE_TAG"
      fi
    fi
    # Ports the services bind INSIDE the containers; the host ports are
    # chosen per workspace and mapped to these in its compose file.
    # The app's alone: what a cartridge's service listens on is the
    # cartridge's to say (its compose/1), and nothing here names one.
    APP_INTERNAL_PORT="4000"
    SOURCE_CODE_VOLUME="$WORKSPACE_PATH:/app/src"
    # Where Mix compiles. Two sides compile the workspace, and never
    # into the same directory: the app service into the compose's
    # `build` volume, and every run of the workbench — new, add, the
    # reads, the console's resident — into a volume of its own,
    # <project>_workbench_build. The app's build is written by the app
    # alone, so no two BEAMs ever compile into one _build, whatever the
    # stack's Mix does about locking. The two sides share deps/ (the
    # compose's `deps` volume): sources only, since what compiles from
    # them lands in each side's _build; only deps.get writes there, and
    # Mix locks the deps directory since 1.18 (the floor below). Both
    # volumes cover the directories Mix looks for on its own, inside the
    # source mount — Mix is told nothing, and neither is anything else
    # that assumes where deps/ is (see the toolchain dockerfile) — so
    # nothing compiles through the bind mount. The one price: the first
    # up after new compiles the project once more, into the app's own.
    WORKBENCH_BUILD_VOLUME="${ELIXIR_PROJECT_NAME}_workbench_build"
    BUILD_VOLUMES=(--volume "$WORKBENCH_BUILD_VOLUME:/app/src/_build" --volume "${ELIXIR_PROJECT_NAME}_deps:/app/src/deps")
    WORKBENCH_VOLUME="$WORKBENCH_PATH:/app/workbench:ro"
    # Where the workspace is on THIS side, when this side is the
    # toolchain. './wb.sh console' runs the console on the workbench's
    # image and mounts the workspace in it at /app/src — the path the
    # one-off containers and the app service mount it at — with the
    # workbench's build volume and the shared deps over its _build and
    # deps, and says so with these three. With them set
    # (toolchain_here), the runs that need nothing but the toolchain —
    # mix on the project, git that writes, the entrypoint's new and add
    # — happen here instead of in a container of their own: same image,
    # same mounts, same command, a container start less each; and a Mix
    # that compiles from the same source path the app compiles from,
    # into the workbench's own build. The path alone
    # does not decide: the mounts were made for one workspace and one
    # volume name, and config.conf may since name another — then the
    # mounts are not this workspace's, and the run goes to a container
    # as it always has. Nothing on a host sets these, and a host with
    # mix on it does not qualify: it would compile the workspace in
    # place, which is what the volumes exist to prevent.
    WORKSPACE_MOUNT="${WORKSPACE_MOUNT:-}"

  # Git ------------------------------------------------------------------------

    # Who signs the commits the workbench makes in the workspace: the
    # first one after 'new', one per 'add' — so 'eject' can revert that
    # one alone — and the revert itself. GIT_IDENTITY=user (config.conf)
    # takes the host's git identity when git is there and has one, and
    # falls back to the workbench's own otherwise; =workbench always
    # signs as the workbench. The commits run inside the toolchain
    # container, where the project's git hooks can run mix.
    WORKBENCH_GIT_NAME="Dockerized Elixir Workbench"
    WORKBENCH_GIT_EMAIL="wb.sh@localhost"
    GIT_NAME="$WORKBENCH_GIT_NAME"
    GIT_EMAIL="$WORKBENCH_GIT_EMAIL"
    if [[ "${GIT_IDENTITY:-user}" == "user" ]] && command -v git > /dev/null 2>&1; then
      HOST_GIT_NAME=$(git -C "$HOME" config --get user.name 2>/dev/null)
      HOST_GIT_EMAIL=$(git -C "$HOME" config --get user.email 2>/dev/null)
      if [ -n "$HOST_GIT_NAME" ] && [ -n "$HOST_GIT_EMAIL" ]; then
        GIT_NAME="$HOST_GIT_NAME"
        GIT_EMAIL="$HOST_GIT_EMAIL"
      fi
    fi
    GIT_IDENTITY_ENV=(
      GIT_AUTHOR_NAME="$GIT_NAME" GIT_AUTHOR_EMAIL="$GIT_EMAIL"
      GIT_COMMITTER_NAME="$GIT_NAME" GIT_COMMITTER_EMAIL="$GIT_EMAIL"
    )

  # Format codes -------------------------------------------------------------

    # Colour when a terminal will read it — stdout a tty, NO_COLOR unset
    # (no-color.org), TERM not dumb — or when WB_ANSI=always asks for it
    # anyway, as the console's jobs do (its page turns the codes into
    # spans). Piped, redirected or captured, the output is plain text:
    # 'help | less' and a script reading 'status' get no codes. Until
    # 2026-09-16 the codes went out whatever read them.
    if { [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-}" != "dumb" ]; } || [ "${WB_ANSI:-}" == "always" ]
    then
      # Colors
      C1="\x1B[38;5;1m" # Dark-red
      C2="\x1B[4;34m"   # Blue underline
      # Format
      B="\x1B[1m" # Bold
      R="\x1B[0m" # Reset
    else
      C1=""; C2=""; B=""; R=""
    fi

    Li=$C2 # Link color

# FUNCTIONS ====================================================================

  # If echo handles -e option, overrides the command
  if [[ "$(echo -e)" == "" ]]; then echo() { command echo -e "$@"; } fi

  # confirm <MESSAGE>
    # Prints MESSAGE and spects input prompt for continue or exit the script
  confirm() {
    echo "⚠️  ${B}Warning${R} $*"
    if [[ "$WB_YES" == true ]]; then echo "Continuing (--yes)."; echo; return; fi
    read -r -n 1 -p $'Should continue? [y/N] ' INPUT
    if [ "$INPUT" != "y" ]; then exit 0; fi
    echo
  }

  # args_error <ERROR>
    # Prints a default messages for argument errors.
  args_error() {
    if   [[ "$1" == "missing" ]];  then echo "Missing arguments."
    elif [[ "$1" == "too_many" ]]; then echo "Too many arguments."
    elif [[ "$1" == "invalid" ]];  then echo "Invalid argument."
    elif [ "$1" != "" ];         then echo "$@"
    else echo "Argument error."; fi
    exit 1
  }

  # env_flag_error
    # --env selected a compose file until it also had to name the scaled
    # deployment, which is not an environment at all. The deploy commands
    # take --deploy now, and say so instead of quietly accepting the old
    # spelling.
  env_flag_error() {
    terminate \
      "Deployments are selected with ${B}--deploy${R}, not --env:" \
      "  ./$(basename "$0") $COMMAND_NAME --deploy dev|prod|scaled"
  }

  # warning <MESSAGE>
    # Prints a warning without interrupting: the command carries on.
  warning() { echo "⚠️  ${B}Warning${R} $*"; echo; }

  # terminate <MESSAGE>
    # Print error and terminate with sigerr 1
  terminate() { echo "${B}${C1}Error${R} $*"; echo; exit 1; }

  # first_free_port <BASE>
    # Prints the first host port available starting from BASE: one
    # nothing listens on now, and no other workspace has baked into a
    # compose file of its own. A port is chosen once, when a file is
    # baked, and the file keeps it — so a workspace that is down holds
    # its ports as surely as one that is up, and two workspaces created
    # while each other slept used to be given the same one, to collide
    # on their first up together (seen 2026-09-07: six on 4001).
  first_free_port() {
    local port=$1 baked
    baked=$(baked_ports)
    while port_held "$port" || grep -qx "$port" <<< "$baked"; do
      port=$((port + 1))
    done
    echo "$port"
  }

  # in_console
    # Whether this process runs in the console's container: 'console'
    # gives it WORKSPACE_MOUNT_PATH, and nothing else does.
  in_console() { [ -n "${WORKSPACE_MOUNT_PATH:-}" ]; }

  # Jobs -----------------------------------------------------------------------

    # The CPU priority of what compiles: JOB_NICENESS (config.conf), a
    # Linux niceness from 0 to 19, 10 when the file does not say. A
    # compile takes every core it finds — an 'add ash' held seven to
    # nine of twelve for minutes (2026-09-25) — and in the console's
    # container it runs beside the console itself, on the same cores
    # as the browser reading it; at the same priority the page went
    # slow and its socket dropped. Niced, the compiler still takes
    # every idle core and gives way the moment something else asks.
    # NICE_CMD goes in front of the mix that compiles here
    # (entrypoint_here); a run in a container of its own gets the same
    # proportion as CPU shares, the cgroup's weight (1024 at 0, about
    # 110 at 10 — the kernel's own table for nice, 1.25 per step).
    # Only what compiles: the readers (status, git) stay at 0, they are
    # short and the console waits on them. Negative would need root.
    JOB_NICENESS="${JOB_NICENESS:-10}"
    [[ "$JOB_NICENESS" =~ ^[0-9]+$ ]] && [ "$JOB_NICENESS" -le 19 ] || \
      terminate "JOB_NICENESS must be 0 to 19 in $SCRIPT_CONFIG_FILE, not '$JOB_NICENESS'."
    NICE_CMD=()
    CPU_SHARES_FLAG=()
    if [ "$JOB_NICENESS" -gt 0 ]; then
      NICE_CMD=(nice -n "$JOB_NICENESS")
      CPU_SHARES_FLAG=(--cpu-shares "$(awk "BEGIN { printf \"%d\", 1024 / (1.25 ^ $JOB_NICENESS) }")")
    fi

  # port_held <PORT>
    # Whether host port PORT is taken. From the host, a connect to its
    # loopback says so, whoever holds it. From the console's container
    # the loopback is the container's own — the console itself listens
    # on 4000 there, which is why every project made from it was given
    # 4001 until 2026-09-16 — so there the answer is Docker's: the host
    # ports its containers publish, read over the socket the console
    # mounts. A host process holding a port stays unseen from a
    # container; 'up' from the host still sees it.
  port_held() {
    if in_console
    then docker ps --format '{{.Ports}}' 2>/dev/null | grep -qE "[:]$1->"
    else (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null
    fi
  }

  # baked_ports
    # The host ports every OTHER workspace under _workspaces/ publishes
    # in its compose files, one per line: what first_free_port must not
    # give again. A workspace kept elsewhere is not seen; its ports are
    # its own to keep apart.
  baked_ports() {
    local file here
    here=$(cd "$WORKSPACE_PATH" 2>/dev/null && pwd -P)
    for file in "$WORKBENCH_PATH"/_workspaces/*/docker-compose*.yml; do
      [ -f "$file" ] || continue
      [[ "$(cd "$(dirname "$file")" && pwd -P)" == "$here" ]] && continue
      sed -n 's/^ *- \([0-9]*\):[0-9]*$/\1/p' "$file"
    done | sort -un
  }

  # refuse_old_pod <COMPOSE_FILE>
    # The pod's service is 'pod' since 2026-09-16; it was 'network'. A
    # deployment that was up when its file was baked again still has
    # the old container, and it holds the ports the new 'pod' would
    # publish: compose would fail on them after building. Said here,
    # with the way out — down, then up.
  refuse_old_pod() {
    grep -q '^  pod:' "$1" 2>/dev/null || return 0
    [ -z "$(docker ps -a -q --filter "label=com.docker.compose.project=$(compose_project_name)" \
      --filter "label=com.docker.compose.service=network" 2>/dev/null)" ] && return 0
    terminate \
      "This deployment's containers were made when the pod's service was named 'network';" \
      "$(basename "$1") names it 'pod' now, and the old container holds its ports." \
      "Bring the deployment down first (./$(basename "$0") down), then up again."
  }

  # check_ports <COMPOSE_FILE>
    # Before an up: every host port the file publishes must be free, or
    # already ours — the deployment that is up being raised again. One
    # another workspace's containers hold is named, with the workspace;
    # one a process on this host holds is said so. Both used to surface
    # as Docker's "port is already allocated", after the images built.
  check_ports() {
    local file="$1" port holder mine free
    mine=$(compose_project_name)
    # A process substitution, not a pipe into the loop: terminate must
    # end this shell, and in a pipeline it would only end the loop's.
    while read -r port; do
      port_held "$port" || continue
      holder=$(docker ps --format '{{.Label "com.docker.compose.project"}} {{.Ports}}' 2>/dev/null | \
        grep -E "[:]$port->" | cut -d' ' -f1 | head -n 1)
      [[ "$holder" == "$mine" ]] && continue
      free=$(first_free_port "$port")
      if [ -n "$holder" ]; then
        terminate \
          "Port $port, which $(basename "$file") publishes, is held by the '$holder' workspace's containers." \
          "Take that one down (./$(basename "$0") down there), or give this workspace another port:" \
          "change $port in the file's port line ($free is free) and run up again — the prod and" \
          "scaled files take the app port from docker-compose.yml on their next bake."
      else
        terminate \
          "Port $port, which $(basename "$file") publishes, is held by a process on this host." \
          "Free it, or change $port in the file's port line ($free is free) and run up again."
      fi
    done < <(sed -n 's/^ *- \([0-9]*\):[0-9]*$/\1/p' "$file" | sort -un)
  }

  # phx_new_versions
    # Every stable phx_new hex knows, newest first — the order hex
    # publishes them in. Pre-releases are dropped, as 'mix
    # archive.install hex phx_new' drops them: an rc is something a
    # person asks for by name, and --phx-new is where names go.
  phx_new_versions() {
    curl -fs "https://hex.pm/api/packages/phx_new" | \
      grep -o '"version":"[^"]*"' | cut -d'"' -f4 | grep -v -- '-'
  }

  # How far back 'resolve_phx_new' walks before giving up. It walks
  # release by release, not one probe per minor line, because the
  # requirement moves inside a line: phx_new 1.8.0 to 1.8.5 ask for
  # Elixir ~> 1.15 and 1.8.13 asks for ~> 1.17, so the newest of a line
  # answers only for itself, and rejecting a whole line on it would
  # refuse installers the stack can run. The number clears the current
  # 1.8 line (12 stable releases) with room to reach the one below it;
  # each candidate costs one hex call, and only the candidates before
  # the first that fits are ever paid for.
  PHX_NEW_CANDIDATES=25

  # resolve_phx_new
    # The newest stable phx_new this stack can run, into
    # PHX_NEW_VERSION. PHX_NEW_NEWEST and PHX_NEW_NEWEST_REQUIREMENT
    # keep hex's newest and what it asks of Elixir, so the caller can
    # say why it did not get that one. Returns 1 when hex does not
    # answer, or when nothing within reach runs here.
    #
    # Every release declares the Elixir it needs, so the first one this
    # stack satisfies is the answer — almost always hex's newest, for
    # the one call the pairing check would have made anyway. It walks
    # only when the stack is behind, which is exactly the case that had
    # no answer before: mix installs the newest and fails loading it,
    # and the workbench refused with the same verdict said earlier.
    # This is where the workbench parts from mix on purpose. Whatever it
    # resolves is stamped into the workspace; config.conf is not
    # written.
  resolve_phx_new() {
    local version requirement tried=0
    PHX_NEW_VERSION=""; PHX_NEW_NEWEST=""; PHX_NEW_NEWEST_REQUIREMENT=""

    for version in $(phx_new_versions); do
      [ $tried -lt $PHX_NEW_CANDIDATES ] || break
      tried=$((tried + 1))
      requirement=$(phx_new_elixir_requirement "$version")

      if [ -z "$PHX_NEW_NEWEST" ]
      then PHX_NEW_NEWEST="$version"; PHX_NEW_NEWEST_REQUIREMENT="$requirement"
      fi

      # A requirement hex did not answer is left unjudged, as
      # stack_satisfies leaves the shapes it cannot read: mix weighs the
      # same pair again when the image installs the archive.
      if [ -z "$requirement" ] || stack_satisfies "$requirement"
      then PHX_NEW_VERSION="$version"; return 0
      fi
    done

    return 1
  }

  # phx_new_elixir_requirement <VERSION>
    # The Elixir requirement a phx_new release declares in its own
    # mix.exs, as hex records it ('~> 1.17'). Empty when hex does not
    # answer: the check that reads it then stands aside.
  phx_new_elixir_requirement() {
    curl -fs "https://hex.pm/api/packages/phx_new/releases/$1" | \
      grep -o '"elixir":"[^"]*"' | cut -d'"' -f4
  }

  # phx_new_release_status <VERSION>
    # What hex says about a release, as an HTTP code: 200 for one that
    # exists, 404 for one that does not, '000' when hex cannot be
    # reached at all. A HEAD asks the only question here — whether the
    # release is there — and carries no body back for it.
  phx_new_release_status() {
    curl -s -I -o /dev/null -w '%{http_code}' \
      "https://hex.pm/api/packages/phx_new/releases/$1"
  }

  # require_stack_floor <ELIXIR_VERSION>
    # The floor of the stack, whatever the installer asks for: Mix locks
    # the build directory and the deps directory since Elixir 1.18. The
    # workbench compiles the workspace from two sides that share deps/
    # (each side has its own _build), and below 1.18 two deps.get at
    # once — the app on boot, a workbench run after an insert — could
    # write the same directory unguarded. Checked where the stack is
    # chosen ('stacks use') and where it is first built ('new').
  ELIXIR_FLOOR="1.18"
  require_stack_floor() {
    [[ "$(printf '%s\n' "$ELIXIR_FLOOR" "$1" | sort -V | head -n 1)" == "$ELIXIR_FLOOR" ]] || \
      terminate \
        "Elixir $1 is below the workbench's floor, $ELIXIR_FLOOR: since 1.18 Mix locks" \
        "the build and deps directories, which the workbench relies on to compile the" \
        "workspace from two sides. Pick a newer stack: ./$(basename "$0") stacks"
  }

  # warn_stack_floor <ELIXIR_VERSION>
    # The floor as a warning, for 'adopt': a project made elsewhere may
    # not compile on anything newer than the Elixir it was written for,
    # and the risk below the floor is one the reader can steer clear of
    # — never two deps.get at once. Asks before going on (--yes goes on).
  warn_stack_floor() {
    [[ "$(printf '%s\n' "$ELIXIR_FLOOR" "$1" | sort -V | head -n 1)" == "$ELIXIR_FLOOR" ]] || \
      confirm \
        "Elixir $1 is below the workbench's floor, $ELIXIR_FLOOR: Mix locks the build and" \
        "deps directories only since 1.18, and the workbench compiles the workspace from" \
        "two sides that share deps/. Below it, never run 'add', 'status' or the console" \
        "while the app is fetching its dependencies (on boot), or deps/ can be corrupted."
  }

  # stack_satisfies <REQUIREMENT>
    # True when ELIXIR_VERSION meets the requirement. Only hex's
    # '~> MAJOR.MINOR' is read — the form every phx_new release has
    # published — and it reads as '>= MAJOR.MINOR and < (MAJOR+1).0':
    # same major, minor no older. Any other shape (a three-part '~>', a
    # '>=', a range, a version this cannot take apart) is left unjudged
    # on purpose: mix checks the same thing again when the image
    # installs the archive, and refusing a good stack on a guess is
    # worse than the late error.
  stack_satisfies() {
    case "$1" in "~> "*) ;; *) return 0 ;; esac

    local floor="${1#\~> }"
    case "$floor" in *.*) ;; *) return 0 ;; esac

    local want_major="${floor%%.*}"
    local want_minor="${floor#*.}"
    local have_major="${ELIXIR_VERSION%%.*}"
    local have_minor="${ELIXIR_VERSION#*.}"; have_minor="${have_minor%%.*}"

    # Every part has to be there and be a plain number, or there is
    # nothing to compare — a three-part '~> 1.17.1' lands here, as its
    # minor arrives carrying the rest.
    local part
    for part in "$want_major" "$want_minor" "$have_major" "$have_minor"; do
      case "$part" in "" | *[!0-9]*) return 0 ;; esac
    done

    [ "$have_major" = "$want_major" ] && [ "$have_minor" -ge "$want_minor" ]
  }

  # check_phx_new_exists <VERSION>
    # Refuses a named installer hex does not have. Only a version
    # somebody typed reaches here — a resolved one came out of hex's own
    # list — and a typo has nothing to weigh against the stack: the
    # requirement comes back empty, the pairing check stands aside on
    # it, and the mistake travels three layers into the image build to
    # be reported by 'mix archive.install' about a file nobody wrote.
    # Only a 404 refuses: hex unreachable judges nothing, as everywhere
    # else here.
  check_phx_new_exists() {
    [[ "$(phx_new_release_status "$1")" == "404" ]] || return 0

    terminate \
      "There is no phx_new $1 on hex (${Li}https://hex.pm/packages/phx_new/versions${R})." \
      "Name one that exists ('./$(basename "$0") new --phx-new VERSION') or leave" \
      "PHX_NEW_VERSION empty in $SCRIPT_CONFIG_FILE for the newest that runs on this stack."
  }

  # check_stack_runs_phx_new <VERSION>
    # Refuses, before anything is built, a stack the installer cannot run
    # on. mix refuses it too — 'mix archive.install' stops when the
    # archive declares a newer Elixir than the image carries — but three
    # layers into a docker build and in its own words. hex knows the
    # requirement beforehand, so it is asked here, where the remedy is
    # the workbench's own: another stack, or another installer.
  check_stack_runs_phx_new() {
    local requirement
    requirement=$(phx_new_elixir_requirement "$1")

    [ -n "$requirement" ] || return 0
    stack_satisfies "$requirement" || terminate \
      "phx_new $1 needs Elixir $requirement, and this stack is $ELIXIR_VERSION." \
      "Move the stack up ('./$(basename "$0") stacks') or name an installer that" \
      "runs on this one ('./$(basename "$0") new --phx-new VERSION')."
  }

  # workspace_compose [COMMAND...]
    # Runs docker compose against the workspace's own compose file.
  workspace_compose() {
    docker compose --file "$WORKSPACE_PATH/$COMPOSE_FILE" "$@"
  }

  # compose_file_for <ENV>
    # Compose file each environment deploys with: the workspace's own
    # docker-compose.yml, docker-compose.prod.yml and
    # docker-compose.scaled.yml, all three baked at its birth
    # (2026-09-27; prod and scaled were baked by their first up, and
    # left uncommitted).
  compose_file_for() {
    case "$1" in
      scaled)  echo "$SCALED_COMPOSE_FILE" ;;
      prod)    echo "$PROD_COMPOSE_FILE" ;;
      *)       echo "$COMPOSE_FILE" ;;
    esac
  }

  # resolve_compose_file <ENV>
    # Sets COMPOSE_TARGET to the environment's compose file, or
    # terminates when it is not there (a workspace born before the three
    # were baked at birth, or a file removed by hand): 'bake' writes it.
    # It assigns instead of echoing on purpose:
    # called from a command substitution, 'terminate' would only exit the
    # subshell and its message would be captured as the file name.
  resolve_compose_file() {
    COMPOSE_TARGET="$WORKSPACE_PATH/$(compose_file_for "$1")"

    [ -f "$COMPOSE_TARGET" ] || terminate \
      "This workspace has no '$1' deployment ($(basename "$COMPOSE_TARGET")" \
      "does not exist). Bake it with: ./$(basename "$0") bake --deploy $1"
  }

  # app_is_running [FILE] [SERVICE]
    # Succeeds when the given service of the given deployment is up (exec
    # target). Defaults to the dev compose and its 'app' service.
  app_is_running() {
    local file_path="${1:-$WORKSPACE_PATH/$COMPOSE_FILE}"
    local service="${2:-app}"

    [ -n "$(
      docker compose --file "$file_path" \
        ps --status running --quiet "$service" 2>/dev/null
    )" ]
  }

  # --------------------------------------------------------------------------

  # wipe_workspace
    # Deletes every file and directory inside the workspace (the workbench
    # itself is never touched: it lives outside the workspace).
  wipe_workspace() {
    [ -d "$WORKSPACE_PATH" ] && \
    find "$WORKSPACE_PATH" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
  }

  # require_node_version
    # The Node major both images install (NODE_VERSION, since
    # 2026-09-28): a config.conf from before the line has none, and the
    # image name and the seed's stamp would carry 'node' with nothing
    # after it. Said here, where a build or a bake is about to read it.
  require_node_version() {
    [ -n "$NODE_VERSION" ] || terminate \
      "NODE_VERSION is not set in config.conf: the major of the Node the images" \
      "carry, from NodeSource (24). Add 'export NODE_VERSION=\"24\"' below DEBIAN_VERSION."
  }

  # create_local_dockerfile
    # Bakes the local (dev toolchain) dockerfile from its seed.
  create_local_dockerfile() {
    require_node_version
    local seed_path="$SCRIPTS_DIR/$LOCAL_DOCKERFILE_SEED"
    local file_path="$SCRIPTS_DIR/$LOCAL_DOCKERFILE"

    cp "$seed_path" "$file_path"

    sed -i "s/%{elixir_version}/$ELIXIR_VERSION/" "$file_path"
    sed -i "s/%{erlang_version}/$ERLANG_VERSION/" "$file_path"
    sed -i "s/%{debian_version}/$DEBIAN_VERSION/" "$file_path"
    sed -i "s/%{node_version}/$NODE_VERSION/" "$file_path"
    sed -i "s/%{phx_new_version}/$PHX_NEW_VERSION/" "$file_path"
    sed -i "s/%{app_name}/$ELIXIR_PROJECT_NAME/" "$file_path"
  }

  # prepare_workspace
    # Ensures an empty workspace directory (confirming first when a project
    # already exists there) and bakes the local dockerfile from seed.
  prepare_workspace() {
    if [[ "$EXISTING_PROJECT" == true ]]; then
      confirm \
        "A project already exists in $WORKSPACE_PATH. This action will" \
        "overwrite all its files." && \
      wipe_workspace
    else
      mkdir -p "$WORKSPACE_PATH"
    fi && \
    create_local_dockerfile
  }

  # register_igniter_package
    # Bootstrap: registers the workbench_igniter package in the generated
    # mix.exs. The dependency is conditional on the mounted workbench
    # (/app/workbench, overridable with WORKBENCH_PATH), so the project
    # stays self-contained whenever the workbench is absent.
    # The dependency goes on the `deps:` line, never as `] ++ …` on the
    # list: Igniter reads the project's dependencies off the literal
    # list in `defp deps`, and so does every cartridge. A base cartridge
    # never merges mix.exs as text (WorkbenchIgniter.MixFile applies its
    # change by the tree), so what sits beside this edit is free.
  register_igniter_package() {
    local file_path="$WORKSPACE_PATH/$MIX_FILE"

    sed -i 's/deps: deps(),/deps: deps() ++ workbench_dep(),/' "$file_path" && \
    sed -i '/^  defp deps do/i\
\  # Workbench igniter tasks, available while the workbench is mounted.\
\  defp workbench_dep do\
\    path = "#{System.get_env("WORKBENCH_PATH", "/app/workbench")}/igniter"\
\
\    if File.exists?(path) do\
\      [{:workbench_igniter, path: path, only: [:dev, :test], runtime: false}]\
\    else\
\      []\
\    end\
\  end\
' "$file_path"
  }

  # bake_compose <IMAGE> <DOCKERFILE> <TARGET_FILE>
    # Writes a compose file of the pod topology into the workspace —
    # the dev file with the app's dev image and dockerfile, the prod
    # file with the release's — off `mix workbench.compose` in the
    # igniter package (scripts/PLAN.md), run on the project: this side
    # decides the ports and the images and hands them over; which
    # services the project asks for — a database with ecto, pgAdmin,
    # Adminer, k6, Prometheus and Grafana with their cartridges — the task reads
    # off the project's cartridges, each declaring its own. The task writes into the
    # workspace itself (/app/src on its side, --out), since a mix run's
    # stdout carries deps.get's lines too; to a temporary first, so a
    # task that fails leaves the file as it was.
  bake_compose() {
    local image="$1" dockerfile="$2" deploy
    if [[ "$dockerfile" == "$LOCAL_DOCKERFILE" ]]; then deploy=dev; else deploy=prod; fi

    # The ports are kept where the deployment's own file has them: the
    # check beside the dev file (compose_behind) keeps the dev file's.
    compose_render "$3" "${3%.check}" \
      --deploy "$deploy" \
      --app-name "$ELIXIR_PROJECT_NAME" \
      --image "$image" \
      --dockerfile "$dockerfile" \
      --uid "$(id -u)" \
      --gid "$(id -g)" \
      --app-port "$APP_PORT" \
      --internal-port "$APP_INTERNAL_PORT"
  }

  # compose_render <FILE> <KEPT_FILE> [OPTIONS...]
    # One of the workspace's compose files, off 'mix workbench.compose',
    # written whole or not at all. No service is named here: what the
    # project's cartridges ask for is theirs to define, and the script
    # hands over only what is the host's to know — the image tags
    # config.conf names (version_flags) and the host ports.
    # A port lives in the file that publishes it, so KEPT_FILE's are
    # kept (--keep-ports-of) and a bake moves nothing. One no file has
    # yet comes back as a need — 'need> NAME DEFAULT', exit 3, nothing
    # written — and is chosen here, the first free from the cartridge's
    # default on, because free is a question for the host; then the
    # task is asked again with it.
  compose_render() {
    local file="$1" kept="$2"; shift 2
    local file_path="$WORKSPACE_PATH/$file" answer name default port chosen=" " versions=() ports=()
    mapfile -t versions < <(version_flags)

    if answer=$(workspace_igniter workbench.compose "$@" "${versions[@]}" \
      --keep-ports-of "/app/src/$kept" --out "/app/src/$file.baking" 2>&1)
    then mv "$file_path.baking" "$file_path"; return 0; fi

    rm -f "$file_path.baking"
    grep -q '^need> ' <<< "$answer" || { echo "$answer" | tail -n 5 >&2; return 1; }

    while read -r _ name default; do
      port=$(first_free_port "$default")
      while [[ "$chosen" == *" $port "* ]]; do port=$(first_free_port $((port + 1))); done
      chosen+="$port "
      ports+=( --port "$name=$port" )
    done < <(grep '^need> ' <<< "$answer" | tr -d '\r')

    if workspace_igniter workbench.compose "$@" "${versions[@]}" "${ports[@]}" \
      --keep-ports-of "/app/src/$kept" --out "/app/src/$file.baking" > /dev/null
    then mv "$file_path.baking" "$file_path"
    else rm -f "$file_path.baking"; return 1
    fi
  }

  # version_flags
    # '--version NAME=TAG' for every NAME_IMAGE_VERSION config.conf (or
    # the environment) sets: POSTGRES_IMAGE_VERSION="16" is postgres=16.
    # One word per line. A name no cartridge asks about is ignored over
    # there; one left unset takes its cartridge's default.
  version_flags() {
    local var name
    for var in $(compgen -v | grep '_IMAGE_VERSION$'); do
      [ -n "${!var}" ] || continue
      name=${var%_IMAGE_VERSION}
      printf '%s\n' --version "${name,,}=${!var}"
    done
  }

  # compose_ports
    # The app's published port, read back off the dev compose — the
    # file is where it lives, so a bake moves nothing — and chosen
    # fresh, the first free one, only when the file has none yet. The
    # services' ports are kept the same way, by compose_render.
  compose_ports() {
    APP_PORT=$(workspace_app_port)
    [ -n "$APP_PORT" ] || APP_PORT=$(first_free_port 4000)
  }

  # compose_behind
    # Whether the dev compose no longer says what the project asks for —
    # a cartridge in or out that brings a service — told the only sure
    # way: rendering it again beside the file and comparing. The file
    # itself is not touched.
  compose_behind() {
    local check="$COMPOSE_FILE.check" behind=1
    compose_ports
    if bake_compose "$LOCAL_IMAGE" "$LOCAL_DOCKERFILE" "$check" && \
       ! cmp -s "$WORKSPACE_PATH/$check" "$WORKSPACE_PATH/$COMPOSE_FILE"
    then behind=0; fi
    rm -f "$WORKSPACE_PATH/$check"
    return $behind
  }

  # compose_is_ours <COMPOSE_FILE>
    # Whether a compose file is still as the workbench wrote it: the
    # last commit that touched it is one of the workbench's own — the
    # project's birth, a bake, an insert, an eject. One the reader
    # edited and committed wears another subject, and is then the
    # reader's: nothing here writes over it unasked. The tree is clean
    # wherever this is asked ('add' and 'eject' require it), so the
    # file is what its last commit left. Asked of git and of nothing
    # else: no container runs for the answer.
  compose_is_ours() {
    local subject
    subject=$(git_read log -n 1 --format=%s -- "$1" 2>/dev/null)
    case "$subject" in
      "New project: "*|"Bake "*|"Insert "*|"Revert \"Insert "*) return 0 ;;
      *) return 1 ;;
    esac
  }

  # revert_conflicts <SHA> <FILE...>
    # What a revert that did not apply left in FILEs, for a person: one
    # line per file with the lines the markers enclose, and who wrote
    # there after SHA — the inserts that came later, by cartridge, newest
    # first, and any other commit by its subject. Read while the markers
    # are still in the tree, from the host's git.
  revert_conflicts() {
    local sha="$1" file ranges since; shift
    for file in "$@"; do
      ranges=$(awk '/^<<<<<<< /{s=NR} /^>>>>>>> /{printf "%s%d-%d", (n++ ? ", " : ""), s, NR}' "$WORKSPACE_PATH/$file")
      since=$(
        git_read log --format=%s "$sha..HEAD" -- "$file" 2>/dev/null | \
        awk '/^Insert /{print $2; next} {print "\"" $0 "\""}' | \
        awk '!seen[$0]++' | paste -sd, - | sed 's/,/, /g'
      )
      echo "  $file: lines $ranges — written since by ${since:-nobody git knows}"
    done
  }

  # rebake_composes
    # Every compose file the workspace has, written again for the
    # project as it is now, uncommitted: the step that makes a
    # cartridge's commit carry the services it brings — and its eject
    # take them away. A compose is a derived file: it is never patched
    # nor reverted, it is rendered again from what the project carries.
    # A file the reader made their own (compose_is_ours) is left alone
    # and named in COMPOSES_LEFT; one whose render fails is left as it
    # was, and named there too — the cartridge landed, and a compose
    # that is behind is something 'bake' mends later.
    # The scaled file is rendered with what it has: as many replicas,
    # the balancer or none.
  rebake_composes() {
    local file
    COMPOSES_LEFT=()
    ensure_build_volumes

    file="$COMPOSE_FILE"
    if compose_is_ours "$file"; then
      compose_ports
      bake_compose "$LOCAL_IMAGE" "$LOCAL_DOCKERFILE" "$file" || COMPOSES_LEFT+=( "$file" )
    else COMPOSES_LEFT+=( "$file" ); fi

    file="$PROD_COMPOSE_FILE"
    if [ -f "$WORKSPACE_PATH/$file" ]; then
      if compose_is_ours "$file"
      then bake_prod_compose || COMPOSES_LEFT+=( "$file" )
      else COMPOSES_LEFT+=( "$file" ); fi
    fi

    file="$SCALED_COMPOSE_FILE"
    if [ -f "$WORKSPACE_PATH/$file" ]; then
      if compose_is_ours "$file"; then
        REPLICAS=""; BALANCER=""; read_scaled_shape
        bake_scaled_compose || COMPOSES_LEFT+=( "$file" )
      else COMPOSES_LEFT+=( "$file" ); fi
    fi
    return 0
  }

  # composes_left_note
    # What rebake_composes left alone, said once at the end — and only
    # when it matters: a file of the reader's own that still says what
    # the project asks for needs no word.
  composes_left_note() {
    [ ${#COMPOSES_LEFT[@]} -gt 0 ] || return 0
    if [[ " ${COMPOSES_LEFT[*]} " != *" $COMPOSE_FILE "* ]] || compose_behind; then
      echo "${B}Note${R} ${COMPOSES_LEFT[*]} was left as it is — edited by hand, or its render failed —" \
        "and may be behind what the project asks for now. ./$(basename "$0") bake [--deploy TARGET]" \
        "writes it again: its ports are kept, any other edit of yours is not."
    fi
  }

  # ensure_build_volumes
    # Creates the workspace's three build volumes — the app's build, the
    # shared deps, the workbench's build — wearing the labels Compose
    # puts on the volumes it creates itself. The one-off runs (new, add,
    # the reads) reach them before the first 'up' does, and a volume
    # born from 'docker run' carries no labels: Compose then finds a
    # volume it cannot recognise as its own and warns about it on every
    # command. The workbench's build is not in the compose at all; the
    # label puts it under the project for 'prune' to find. Idempotent —
    # on an existing volume 'docker volume create' is a no-op — so it is
    # called wherever a one-off mounts them.
    #
    # And the two directories they cover, when the workspace is there:
    # a mount point Docker has to create itself, inside a bind mount,
    # lands on the host owned by root. Made here they belong to this
    # user — and both images carry the same two, which is
    # where a fresh volume takes its ownership from.
  ensure_build_volumes() {
    local volume
    [ -d "$WORKSPACE_PATH" ] && mkdir -p "$WORKSPACE_PATH/_build" "$WORKSPACE_PATH/deps"
    for volume in build deps workbench_build
    do
      docker volume create \
        --label com.docker.compose.project="$ELIXIR_PROJECT_NAME" \
        --label com.docker.compose.volume="$volume" \
        "${ELIXIR_PROJECT_NAME}_${volume}" > /dev/null
    done
  }

  # workbench_project <PROJECT>
    # Whether a compose project on the daemon is a workspace of this
    # workbench, read off the working directory its containers name:
    # the compose file there starts with the header's first line, or
    # the directory is under this workbench's _workspaces (a deleted
    # workspace leaves its containers behind and its files gone). A
    # project with no container left is told by its name alone, if a
    # compose under _workspaces still carries it; otherwise it is left
    # alone with the rest of the daemon: anything not known to be the
    # workbench's is somebody else's.
  workbench_project() {
    local dir file
    dir=$(docker ps --all --filter "label=com.docker.compose.project=$1" \
      --format '{{.Label "com.docker.compose.project.working_dir"}}' | head -n 1)
    [ -n "$dir" ] || { grep -qs "^name: $1\$" "$WORKBENCH_PATH"/_workspaces/*/docker-compose.yml; return; }
    case "$dir" in "$WORKBENCH_PATH/_workspaces/"*) return 0 ;; esac
    for file in "$dir/$COMPOSE_FILE" "$dir/$SCALED_COMPOSE_FILE" "$dir/$PROD_COMPOSE_FILE"; do
      # The header's first line, as the workbench writes it now and as it
      # wrote it before 2026-09-06 ("Compose seed, baked by wb.sh").
      [ -f "$file" ] && head -n 1 "$file" | \
        grep -qE '^# (Compose seed, baked by wb\.sh|The workspace.s (orchestration|scaled deployment), baked by the workbench)' && return 0
    done
    return 1
  }

  # prune_workbench [--images | --build]
    # What no live workspace uses, removed; never this workspace's
    # deployment, never the console, and never a compose project that
    # is not a workspace of this workbench (workbench_project decides:
    # the daemon is shared with whatever else the host runs). Three
    # shapes, one per call: the default is the leftovers of the other
    # workspaces — their stopped containers (with the anonymous volumes
    # those carried, the data of a dead database among them), their
    # networks, their named volumes, the build volumes made before
    # wb.sh labelled them included — of which docker keeps whatever a
    # running container still uses; '--images' is the untagged images
    # a prod bake leaves behind; '--build' is this workspace's two
    # build volumes, which docker refuses while the app mounts them;
    # and a fourth, since 2026-09-16, is images or volumes by name —
    # an old stack of the workbench, a base another project pulled, a
    # database's volume to start it clean — refused while a container
    # uses one, named, since docker would refuse it too. A name that is
    # one of several on an image only comes off, the layers go with the
    # last, and an image comes back on the next build; a volume's data
    # does not come back. Every shape is confirmed:
    # the console runs it under --yes and asks for the reader's word
    # itself.
  prune_workbench() {
    local here="" p v projects="" containers="" networks="" volumes=""
    [[ "$EXISTING_PROJECT" == true ]] && here=$(compose_project_name)
    case "$1" in
      --images)
        confirm "This action will remove every untagged image: the layers a prod bake leaves behind." && \
        docker image prune --force ;;
      --build)
        [[ "$EXISTING_PROJECT" == true ]] || terminate "There is no project."
        confirm \
          "This action will remove ${ELIXIR_PROJECT_NAME}_build, ${ELIXIR_PROJECT_NAME}_deps and $WORKBENCH_BUILD_VOLUME:" \
          "the next 'up' compiles the project from scratch, and so does the next workbench run." && \
        docker volume rm "${ELIXIR_PROJECT_NAME}_build" "${ELIXIR_PROJECT_NAME}_deps" "$WORKBENCH_BUILD_VOLUME" ;;
      "")
        # Every compose project that left something on the daemon, this
        # workspace's aside; of those, the workbench's own.
        for p in $( {
              docker ps --all --filter label=com.docker.compose.project --format '{{.Label "com.docker.compose.project"}}'
              docker network ls --filter label=com.docker.compose.project --format '{{.Label "com.docker.compose.project"}}'
              docker volume ls --filter label=com.docker.compose.project --format '{{.Label "com.docker.compose.project"}}'
            } | sort -u); do
          [[ "$p" == "$here" ]] && continue
          if workbench_project "$p"
          then projects="${projects:+$projects }$p"
          else echo "  $p: not a workspace of this workbench, left alone"; fi
        done
        for p in $projects; do
          containers="$containers $(docker ps --all --filter "label=com.docker.compose.project=$p" \
            --filter status=exited --filter status=created --filter status=dead --quiet)"
          networks="$networks $(docker network ls --filter "label=com.docker.compose.project=$p" --quiet)"
          volumes="$volumes $(docker volume ls --filter "label=com.docker.compose.project=$p" --quiet)"
          # The build volumes made before wb.sh labelled them carry the name alone.
          for v in "${p}_build" "${p}_deps" "${p}_workbench_build"; do
            docker volume inspect "$v" > /dev/null 2>&1 && volumes="$volumes $v"
          done
        done
        volumes=$(xargs -n1 <<< "$volumes" | sort -u)
        containers=$(xargs -n1 <<< "$containers" | sort -u)
        networks=$(xargs -n1 <<< "$networks" | sort -u)
        echo "Of the workspaces other than '${here:-none}' —${projects// /, } — and never the console:"
        echo "  $(echo "$containers" | grep -c .) stopped containers," \
             "$(echo "$networks" | grep -c .) networks," \
             "$(echo "$volumes" | grep -c .) named volumes."
        # shellcheck disable=SC2086  # word splitting intended: the three lists are one id per line
        confirm \
          "This action will remove them, the data volumes of their databases included." \
          "What a running container of another project still uses stays." && \
        {
          [ -n "$containers" ] && docker rm --volumes $containers
          [ -n "$networks" ] && docker network rm $networks 2>/dev/null
          [ -n "$volumes" ] && docker volume rm $volumes 2>/dev/null
          true
        } ;;
      --*) args_error invalid ;;
      *)
        local name users images="" vols=""
        for name in "$@"; do
          if docker volume inspect "$name" > /dev/null 2>&1; then
            users=$(docker ps --all --filter "volume=$name" --format '{{.Names}}' 2>/dev/null | xargs)
            [ -z "$users" ] || terminate \
              "Volume $name is mounted by $users: take those containers down first, or leave the volume."
            vols="${vols:+$vols }$name"
          elif docker image inspect "$name" > /dev/null 2>&1; then
            users=$(docker ps --all --filter "ancestor=$name" --format '{{.Names}}' 2>/dev/null | xargs)
            [ -z "$users" ] || terminate \
              "Image $name is used by $users: remove those containers first, or leave the image."
            images="${images:+$images }$name"
          else terminate "No image or volume named $name."; fi
        done
        # The words for each kind, apart: an apostrophe inside ${x:+…}
        # under double quotes opens a quote to bash.
        local note=""
        [ -n "$vols" ] && note="A volume's data goes with it, and does not come back."
        [ -n "$images" ] && note="${note:+$note }A name that is one of several on an image only comes off, and the layers go with the last; a base image comes back on the next build that needs it, minutes."
        confirm "This action will remove $*." "$note" && \
        {
          # shellcheck disable=SC2086  # word splitting intended: one name per word
          [ -n "$images" ] && docker image rm $images
          # shellcheck disable=SC2086
          [ -n "$vols" ] && docker volume rm $vols
          true
        } ;;
    esac
  }

  # workspace_port <COMPOSE_FILE> <INTERNAL_PORT>
    # The host port a compose file of the workspace publishes for a
    # container port — nothing when the file, or the service, is not
    # there. The four below read the dev file, where the ports live.
  workspace_port() {
    sed -n "s/^ *- \([0-9]*\):$2\$/\1/p" "$WORKSPACE_PATH/$1" 2>/dev/null | head -n 1
  }
  workspace_app_port()     { workspace_port "$COMPOSE_FILE" "$APP_INTERNAL_PORT"; }

  # workspace_published
    # Every port the dev compose publishes beside the app's, one
    # 'INTERNAL HOST' per line: whose each is, the status of the
    # project says (each cartridge's 'compose', by the port it listens on).
  workspace_published() {
    sed -n 's/^ *- \([0-9]*\):\([0-9]*\)$/\2 \1/p' "$WORKSPACE_PATH/$COMPOSE_FILE" 2>/dev/null | \
      grep -v "^$APP_INTERNAL_PORT "
  }

  # workspace_doors
    # The same ports for a person, 'LABEL HOST' per line. The label is
    # the file's own: a cartridge opens the comment over a port it
    # publishes with what the port is — '# pgAdmin port, with…'.
  workspace_doors() {
    awk '
      /^ *# [A-Za-z0-9]+ port/ { label = $2 }
      /^ *- [0-9]+:[0-9]+$/ {
        split($2, pair, ":")
        if (label != "" && label != "Application") print label, pair[1]
        label = ""
      }
    ' "$WORKSPACE_PATH/$COMPOSE_FILE" 2>/dev/null
  }

  # Where the toolchain runs -------------------------------------------------
    # Four runners below need the toolchain and nothing else: mix on the
    # project (workspace_igniter), git that writes (workspace_git), and
    # the entrypoint's new and add (entrypoint_run). Each has two ways:
    # here, when this side is the toolchain — the console's container,
    # see WORKSPACE_MOUNT — or a container on the workbench's image with
    # the same mounts otherwise. The command is the same either way; only
    # the runner branches, so nothing about a verb knows or cares where
    # it ran. What stays in a container regardless: whatever needs the
    # pod's network (mix — the database is there), whatever goes
    # to the daemon anyway (build, compose), and the package's own tasks
    # (package_igniter) — here they would compile through the bind mount
    # of the workbench, which nothing may.

  # toolchain_here
    # Whether this very process runs in the toolchain, with the workspace
    # config.conf names mounted at WORKSPACE_MOUNT and its volumes over
    # it — see WORKSPACE_MOUNT — and on the image this run asks for: a
    # 'new' that resolves another installer than the console's image
    # carries generates in a container of that image, never here with
    # the wrong phx_new.
  toolchain_here() {
    [ -n "$WORKSPACE_MOUNT" ] && \
    [[ "${WORKSPACE_MOUNT_PATH:-}" == "$WORKSPACE_PATH" ]] && \
    [[ "${WORKSPACE_MOUNT_PROJECT:-}" == "$ELIXIR_PROJECT_NAME" ]] && \
    [[ "${WORKSPACE_MOUNT_IMAGE:-}" == "$WORKBENCH_IMAGE" ]]
  }

  # toolchain_env [NAME=VALUE...] <COMMAND...>
    # COMMAND run here, in this container's toolchain, the way a fresh
    # workbench container would run it: the console's own two Mix
    # variables dropped — set in its image so its build lives under
    # /app/console, inherited they would send the project's there —
    # the workbench named to the project's mix.exs (the package is a
    # path dependency on it), and colour asked for as a container is.
  toolchain_env() {
    env -u MIX_BUILD_ROOT -u MIX_DEPS_PATH \
      WORKBENCH_PATH="$WORKBENCH_PATH" "${COLOR_ENV[@]}" "$@"
  }

  # entrypoint_run [-T] <NAME> [ARGS...]
    # scripts/entrypoint.sh ARGS on the workspace, with the toolchain and
    # the workbench. Here when this is the toolchain; else in a container
    # of the workbench's image, with the workspace's volumes. -T asks for no terminal, as
    # compose spells it, for a run whose output is read. NAME is the
    # entrypoint's own command (new, add, expand…), and names the
    # container after it and this process: two at once — the console
    # reads on every page it serves — must not fight over one name.
  entrypoint_run() {
    local tty_flags=("${DOCKER_TTY_FLAGS[@]}")
    if [[ "$1" == "-T" ]]; then tty_flags=(); shift; fi
    local name="$1"
    if toolchain_here; then
      entrypoint_here "$@"
    else
      # On the workbench's image, the installer stamped in the workspace
      # (or the one 'new' resolved), and never as the compose's `app`:
      # `add` and `expand` compile the project and ask nothing of the
      # database or the .env, and the app service would put them in the
      # app's build.
      ensure_build_volumes && ensure_workbench_image || return 1
      docker run \
        "${tty_flags[@]}" \
        "${CPU_SHARES_FLAG[@]}" \
        "${COLOR_ENV[@]/#/--env=}" \
        --name "${APP_NAME}_workbench_${name}_$$" \
        --rm \
        --volume "$SOURCE_CODE_VOLUME" \
        --volume "$WORKBENCH_VOLUME" \
        "${BUILD_VOLUMES[@]}" \
        "$WORKBENCH_IMAGE" "${CONTAINER_ENTRYPOINT[@]}" "$@"
    fi
  }

  # entrypoint_here [ARGS...]
    # The entrypoint run in this container. It works from /app, where the
    # workspace is 'src' — WORKSPACE_MOUNT — as in a container of its
    # own; the workbench, at its host path here, is named by it. Niced
    # (JOB_NICENESS): it compiles beside the console, on the console's
    # cores.
  entrypoint_here() {
    (cd "$(dirname "$WORKSPACE_MOUNT")" && \
     toolchain_env "${NICE_CMD[@]}" bash "$WORKBENCH_PATH/scripts/entrypoint.sh" "$@")
  }

  # workspace_igniter <TASK> [ARGS...]
    # Runs a workbench.* mix task of the igniter package on the workspace.
    # 'deps.get' first: the package is a dependency the project only sees
    # with the workbench mounted, so the app service never fetches what
    # it needs, and a fresh deps volume has none of it. Then every
    # dependency compiled — the package's own (igniter and its tree) are
    # not compiled by the app service either — which is incremental and
    # costs nothing once done. Up to date, the two cost a second. All in
    # the same Mix boot as the task (a boot costs seconds), so the task
    # sees the package's current source; what mix prints on its way to
    # the task (the package, a dependency, the project) lands before the
    # answer — the --json readers keep from the first JSON line on
    # (json_answer).
    # In a container, a bare toolchain one: the source and the workbench
    # mounted, no compose. The running app container has no workbench
    # mounted (the package is not a dependency of the project once it
    # leaves the workbench), and a compose one-off would bring the
    # database up for a task that only reads the source. Named after
    # this process: two readers at once — the console reads the status
    # on every page it serves — must not fight over one name, or the
    # second finds it taken and answers nothing.
  # json_answer
    # Keeps a mix task's output from its first JSON line on: mix prints
    # what it compiles on the way to the task (a new dependency, the
    # project, the package itself) on stdout, before the task answers.
  json_answer() { sed -n '/^[[{]/,$p'; }

  workspace_igniter() {
    if toolchain_here; then
      # shellcheck disable=SC1010  # 'do' is mix's own task here, not the keyword
      (cd "$WORKSPACE_MOUNT" && toolchain_env mix do deps.get + deps.compile + "$@")
    else
      ensure_build_volumes && ensure_workbench_image || return 1
      docker run \
        "${DOCKER_TTY_FLAGS[@]}" \
        "${COLOR_ENV[@]/#/--env=}" \
        --rm \
        --name "${APP_NAME}_workbench_$1_$$" \
        --volume "$SOURCE_CODE_VOLUME" \
        --volume "$WORKBENCH_VOLUME" \
        "${BUILD_VOLUMES[@]}" \
        --workdir /app/src \
        "$WORKBENCH_IMAGE" sh -c \
          'exec mix do deps.get + deps.compile + "$@"' \
          mix "$@"
    fi
  }

  # reader_igniter <TASK> [ARGS...]
    # workspace_igniter for the readers: the status, which the console
    # reads on every page it serves, while a job may be running a mix
    # of its own beside it. Hex keeps its registry cache in
    # ~/.hex/cache.ets and rewrites it in place; a reader opening the
    # file while the job's mix writes it finds a bad one, says so on
    # stderr ("Error opening ETS file ...: :badfile") and throws the
    # cache away. In the console the readers get a Hex home of their
    # own, under the console's build volume so it outlives the
    # container; anywhere else every run has a container, and a home,
    # to itself.
  reader_igniter() {
    if toolchain_here
    then ( export HEX_HOME="${MIX_BUILD_ROOT:-$HOME}/hex"; workspace_igniter "$@" )
    else workspace_igniter "$@"; fi
  }

  # package_igniter <TASK> [ARGS...]
    # A mix task of the igniter package run on the package itself, in the
    # workbench's image, with no project under it. The catalog belongs to
    # the workbench and not to the workspace: it has to answer when the
    # workspace is empty, which is when the New project card needs it.
    # Its build goes under its own root so it never collides with a
    # host's build of the same package.
  package_igniter() {
    ensure_workbench_image || terminate "The workbench image did not build, and the catalog is read with it."
    docker run \
      --rm \
      "${COLOR_ENV[@]/#/--env=}" \
      --name "workbench_package_$1_$$" \
      --volume "$WORKBENCH_PATH/igniter:/app/igniter" \
      --volume "$WORKBENCH_VOLUME" \
      --volume workbench_package_build:/app/igniter/_build \
      --volume workbench_package_deps:/app/igniter/deps \
      --workdir /app/igniter \
      "$WORKBENCH_IMAGE" sh -c \
        'mix do deps.get + compile > /dev/null 2>&1; exec mix "$@"' \
        mix "$@"
  }

  # expand_plan <CARTRIDGE> [OPTIONS...]
    # The plan 'add' runs, one 'NAME [ARGV]' per line: the cartridge
    # itself for a plain one, the missing members for a collection —
    # asked of 'mix workbench.expand' on the project. Only the 'plan> '
    # lines are the plan; the rest is mix noise.
  expand_plan() {
    local raw
    raw=$(entrypoint_run -T expand "$@") || return 1
    echo "$raw" | tr -d '\r' | sed -n 's/^plan> //p'
  }

  # plan_json
    # The plan on stdin as JSON: [{"name": …, "argv": […]}, …].
  plan_json() {
    local line name argv first=true
    printf '['
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      name=${line%% *}; [[ "$name" == "$line" ]] && argv="" || argv=${line#* }
      $first || printf ','; first=false
      # shellcheck disable=SC2086  # word splitting intended: $argv is the rest of the plan line, one word per option
      printf '{"name": %s, "argv": [%s]}' "$(json_string "$name")" "$(words_json $argv)"
    done
    printf ']\n'
  }

  # words_json [WORD...]
    # Its arguments as JSON strings, comma-separated.
  words_json() {
    local w out=""
    for w in "$@"; do out="$out,$(json_string "$w")"; done
    printf '%s' "${out#,}"
  }

  # workspace_git [ARGS...]
    # Runs git on the workspace with the toolchain — where the project's
    # git hooks can run mix, and as the workspace's own user — signing as
    # GIT_NAME <GIT_EMAIL>: here when this is the toolchain, from a
    # workbench container otherwise.
  # git_read <ARGS...>
    # A read-only git query on the workspace: with a git on this side
    # (the console container has one; a host may) it runs here — a
    # container start costs seconds and 'status' asks three times —
    # and in the workbench container otherwise. What writes (init, add,
    # commit, revert) stays workspace_git: the project's hooks run
    # there, where mix is.
  git_read() {
    if command -v git > /dev/null 2>&1
    then git -C "$WORKSPACE_PATH" "$@"
    else workspace_git "$@"
    fi
  }

  workspace_git() {
    if toolchain_here; then
      toolchain_env "${GIT_COLOR_ENV[@]}" "${GIT_IDENTITY_ENV[@]}" \
        git -C "$WORKSPACE_MOUNT" "$@"
    else
      # The build volumes too: a hook that runs here runs mix here
      # (.githooks/mix, on the precommit cartridge), and mix without
      # the project's deps and _build has nothing to run it with.
      ensure_build_volumes && ensure_workbench_image || return 1
      docker run \
        --rm \
        "${GIT_COLOR_ENV[@]/#/--env=}" \
        "${GIT_IDENTITY_ENV[@]/#/--env=}" \
        --volume "$SOURCE_CODE_VOLUME" \
        "${BUILD_VOLUMES[@]}" \
        --workdir /app/src \
        "$WORKBENCH_IMAGE" git "$@"
    fi
  }

  # workspace_dirty
    # Succeeds when the workspace has changes git does not have.
  workspace_dirty() {
    [ -n "$(git_read status --porcelain 2>/dev/null)" ]
  }

  # workspace_commit [--hooks] <MESSAGE>
    # Commits everything in the workspace under MESSAGE, when there is
    # anything to commit, and says who signed it.
    # The project's hooks run only with --hooks, which is the reader's
    # own 'commit'. The rest are the workbench's bookkeeping — one
    # cartridge, one commit, and its revert — and a pre-commit hook is
    # the developer's reminder about their changes, not a gate on that:
    # an eject a check refuses is an eject that cannot happen, and a
    # hook running the suite would run it on every insert.
  workspace_commit() {
    local verify=(--no-verify)
    if [[ "$1" == "--hooks" ]]; then verify=(); shift; fi
    [ -d "$WORKSPACE_PATH/.git" ] || workspace_git init -q
    if workspace_dirty; then
      workspace_git add -A && \
      workspace_git commit -q "${verify[@]}" -m "$1" && \
      echo "Committed ${B}$1${R} (as $GIT_NAME <$GIT_EMAIL>)."
    else
      echo "Nothing to commit."
    fi
  }

  # eject_outside_tree <FEATURE>
    # The half of an eject the revert cannot do: what the insert left
    # outside the tree, which no commit carries — precommit's hook in
    # .git/hooks. The cartridge knows what it left ('ejected/1', off
    # 'mix workbench.ejected'), and is asked after the revert is
    # committed, because the revert is the decision and could still be
    # abandoned. A failure here does not undo the eject: it is said,
    # with the task's last lines, and the reader cleans up by hand.
  eject_outside_tree() {
    local answer
    if answer=$(workspace_igniter workbench.ejected "$1" 2>&1); then
      grep '^ejected> ' <<< "$answer" | tr -d '\r' | sed "s/^ejected> /  $1 /"
    else
      echo "${B}Note${R} $1 may have left something outside the tree (.git/hooks), and could not be asked what:" >&2
      echo "$answer" | tail -n 5 >&2
    fi
    return 0
  }

  # undo_failed_insert <INSERT>
    # An insert that fails leaves behind whatever it had written before
    # it failed, uncommitted — and that alone stops every command after
    # it, since 'add' and 'eject' both need a clean tree. Undoing it
    # asks nothing because nothing of the reader's is at stake: 'add'
    # begins on a clean tree (require_clean_workspace, which counts
    # untracked files too) and commits each insert as it lands, so what
    # is uncommitted at this point was written moments ago by the insert
    # that just failed, and HEAD is where the workspace stood a minute
    # before. Ignored paths are left where they are: deps/ and _build/
    # are the container's work, not the cartridge's, and throwing them
    # away would cost a recompile to undo nothing.
  undo_failed_insert() {
    workspace_dirty || return 0

    # A '<file>.phx-new' a base cartridge left beside a file it could not
    # merge stays: it is the one thing the reader needs because of the
    # failure. The tree stays dirty with it, so the next 'add' waits
    # until it is merged by hand and deleted, as the issue asks.
    workspace_git checkout -- . > /dev/null 2>&1 && \
    workspace_git clean -fdq -e '*.phx-new' && \
    echo "Undid what ${B}$1${R} had written before it failed:" \
      "the workspace is back at $(git_read log --format='%h %s' -n 1)."
    local aside
    aside=$(workspace_git ls-files --others --exclude-standard -- '*.phx-new' 2>/dev/null | xargs)
    [ -z "$aside" ] || echo "Left for you to merge by hand and delete: $aside"
  }

  # require_clean_workspace <ACTION>
    # Every cartridge is one commit, so 'eject' can revert it alone: the
    # commands that write cartridges refuse a tree with changes git does
    # not have, instead of folding them into the cartridge's commit.
  require_clean_workspace() {
    if [ ! -d "$WORKSPACE_PATH/.git" ] || workspace_dirty; then
      terminate \
        "The workspace has changes git does not have, and '$1' needs a" \
        "clean tree: each cartridge is one commit, so 'eject' can revert" \
        "it alone. Commit them first: ./$(basename "$0") commit \"MESSAGE\""
    fi
  }

  # active_inserts
    # The cartridges inserted by commit and not ejected since, newest
    # first, one per line: sha, subject and date separated by \x1f. One
    # walk of the log: a revert of an insert cancels the next (older)
    # insert with that subject.
  active_inserts() {
    git_read log --format='%H%x1f%s%x1f%ci' 2>/dev/null | \
    awk -F'\x1f' '
      $2 ~ /^Revert "Insert / { s = $2; sub(/^Revert "/, "", s); sub(/"$/, "", s); pending[s]++; next }
      $2 ~ /^Insert /         { if (pending[$2] > 0) { pending[$2]--; next } print }
    '
  }

  # compose_project_name
    # The compose project every deployment of the workspace shares (the
    # 'name:' its compose files carry).
  compose_project_name() {
    # Quiet when the file is not there: a project has a mix.exs before
    # it has a compose — the window inside 'new', between phx.new and
    # the bake — and sed's complaint went to stderr, which a reader
    # captures along with the JSON it asked for ('not JSON:' in the
    # console, 2026-09-27).
    sed -n 's/^name: //p' "$WORKSPACE_PATH/$COMPOSE_FILE" 2> /dev/null | head -n 1
  }

  # workspace_containers [FORMAT]
    # Every container of the workspace's compose project, whichever
    # deployment created it — dev and prod share their service names, so
    # the image is what tells them apart. FORMAT is compose's --format.
  workspace_containers() {
    docker compose --project-name "$(compose_project_name)" \
      ps --all --format "${1:-json}" 2>/dev/null
  }

  # workspace_containers_brief
    # The same containers in the five words a tool acts on: service,
    # state, health, the status line, the published ports. The raw rows
    # of 'compose ps' carry every label of the project and are most of
    # 'status --json'. The fields travel separated by 0x1f, not a tab:
    # a tab is whitespace to 'read', and two in a row — an empty health
    # — would fold into one and shift every field after it.
  workspace_containers_brief() {
    local service state health status ports
    workspace_containers $'{{.Service}}\x1f{{.State}}\x1f{{.Health}}\x1f{{.Status}}\x1f{{.Ports}}' | \
    while IFS=$'\x1f' read -r service state health status ports; do
      printf '{"service": %s, "state": %s, "health": %s, "status": %s, "ports": %s}\n' \
        "$(json_string "$service")" "$(json_string "$state")" "$(json_string "$health")" \
        "$(json_string "$status")" "$(json_string "$ports")"
    done | json_array
  }

  # json_string <TEXT>
    # TEXT as a JSON string literal. The control characters are escaped
    # too, not only the backslash and the quote: a cartridge's NEED.md
    # travels through here, and a raw newline inside a string is what
    # makes a reader call the whole answer invalid.
  json_string() {
    printf '"%s"' "$(
      printf '%s' "$1" | \
      sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' \
          -e 's/\x08/\\b/g' -e 's/\x0c/\\f/g' -e 's/\r/\\r/g' -e 's/\t/\\t/g' | \
      sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/\\n/g'
    )"
  }

  # json_array
    # One JSON array from stdin: objects one per line (compose's ps
    # --format json), or an array already, or nothing.
  json_array() {
    local input
    input=$(cat)
    case "$input" in
      \[*) printf '%s\n' "$input" ;;
      "")  printf '[]\n' ;;
      *)   printf '[%s]\n' "$(printf '%s' "$input" | paste -sd, -)" ;;
    esac
  }

  # workspace_deployment
    # Which deployment is up, read off the running containers: the
    # scaled one has replicas app1..appN; dev and prod both run 'app',
    # and only the image tells them apart. Empty when nothing runs.
  workspace_deployment() {
    local running
    running=$(docker compose --project-name "$(compose_project_name)" \
      ps --status running --format '{{.Service}} {{.Image}}' 2>/dev/null)
    if   echo "$running" | grep -q '^app[0-9]'; then echo scaled
    elif echo "$running" | grep -q '^app .*-prod$'; then echo prod
    elif echo "$running" | grep -q '^app '; then echo dev
    fi
  }

  # workspace_addresses
    # The address of every container of the compose project on its
    # network, as one JSON object keyed by service — what the cluster
    # screen names its nodes by. A container on several networks lists
    # them joined, which none of the workbench's composes does.
  workspace_addresses() {
    local ids
    mapfile -t ids < <(docker compose --project-name "$(compose_project_name)" ps --quiet 2>/dev/null)
    [ ${#ids[@]} -gt 0 ] || { printf '{}'; return; }
    printf '{%s}' "$(
      docker inspect --format \
        '"{{index .Config.Labels "com.docker.compose.service"}}": "{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}"' \
        "${ids[@]}" 2>/dev/null | paste -sd, -
    )"
  }

  # workspace_homes
    # Who a session on each container is, and where it lands: the user
    # and the working directory its image declares, as one JSON object
    # keyed by service — '{"database": {"user": "", "workdir": "/"}}'.
    # What a prompt is made of, asked of the container instead of
    # written down per service; an empty user is root's, as docker
    # exec has it.
  workspace_homes() {
    local ids
    mapfile -t ids < <(docker compose --project-name "$(compose_project_name)" ps --quiet 2>/dev/null)
    [ ${#ids[@]} -gt 0 ] || { printf '{}'; return; }
    printf '{%s}' "$(
      docker inspect --format \
        '"{{index .Config.Labels "com.docker.compose.service"}}": {"user": {{json .Config.User}}, "workdir": {{json .Config.WorkingDir}}}' \
        "${ids[@]}" 2>/dev/null | paste -sd, -
    )"
  }

  # status_json [--fast] [--brief]
    # The workspace as one JSON object: whether it holds a project, where
    # it is, its ports, which deployments were baked, which one is up,
    # the containers of its compose project with their addresses, its
    # git, and — 'project' — what 'mix workbench.status --json' says of
    # the cartridges it carries. That last one boots Mix in a container
    # and costs seconds, where the rest costs tenths: '--fast' leaves it
    # out ('project' is then null, as it is when there is no project),
    # for the readings that follow an up or a down, where nothing about
    # the cartridges could have changed.
    # '--brief' is the same answer in the words a tool keeps in its
    # context window — an agent reading the workspace before it acts:
    # the containers as service, state, health and ports instead of the
    # raw rows of 'compose ps' (every label of the project: five sixths
    # of the answer), and no 'addresses' or 'homes', which only the
    # console's terminals read. Everything else, 'git.inserts' first, is
    # what such a reader acts on, and stays.
    # Without a project it still answers, with 'exists' false, so the
    # console can draw the empty workspace instead of an error.
  status_json() {
    local port published project flag fast=false brief=false
    for flag in "$@"; do
      case "$flag" in
        --fast)  fast=true ;;
        --brief) brief=true ;;
        *)       args_error invalid ;;
      esac
    done
    if [ "$EXISTING_PROJECT" != true ]; then
      printf '{\n'
      printf '  "exists": false,\n'
      printf '  "workspace": %s,\n' "$(json_string "$WORKSPACE_PATH")"
      printf '  "compose_project": null,\n'
      printf '  "ports": {"app": null, "published": {}},\n'
      printf '  "baked": {"dev": false, "prod": false, "scaled": false},\n'
      printf '  "deployment": null,\n'
      printf '  "containers": [],\n'
      if [ "$brief" = false ]; then
        printf '  "addresses": {},\n'
        printf '  "homes": {},\n'
      fi
      printf '  "git": %s,\n' "$(git_json)"
      printf '  "project": null\n'
      printf '}\n'
      return
    fi
    port=$(workspace_app_port)
    # The services' ports by the port each listens on, '"5050": 5051':
    # which service that is, 'project' says.
    published=$(workspace_published | awk '{printf "%s\"%s\": %s", (NR > 1 ? ", " : ""), $1, $2}')
    if [ "$fast" = true ]
    then project=""
    else project=$(reader_igniter workbench.status --json 2>/dev/null | json_answer); fi

    # printf, never echo, and every value as an argument rather than
    # part of the format: what goes in here is JSON already, full of the
    # \n and \\ that a JSON string is made of, and none of it is this
    # script's to read as an escape.
    printf '{\n'
    printf '  "exists": true,\n'
    printf '  "workspace": %s,\n' "$(json_string "$WORKSPACE_PATH")"
    printf '  "compose_project": %s,\n' "$(json_string "$(compose_project_name)")"
    printf '  "ports": {"app": %s, "published": {%s}},\n' "${port:-null}" "$published"
    printf '  "baked": {\n'
    # Read, not asserted: it said true because a project was there, and
    # a project is there before its compose is (2026-09-27).
    printf '    "dev": %s,\n' "$([ -f "$WORKSPACE_PATH/$COMPOSE_FILE" ] && echo true || echo false)"

    printf '    "prod": %s,\n' "$([ -f "$WORKSPACE_PATH/$PROD_COMPOSE_FILE" ] && echo true || echo false)"
    printf '    "scaled": %s\n' "$([ -f "$WORKSPACE_PATH/$SCALED_COMPOSE_FILE" ] && echo true || echo false)"
    printf '  },\n'
    printf '  "deployment": %s,\n' "$(d=$(workspace_deployment); [ -n "$d" ] && json_string "$d" || echo null)"
    if [ "$brief" = true ]; then
      printf '  "containers": %s,\n' "$(workspace_containers_brief)"
    else
      printf '  "containers": %s,\n' "$(workspace_containers | json_array)"
      printf '  "addresses": %s,\n' "$(workspace_addresses)"
      printf '  "homes": %s,\n' "$(workspace_homes)"
    fi
    printf '  "git": %s,\n' "$(git_json)"
    printf '  "project": %s\n' "${project:-null}"
    printf '}\n'
  }

  # git_json
    # The workspace's git as JSON: whether it is a repository, whether
    # the tree is clean, HEAD, who signs, and the cartridges inserted by
    # commit — newest first — which 'eject' reverts.
  git_json() {
    local inserts
    if [ ! -d "$WORKSPACE_PATH/.git" ]; then printf '{"repo": false}\n'; return; fi
    inserts=$(
      active_inserts | \
      while IFS=$'\x1f' read -r sha subject date; do
        # The subject is 'Insert NAME [ARGV]': the options the cartridge
        # went in with, as an array, so no reader has to parse a subject.
        # shellcheck disable=SC2086  # word splitting intended: the subject's words are that argv
        set -- $subject; shift 2
        printf '{"sha": "%s", "feature": "%s", "subject": %s, "date": "%s", "argv": [%s]},' \
          "$sha" "$(echo "$subject" | awk '{print $2}')" "$(json_string "$subject")" "$date" "$(words_json "$@")"
      done
    )
    printf '{"repo": true, "clean": %s, "head": %s, "identity": %s, "inserts": [%s]}\n' \
      "$(workspace_dirty && echo false || echo true)" \
      "$(json_string "$(git_read log --format='%h %s' -n 1 2>/dev/null)")" \
      "$(json_string "$GIT_NAME <$GIT_EMAIL>")" \
      "${inserts%,}"
  }

  # status_report
    # The same, for a person.
  status_report() {
    local port label door containers
    port=$(workspace_app_port)
    containers=$(workspace_containers '{{.Service}} {{.State}}{{if .Health}}/{{.Health}}{{end}} ({{.Image}})')

    echo "${B}Workspace${R}  $WORKSPACE_PATH"
    echo "${B}Project${R}    $(compose_project_name)"
    echo "  app      ${Li}http://localhost:$port${R}"
    while read -r label door; do
      [ -n "$door" ] && echo "  $(printf '%-8s' "$label") ${Li}http://localhost:$door${R}"
    done < <(workspace_doors)
    echo
    echo "${B}Deployments${R}  (baked compose files; up with: ./$(basename "$0") up --deploy TARGET)"
    for target in dev prod scaled; do
      if [ -f "$WORKSPACE_PATH/$(compose_file_for $target)" ]
      then echo "  $(printf '%-7s' $target) baked"
      else echo "  $(printf '%-7s' $target) -"; fi
    done
    echo
    echo "${B}Containers${R}  (dev and prod share their names: the image tells them apart)"
    # shellcheck disable=SC2001  # sed indents every line of a multi-line value; the expansion for that is not legible
    if [ -n "$containers" ]
    then echo "$containers" | sed 's/^/  /'
    else echo "  none"; fi
    echo
    echo "${B}Git${R}  (commits the workbench makes, signed as $GIT_NAME <$GIT_EMAIL>)"
    if [ -d "$WORKSPACE_PATH/.git" ]; then
      if workspace_dirty; then echo "  tree: changes git does not have (./$(basename "$0") commit)"
      else echo "  tree: clean"; fi
      echo "  head: $(git_read log --format='%h %s' -n 1 2>/dev/null || echo 'no commits yet')"
      active_inserts | awk -F'\x1f' '{ printf "  insert: %s %s\n", substr($1, 1, 7), $2 }'
    else echo "  not a repository"; fi
    echo
    echo "${B}Cartridges${R}  (mix workbench.status, read off the source)"
    reader_igniter workbench.status 2>/dev/null | sed 's/^/  /'
  }

  # bake_prod_compose
    # Generates the workspace's production compose file (at birth, on
    # every insert and eject, and by 'bake --deploy prod'): same seed and
    # application port as the dev compose, versioned production image,
    # the one-shot 'migrate' service the app waits for (bake_compose
    # keeps it for this Dockerfile), and — the production image being
    # self-contained — no source code volume nor build identity (its
    # Dockerfile runs as nobody).
  bake_prod_compose() {
    APP_PORT=$(workspace_app_port)
    # Its services' ports are its own, kept across bakes by
    # compose_render; the first free ones the first time.
    APP_VERSION=$(
      sed -n 's/^.*version: "\(.*\)".*/\1/p' "$WORKSPACE_PATH/$MIX_FILE" | \
      head -n 1
    )

    # The release has no source mount, no build volumes and no build
    # identity: the prod rendering leaves them out.
    bake_compose \
      "$APP_NAME:$APP_VERSION-prod" \
      "$PROD_DOCKERFILE" \
      "$PROD_COMPOSE_FILE"
  }

  # parse_deploy_args [ARGS...]
    # Reads the options 'up', 'build' and 'bake' share into DEPLOY_ARG,
    # REPLICAS and BALANCER, leaving everything it did
    # not consume in DEPLOY_REST (passed through to docker compose).
    # --replicas and --balancer only shape how the scaled compose file
    # is baked, so they are 'bake's alone (2026-09-27): 'up' and 'build'
    # act on the file as it is, and refuse them (SHAPE_GIVEN) rather than
    # silently deploying another shape than the one baked. Unasked, the
    # shape stays the file's (read_scaled_shape), the default for a file
    # that is not there yet.
  parse_deploy_args() {
    DEPLOY_ARG=dev
    REPLICAS=""
    BALANCER=""
    SHAPE_GIVEN=""
    DEPLOY_REST=()

    while [ $# -gt 0 ]; do
      case "$1" in
        --deploy)      DEPLOY_ARG="$2";          shift 2 ;;
        -e|--env)      env_flag_error ;;
        --replicas)    REPLICAS="$2"; SHAPE_GIVEN="--replicas"; shift 2 ;;
        --balancer)    BALANCER=true; SHAPE_GIVEN="--balancer"; shift ;;
        --no-balancer) BALANCER=false; SHAPE_GIVEN="--no-balancer"; shift ;;
        *)             DEPLOY_REST+=( "$1" );  shift ;;
      esac
    done

    read_scaled_shape

    case "$REPLICAS" in
      ''|*[!0-9]*|0) args_error "--replicas expects a positive integer." ;;
    esac
  }

  # read_scaled_shape
    # The shape of the scaled deployment — REPLICAS, BALANCER — as its
    # file has it, for what was not asked on the line: as many replicas
    # as it declares, the balancer if it has one. With no file, the
    # defaults. Then its ports, for the message after an up: the
    # balancer's and each replica's (BALANCER_PORT, REPLICA_PORTS), read
    # off the file the way bake_scaled_compose keeps them.
  read_scaled_shape() {
    local file="$WORKSPACE_PATH/$SCALED_COMPOSE_FILE"
    if [ -f "$file" ]; then
      [ -n "$REPLICAS" ] || REPLICAS=$(grep -c '^  app[0-9][0-9]*:$' "$file")
      if [ -z "$BALANCER" ]; then
        if grep -q '^  balancer:$' "$file"; then BALANCER=true; else BALANCER=false; fi
      fi
      mapfile -t REPLICA_PORTS < <(sed -n "s/^ *- \([0-9]*\):$APP_INTERNAL_PORT\$/\1/p" "$file")
      BALANCER_PORT=$(sed -n 's/^ *- \([0-9]*\):80$/\1/p' "$file" | head -n 1)
    else
      REPLICA_PORTS=(); BALANCER_PORT=""
    fi
    [ -n "$REPLICAS" ] || REPLICAS=$DEFAULT_REPLICAS
    [ -n "$BALANCER" ] || BALANCER=true
  }

  # refuse_shape <VERB>
    # 'up' and 'build' take no --replicas or --balancer: the shape is
    # baked, and they deploy or build the file as it is.
  refuse_shape() {
    [ -z "$SHAPE_GIVEN" ] || args_error \
      "$SHAPE_GIVEN is bake's, not $1's: the scaled deployment is $1's as baked." \
      "Shape it first: ./$(basename "$0") bake --deploy scaled [--replicas N] [--no-balancer]"
  }

  # bake_release_composes
    # The prod and scaled compose files, as 'new' and 'adopt' bake them
    # with the dev one (2026-09-27): a derived file that exists from
    # birth is one every Insert carries its services into and every
    # eject takes them out of, and one no 'up' has to write — and leave
    # uncommitted — on the way. The scaled file takes the default shape.
  bake_release_composes() {
    REPLICAS=$DEFAULT_REPLICAS
    BALANCER=true
    bake_prod_compose && bake_scaled_compose
  }

  # bake_scaled_compose
    # Writes the workspace's scaled compose file, off workbench.compose
    # as bake_compose does: the production image replicated REPLICAS
    # times on a bridge network, each replica with its own host port.
    # The replicas' ports are chosen here and left in the REPLICA_PORTS
    # array; a service's — one that publishes on this network too — is
    # kept across bakes as the prod file keeps its own.
  bake_scaled_compose() {
    local port=4000
    local i=1
    local balancer_flag clustering_flag replica_ports

    APP_VERSION=$(
      sed -n 's/^.*version: "\(.*\)".*/\1/p' "$WORKSPACE_PATH/$MIX_FILE" | \
      head -n 1
    )

    # The file keeps its ports, as the other two do, while it is asked
    # for the same shape — as many replicas, the balancer or none: a
    # bake moves nothing, and a deployment that is up is not given
    # ports it does not hold. Another shape is other ports, chosen below.
    local kept_replicas=() kept_balancer=""
    if [ -f "$WORKSPACE_PATH/$SCALED_COMPOSE_FILE" ]; then
      mapfile -t kept_replicas < <(sed -n "s/^ *- \([0-9]*\):$APP_INTERNAL_PORT\$/\1/p" "$WORKSPACE_PATH/$SCALED_COMPOSE_FILE")
      kept_balancer=$(sed -n 's/^ *- \([0-9]*\):80$/\1/p' "$WORKSPACE_PATH/$SCALED_COMPOSE_FILE" | head -n 1)
    fi
    if [ "${#kept_replicas[@]}" -ne "$REPLICAS" ] || \
       { [[ "$BALANCER" == true ]] && [ -z "$kept_balancer" ]; } || \
       { [[ "$BALANCER" != true ]] && [ -n "$kept_balancer" ]; }
    then kept_replicas=(); kept_balancer=""; fi

    # The balancer takes the first free port: it is the deployment's single
    # entry point. Every replica publishes its own too, so a specific
    # node can still be addressed — which is how the cross-node
    # behaviour is demonstrated.
    if [[ "$BALANCER" == true ]]; then
      BALANCER_PORT=${kept_balancer:-$(first_free_port $port)}
      port=$((BALANCER_PORT + 1))
      balancer_flag=(--balancer-port "$BALANCER_PORT")
    else
      balancer_flag=(--no-balancer)
    fi

    REPLICA_PORTS=()
    if [ "${#kept_replicas[@]}" -gt 0 ]; then
      REPLICA_PORTS=( "${kept_replicas[@]}" )
    else
      while [ "$i" -le "$REPLICAS" ]; do
        port=$(first_free_port $port)
        REPLICA_PORTS+=( "$port" )
        port=$((port + 1))
        i=$((i + 1))
      done
    fi
    replica_ports=$(IFS=,; echo "${REPLICA_PORTS[*]}")

    # Without the clustering feature the release is not distributed, so
    # DNSCluster would poll DNS forever, connect to nobody and warn about
    # it on every boot. The rendering leaves DNS_CLUSTER_QUERY out, which
    # keeps it out of the supervision tree (runtime.exs falls back to
    # :ignore).
    if clustering_installed; then clustering_flag=--clustering; else clustering_flag=--no-clustering; fi

    compose_render "$SCALED_COMPOSE_FILE" "$SCALED_COMPOSE_FILE" \
      --deploy scaled \
      --app-name "$ELIXIR_PROJECT_NAME" \
      --image "$APP_NAME:$APP_VERSION-prod" \
      --dockerfile "$PROD_DOCKERFILE" \
      --internal-port "$APP_INTERNAL_PORT" \
      --replicas "$REPLICAS" \
      --replica-ports "$replica_ports" \
      "${balancer_flag[@]}" \
      "$clustering_flag"
  }

  # clustering_installed
    # Whether the clustering feature is installed in the workspace. Its
    # block in rel/env.sh.eex is what boots the release as a named
    # distributed node; without it the release starts with a short name
    # and the replicas cannot connect to each other.
  clustering_installed() {
    grep -qs "Workbench clustering:" "$WORKSPACE_PATH/rel/env.sh.eex"
  }

  # clustering_warning
    # The deployment is valid either way — replicas behind a balancer is
    # how a stateless application scales, and they need not know each
    # other exists — but running isolated must never be silent, so it is
    # said here instead of being left to a log line inside each replica.
  clustering_warning() {
    clustering_installed || warning \
      "The 'clustering' feature is not installed: these replicas run" \
      "isolated, behind the balancer but without forming a BEAM cluster." \
      "That is a valid deployment for a stateless application. To connect" \
      "them (PubSub across nodes, Presence, distributed registries), stop" \
      "here and run: ./$(basename "$0") add clustering"
  }

  # deployed_message
    # Printed after a successful 'up' of the dev or prod compose.
  deployed_message() {
    echo
    echo "Application deploying at ${Li}http://localhost:$(workspace_app_port)${R}" \
      "(first boot compiles: give it a moment)."
    echo "Follow the logs with ${B}./$(basename "$0") logs${R}," \
      "stop everything with ${B}./$(basename "$0") stop${R}."
  }

  # scaled_deployed_message
    # Printed after a successful 'up --deploy scaled': one URL per replica
    # and how to look at the deployment from the inside.
  scaled_deployed_message() {
    local i=1

    echo
    clustering_warning
    echo "Scaled deployment coming up with $REPLICAS replicas:"
    if [[ "$BALANCER" == true ]]; then
      echo "  balancer  ${Li}http://localhost:$BALANCER_PORT${R}  (round-robin entry point)"
    fi
    for port in "${REPLICA_PORTS[@]}"
    do
      echo "  app$i      ${Li}http://localhost:$port${R}"
      i=$((i + 1))
    done
    echo
    echo "Attach to a node's release shell:"
    echo "  ${B}docker compose --file $WORKSPACE_PATH/$SCALED_COMPOSE_FILE \\${R}"
    echo "  ${B}  exec app1 /app/bin/$ELIXIR_PROJECT_NAME remote${R}"
    if clustering_installed; then
      echo "  iex> node()      # $ELIXIR_PROJECT_NAME@172.x.x.x"
      echo "  iex> Node.list() # the other $((REPLICAS - 1))"
    fi
    if [[ "$BALANCER" == true ]]; then
      echo
      echo "See the balancing: the X-Served-By address is the node that answered."
      echo "  ${B}curl -sI http://localhost:$BALANCER_PORT | grep X-Served-By${R}"
    fi
    echo
    echo "Stop everything with ${B}./$(basename "$0") down --deploy scaled${R}."
  }

  # help
    # Prints help
  help() {
    section() { echo "${B}$1${R}"; }
    section_content() {
      for arg in "$@"
      do
        echo "  $arg"
      done
      echo
    }
    # A command: its line, and its body indented under it, as a man page does.
    print_command() { echo "  ${B}$1${R}"; }
    command_content() {
      for arg in "$@"
      do
        echo "      $arg"
      done
      echo
    }

    local script_name
    script_name=$(basename "$0")

    section "NAME"
    section_content "$(sed -n '2s/# //p' "$WORKBENCH_SELF")"

    section "VERSION"
    section_content \
      "$WORKBENCH_VERSION"

    section "SYNOPSIS"
    section_content \
      "./$script_name [-y | --yes] COMMAND [ARGS...]" \
      "  -y, --yes   Answer yes to every confirmation ('new' over a project," \
      "              'delete', 'prune'), for scripts and tools driving the workbench."

    section "DESCRIPTION"
    section_content \
      "Create ${B}Phoenix${R} projects and run them on localhost in Docker, with" \
      "nothing installed on the host but Docker. The workbench stays in this" \
      "directory; each project lives in its own workspace (${B}WORKSPACE_PATH${R} in" \
      "config.conf) with its own compose files, so several can run at once." \
      "Features are cartridges: 'add' inserts one as one commit, 'eject'" \
      "reverts it. See README.md and CHANGELOG.md for the reasons." \
      "" \
      "Current workspace: $WORKSPACE_PATH"

    section "COMMANDS"
    print_command "login [USER] [TOKEN]"
    command_content \
      "Log Docker in to ghcr.io with a GitHub token, for private images." \
      "  USER    GitHub user name." \
      "  TOKEN   A classic personal access token."

    print_command "new [--name NAME] [--phx-new VERSION] [PHX_NEW_OPTIONS...]"
    command_content \
      "Generate a Phoenix project in the workspace and make its first commit:" \
      "stock phx.new plus what the workbench needs to run it (mix" \
      "workbench.setup, phx.gen.release --docker, the workspace's" \
      "Dockerfile.local and compose). Features come later, with 'add'." \
      "  --name NAME         The project's name for this creation: the app and" \
      "                      module derive from it, and so do the workspace's" \
      "                      images and its compose project. Capitalised, spaces" \
      "                      between words ('My App'). Default: PROJECT_NAME in" \
      "                      config.conf, which is also what the console starts" \
      "                      its toolchain for." \
      "  --phx-new VERSION   Phoenix installer to use (default: the newest hex" \
      "                      has for this stack; PHX_NEW_VERSION in config.conf" \
      "                      sets a standing one)." \
      "  PHX_NEW_OPTIONS     Any flag of 'mix phx.new'."

    print_command "adopt [--phx-new VERSION]"
    command_content \
      "Take in a Phoenix project that was not generated here: the one already" \
      "in the workspace, as it is. Commits it as found when it has no" \
      "repository, then adds what 'new' adds after phx.new, as one commit" \
      "('Adopt APP'). Its .env, and any Dockerfile, stay its own." \
      "  --phx-new VERSION   The installer the base cartridges take their delta" \
      "                      with (default: the phoenix mix.lock locks)."

    print_command "add [--archived] FEATURE [OPTIONS...]"
    command_content \
      "Insert a cartridge as one commit ('Insert FEATURE …'), the services it" \
      "brings baked into the compose files in that same commit. A collection" \
      "inserts each missing member as its own commit. Needs a clean tree." \
      "  FEATURE    A cartridge of the catalog ('catalog' lists them)." \
      "  OPTIONS    Flags of its 'mix workbench.install.FEATURE' task." \
      "  --archived Insert a retired cartridge anyway. An archived box is not" \
      "             offered for new projects — its papers stay on the shelf as" \
      "             the log of why it was made — but its installer still works,"\
      "             so a hand rebuilding an old project can ask for it."

    print_command "eject FEATURE"
    command_content \
      "Revert a cartridge's insert commit, and bake the compose files again" \
      "without it, as one commit. Refused when its files changed since, or" \
      "while another cartridge builds on it. Needs a clean tree."

    print_command "stacks [--json | -n N | use TAG]"
    command_content \
      "List the usable stacks: the recent hexpm/elixir debian-slim images on" \
      "Docker Hub, the configured one marked." \
      "  -n N      The N most recent (default: 12)." \
      "  --json    Every usable tag, as one JSON array." \
      "  use TAG   Write TAG's three versions into config.conf."

    print_command "engine [native | desktop | toggle | NAME]"
    command_content \
      "Show or switch the Docker context the workbench uses. On Linux 'native'" \
      "is the host's engine and 'desktop' Docker Desktop's VM; they share no" \
      "images, volumes or containers." \
      "  (none)    The current context, and the list." \
      "  toggle    Switch to the other one." \
      "  NAME      Switch to that context."

    print_command "console [up | down | logs | build]"
    command_content \
      "Run the console, a LiveView page that shows the workspace and drives" \
      "this script, as a container on 127.0.0.1, first free port from 4100." \
      "Bare, it starts it and follows its output; Ctrl+C takes it down." \
      "The workbench image is built first if missing." \
      "  up      Start it and return; it keeps running." \
      "  down    Stop it." \
      "  logs    Follow its output." \
      "  build   Build the workbench image again."

    print_command "bake [--deploy TARGET] [--replicas N] [--no-balancer]"
    command_content \
      "Write the workspace's compose file again for the project as it is," \
      "with the services its cartridges ask for, keeping its ports, as one" \
      "commit. 'add' and 'eject' do it on their own; this is for a compose you" \
      "edited by hand (which they leave alone), a config.conf that changed, or" \
      "another shape of the scaled deployment. Dockerfile.local is baked again" \
      "when the seed moved. Needs a clean tree." \
      "  --deploy TARGET   Deployment to bake: dev, prod, scaled (default: dev)." \
      "  --replicas N      Replicas of the scaled deployment (as baked; 4 at birth)." \
      "  --no-balancer     No nginx front in the scaled deployment (as baked)."

    print_command "commit [MESSAGE | --message-file PATH]"
    command_content \
      "Commit everything in the workspace, from the workbench container," \
      "signed as GIT_IDENTITY (config.conf) says." \
      "  MESSAGE               The message (default: 'Workbench: commit" \
      "                        pending changes')." \
      "  --message-file PATH   Read title and body from PATH."

    print_command "catalog [--json [--brief]]"
    command_content \
      "List the workbench's cartridges: name, version, how each is enabled," \
      "what it installs." \
      "  --json   One JSON array, with each installer's options and covers." \
      "  --brief  The array a tool keeps in its context: name, version, facts," \
      "           need, requires, and each option's name, type, default, values."

    print_command "config set KEY=VALUE [KEY=VALUE...]"
    command_content \
      "Write values into config.conf in place, keeping comments and order." \
      "A key the file does not export is refused."

    print_command "expand [--json] [--archived] CARTRIDGE [OPTIONS...]"
    command_content \
      "Print what 'add CARTRIDGE OPTIONS' would insert, one 'NAME [ARGV]' per" \
      "line in insert order, without inserting it." \
      "  --json     One JSON array of {name, argv}." \
      "  --archived Draw the plan of a retired cartridge too."

    print_command "status [--json [--fast] [--brief]]"
    command_content \
      "Report the workspace: ports, deployments baked and up, containers and" \
      "their addresses, git, and the cartridges the project carries." \
      "  --json   One JSON object; 'exists' false on an empty workspace." \
      "  --fast   Skip asking the cartridges (no Mix boot; 'project' null)." \
      "  --brief  Containers as service, state, health, ports; no addresses" \
      "           or homes. With --fast, the reading for an agent's context."

    print_command "up [--deploy TARGET]"
    command_content \
      "Bring a deployment up, detached, as its compose file is baked." \
      "  --deploy TARGET   dev (default); prod, the release image with the" \
      "                    migrations run first; scaled, the release replicas" \
      "                    behind nginx as 'bake --deploy scaled' shaped them," \
      "                    a BEAM cluster with the 'clustering' cartridge in."

    print_command "build [--deploy TARGET] [OPTIONS...]"
    command_content \
      "Build a deployment's app image without deploying it." \
      "  --deploy TARGET   dev (default), prod or scaled." \
      "  OPTIONS           Flags of 'docker compose build', e.g. --no-cache."

    print_command "k6 [--deploy TARGET] [SCRIPT] [K6_OPTIONS...]"
    command_content \
      "Run a k6 script from the project's k6/ against the deployment that is" \
      "up. Needs the k6 cartridge." \
      "  --deploy TARGET   Deployment to test (default: dev)." \
      "  SCRIPT            A file under k6/ (default: smoke.js)." \
      "  K6_OPTIONS        Passed to 'k6 run', e.g. --vus 20 --duration 1m."

    print_command "logs [--deploy TARGET] [SERVICE...]"
    command_content \
      "Follow the containers' logs; Ctrl+C detaches, they keep running." \
      "  --deploy TARGET   Deployment (default: dev)." \
      "  SERVICE           Only these services."

    print_command "stop | down | ps | restart [--deploy TARGET] [SERVICE...]"
    command_content \
      "Stop the containers (kept, for a fast 'up'), remove them, list them," \
      "or restart the named services." \
      "  --deploy TARGET   Deployment (default: dev)." \
      "  SERVICE           Only these services."

    print_command "prune [--images | --build | NAME...]"
    command_content \
      "Remove what no live workspace uses: other compose projects' stopped" \
      "containers with their anonymous volumes, and their unmounted networks" \
      "and named volumes. Never this deployment, never the console. Asks first." \
      "  --images   Instead, remove the untagged images prod bakes leave." \
      "  --build    Instead, remove this workspace's build volumes; refused" \
      "             while the app mounts them." \
      "  NAME       Instead, remove these images or volumes by name; refused" \
      "             while a container uses one. A volume's data does not come back."

    print_command "iex | bash [--deploy TARGET] [SERVICE]"
    command_content \
      "Open IEx, or a shell, on a running container. 'iex' attaches to the" \
      "node that serves the app: dev's with --remsh, a release's with its" \
      "remote shell. For a VM of its own, open bash and 'iex -S mix' there." \
      "  --deploy TARGET   Deployment (default: dev)." \
      "  SERVICE           Container (default: app; app1..appN when scaled)."

    print_command "mix [ARGS...]"
    command_content \
      "Run a mix task on the running app container, or on a one-off" \
      "container when nothing is up." \
      "  ARGS   The task and its options, e.g. test, docs, ecto.reset."

    print_command "delete"
    command_content \
      "Delete the workspace's project files and its compose project. Asks first."

    print_command "demo [--deploy TARGET]"
    command_content \
      "Run new, up, logs and delete in a row; Ctrl+C on the logs moves on to" \
      "the teardown." \
      "  --deploy TARGET   Deployment to demo (default: dev)."

    print_command "help"
    command_content \
      "Print this help."

    section "LICENSE"
    section_content \
      "MIT license (${Li}https://mit-license.org${R})" \
      "Copyright © 2024 José Luis Pamplona Stoever"
  }

  # build_setup_flags PHOENIX_NEW_OPTIONS...
    # Translates the phx.new options into flags for the 'mix
    # workbench.setup' task, which takes no configuration from
    # config.conf: the vanilla project has nothing to configure beyond
    # what the workspace needs to boot. Result in the SETUP_FLAGS array.
  build_setup_flags() {
    local ECTO=true
    for arg in "$@"; do
      case "$arg" in
        --no-ecto) ECTO=false ;;
      esac
    done

    SETUP_FLAGS=( --internal-port "$APP_INTERNAL_PORT" )
    [[ "$ECTO" == false ]] && SETUP_FLAGS+=( --no-ecto )
    true
  }

  # resolve_installer
    # The Phoenix installer, in order of authority: PHX_NEW_VERSION as
    # it stands (--phx-new for one run, the workspace's stamp), the
    # setting in config.conf, hex for everyone else — and with it the
    # workbench image's tag, which carries the installer. Shared by
    # 'new', which stamps the answer into the workspace, and by
    # 'console', which builds the image it runs on when the daemon has
    # none.
  resolve_installer() {
    PHX_NEW_NAMED=""
    if [ -n "$PHX_NEW_VERSION" ]
    then PHX_NEW_NAMED="flag"
    elif [ -n "$PHX_NEW_SETTING" ]
    then PHX_NEW_VERSION="$PHX_NEW_SETTING"; PHX_NEW_NAMED="setting"
    fi

    if [ -n "$PHX_NEW_NAMED" ]; then
      # A named installer is taken as named — not moving is the whole
      # point of naming one — and weighed against the stack, the pair
      # that has to hold: phx_new declares the Elixir it runs on, and
      # this stack either meets it or the image cannot install the
      # archive at all.
      check_phx_new_exists "$PHX_NEW_VERSION"
      check_stack_runs_phx_new "$PHX_NEW_VERSION"
      if [[ "$PHX_NEW_NAMED" == "setting" ]]; then
        echo "Phoenix installer: ${B}phx_new $PHX_NEW_VERSION${R}" \
          "(PHX_NEW_VERSION in $SCRIPT_CONFIG_FILE; --phx-new names another)."
      fi
    else
      if ! resolve_phx_new; then
        if [ -n "$PHX_NEW_NEWEST" ]
        then terminate \
          "No phx_new of the $PHX_NEW_CANDIDATES releases below $PHX_NEW_NEWEST runs on Elixir $ELIXIR_VERSION." \
          "Move the stack up ('./$(basename "$0") stacks') or name an older installer" \
          "('./$(basename "$0") new --phx-new VERSION')."
        else terminate \
          "hex.pm did not answer for phx_new. Name a version: ./$(basename "$0") new --phx-new 1.8.13"
        fi
      fi

      if [[ "$PHX_NEW_VERSION" == "$PHX_NEW_NEWEST" ]]
      then echo "Phoenix installer: ${B}phx_new $PHX_NEW_VERSION${R} (the newest on hex; --phx-new names another)."
      # Not the newest, and never silently: nobody named a version and
      # the answer is not the obvious one, so the reason travels with it.
      else echo "Phoenix installer: ${B}phx_new $PHX_NEW_VERSION${R} (the newest that runs on Elixir" \
        "$ELIXIR_VERSION; hex's newest is $PHX_NEW_NEWEST, which needs Elixir $PHX_NEW_NEWEST_REQUIREMENT)."
      fi
    fi

    WORKBENCH_IMAGE="$IMAGE_REPOSITORY-$IMAGE_STACK-phx$PHX_NEW_VERSION:$IMAGE_TAG"
  }

  # build_workbench_image
    # The workbench's image, off scripts/Dockerfile.workbench: the stack
    # and the installer as build arguments, and the UID/GID of this user.
  build_workbench_image() {
    require_node_version
    ( cd "$SCRIPTS_DIR" && \
      docker build \
        --build-arg ELIXIR="$ELIXIR_VERSION" \
        --build-arg OTP="$ERLANG_VERSION" \
        --build-arg DEBIAN="$DEBIAN_VERSION" \
        --build-arg NODE="$NODE_VERSION" \
        --build-arg PHX_NEW="$PHX_NEW_VERSION" \
        --build-arg UID="$(id -u)" \
        --build-arg GID="$(id -g)" \
        --file "$WORKBENCH_DOCKERFILE" --tag "$WORKBENCH_IMAGE" . )
  }

  # ensure_workbench_image
    # The workbench's image, built when the daemon has none — with the
    # workspace's installer, or the one 'new' would pick, so the project
    # to come finds it built and builds nothing twice. Every run of the
    # workbench in a container of its own asks for it first: on a daemon
    # pruned clean the image comes back on the first command that needs
    # it. What it says goes to stderr, out of the way of the readers'
    # JSON.
  ensure_workbench_image() {
    docker image inspect "$WORKBENCH_IMAGE" > /dev/null 2>&1 && return
    {
      echo "No workbench image $WORKBENCH_IMAGE yet: building it first (minutes)."
      resolve_installer && build_workbench_image
    } >&2
  }

  # create_project <SETUP_COMMAND> [PHOENIX_NEW_OPTIONS...]
    # Body of the 'new' command: prepares the workspace, builds the
    # workbench's image if missing, generates the Phoenix project, registers the
    # igniter package and runs SETUP_COMMAND (the 'workbench_setup'
    # entrypoint branch) with the SETUP_FLAGS its builder left. Finally
    # bakes the workspace's own dockerfile and compose file.
  create_project() {
    local setup_command="$1"; shift

    prepare_workspace && \
    ensure_build_volumes && \
    ensure_workbench_image && \
    entrypoint_run new "$ELIXIR_PROJECT_NAME" "$@" && \
    register_igniter_package && \
    entrypoint_run "$setup_command" "${SETUP_FLAGS[@]}" && \
    # The project keeps its own baked dev dockerfile, the app's image:
    # the compose build points at it, and its first up builds it —
    # sharing the workbench image's first layers, so in seconds.
    cp "$SCRIPTS_DIR/$LOCAL_DOCKERFILE" "$WORKSPACE_PATH/$LOCAL_DOCKERFILE" && \
    # The workspace owns its orchestration: the three compose files
    # with real values, the dev one building the project-owned
    # Dockerfile.local, prod and scaled running the release image off
    # the production Dockerfile phx.gen.release wrote. All three are the
    # birth commit's (2026-09-27; prod and scaled were their first up's,
    # uncommitted).
    bake_compose "$LOCAL_IMAGE" "$LOCAL_DOCKERFILE" "$COMPOSE_FILE" && \
    bake_release_composes
  }

  # adopt_project
    # Body of the 'adopt' command: what 'new' adds after phx.new, on a
    # project that was not generated here. The workspace's history
    # first — the project as it was found, when it had no repository —
    # so that the workbench's part is one commit of its own, which the
    # reader can see and revert. A step that fails leaves the tree at
    # that commit.
  adopt_project() {
    if [ -d "$WORKSPACE_PATH/.git" ]
    then require_clean_workspace adopt
    else workspace_commit "Import $ELIXIR_PROJECT_NAME as found" || return 1
    fi

    # The package goes on the `deps:` line, as on a generated project;
    # a mix.exs spelled otherwise gets nothing, and says so.
    grep -q 'deps() ++ workbench_dep()' "$WORKSPACE_PATH/$MIX_FILE" || register_igniter_package
    if ! grep -q 'deps() ++ workbench_dep()' "$WORKSPACE_PATH/$MIX_FILE"; then
      undo_failed_insert adopt
      terminate \
        "$MIX_FILE has no 'deps: deps(),' line in its project/0, which is where" \
        "the workbench's package goes. Add '++ workbench_dep()' to its deps by hand."
    fi

    if entrypoint_run workbench_adopt "${SETUP_FLAGS[@]}" && \
       create_local_dockerfile && \
       cp "$SCRIPTS_DIR/$LOCAL_DOCKERFILE" "$WORKSPACE_PATH/$LOCAL_DOCKERFILE" && \
       bake_compose "$LOCAL_IMAGE" "$LOCAL_DOCKERFILE" "$COMPOSE_FILE" && \
       bake_release_composes
    then workspace_commit "Adopt $ELIXIR_PROJECT_NAME"
    else undo_failed_insert adopt; return 1
    fi
  }

# SCRIPT =======================================================================

if [ $# -gt 0 ]; then
  # The invoked command, for messages written before any branch shifts it.
  COMMAND_NAME="$1"

  if   [[ "$1" == "login" ]]; then
    shift

    if [ $# -eq 0 ]; then
      args_error \
        "Github user name is missing." \
        "Try add a user name as command argument."
    elif [ $# -eq 1 ]; then
      args_error \
        "Github personal access token (classic) is missing." \
        "Try add a token as command argument."
    else
      GITHUB_USER=$1
      GITHUB_TOKEN=$2
      REGISTRY_SERVER="ghcr.io"

      echo "$GITHUB_TOKEN" | docker login "$REGISTRY_SERVER" \
        --username "$GITHUB_USER" \
        --password-stdin
    fi

  elif [[ "$1" == "new" ]]; then
    shift

    # The Phoenix installer for this creation, in order of authority:
    # --phx-new for this one run, PHX_NEW_VERSION (config.conf) for a
    # standing choice, hex for everyone else. Whatever it comes to is
    # stamped into the workspace's Dockerfile.local — so this project
    # keeps that generator for good — and nothing is written back to
    # config: the file names the project to come, the workspace
    # remembers the one it got.
    PHX_NEW_VERSION=""
    PHX_NEW_ARGS=()
    while [ $# -gt 0 ]; do
      case "$1" in
        --phx-new) PHX_NEW_VERSION="$2"; shift 2 ;;
        --phx-new=*) PHX_NEW_VERSION="${1#*=}"; shift ;;
        --name) PROJECT_NAME="$2"; shift 2 ;;
        --name=*) PROJECT_NAME="${1#*=}"; shift ;;
        *) PHX_NEW_ARGS+=("$1"); shift ;;
      esac
    done
    set -- "${PHX_NEW_ARGS[@]}"

    # The name of the project to be, and the only command that takes
    # one: --name for this creation, PROJECT_NAME (config.conf, or the
    # environment for a run) otherwise. The flag was required for a day
    # (2026-09-26) while the setting was gone; it came back because the
    # console needs the name before there is a project — it mounts
    # '<project>_build' and '<project>_deps', the volumes the compose
    # will own, to run mix and git in its own process.
    [ -n "$PROJECT_NAME" ] || args_error \
      "No project name. Set PROJECT_NAME in config.conf, or name one:" \
      "./$(basename "$0") new --name \"My App\""
    echo "$PROJECT_NAME" | grep -qE '^[A-Za-z][A-Za-z0-9 _-]*$' || terminate \
      "Not a project name: '$PROJECT_NAME' (a letter first, then letters, digits, spaces, - or _)."
    name_project
    require_stack_floor "$ELIXIR_VERSION"
    resolve_installer

    # Host ports for this workspace: first available ones.
    APP_PORT=$(first_free_port 4000)

    # The vanilla creation: config.conf only names the project, the
    # workspace and the stack versions, since they shape the project
    # generation and the images, not the Elixir configuration — that
    # arrives afterwards, as cartridges ('./wb.sh add').
    build_setup_flags "$@" && \
    create_project workbench_setup "$@" && \
    workspace_commit "New project: $ELIXIR_PROJECT_NAME"

  elif [[ "$1" == "adopt" ]]; then
    shift

    PHX_NEW_VERSION=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --phx-new) PHX_NEW_VERSION="$2"; shift 2 ;;
        --phx-new=*) PHX_NEW_VERSION="${1#*=}"; shift ;;
        *) args_error "Unknown option '$1'. Try: ./$(basename "$0") adopt [--phx-new VERSION]" ;;
      esac
    done

    [[ "$EXISTING_PROJECT" == true ]] || terminate \
      "There is no project in $WORKSPACE_PATH to adopt (no $MIX_FILE)." \
      "Put one there, or generate one: ./$(basename "$0") new"
    [ ! -f "$WORKSPACE_PATH/$COMPOSE_FILE" ] || terminate \
      "The project in $WORKSPACE_PATH already runs in the workbench: it has its $COMPOSE_FILE."
    [ -n "${PROJECT_APP:-}" ] || terminate \
      "$MIX_FILE names no app ('app: :name,' in project/0), and the workspace is named after it."

    # The stack is config.conf's, as for 'new', and has to be one the
    # project runs on: what its mix.exs asks of Elixir is weighed
    # against it as phx_new's requirement is. Below the floor it warns
    # instead of refusing (warn_stack_floor).
    warn_stack_floor "$ELIXIR_VERSION"
    ELIXIR_REQUIREMENT=$(sed -n 's/^ *elixir: "\([^"]*\)",.*/\1/p' "$WORKSPACE_PATH/$MIX_FILE" | head -n 1)
    [ -z "$ELIXIR_REQUIREMENT" ] || stack_satisfies "$ELIXIR_REQUIREMENT" || terminate \
      "$PROJECT_APP asks for Elixir $ELIXIR_REQUIREMENT, and this stack is $ELIXIR_VERSION." \
      "Pick one it runs on: ./$(basename "$0") stacks"

    # Nobody knows which phx_new generated a project made elsewhere,
    # and the base cartridges take their delta with one. The Phoenix it
    # runs on is the closest answer, and the better one: the delta is
    # merged into the project as it is now, not as it was born. The
    # answer is stamped into Dockerfile.local like a generated one's.
    if [ -z "$PHX_NEW_VERSION" ]; then
      PHX_NEW_VERSION=$(
        sed -n 's/^ *"phoenix": {:hex, :phoenix, "\([^"]*\)".*/\1/p' \
          "$WORKSPACE_PATH/mix.lock" 2> /dev/null | head -n 1
      )
      [ -n "$PHX_NEW_VERSION" ] || terminate \
        "mix.lock locks no phoenix, so there is no Phoenix to read the installer off." \
        "Name one: ./$(basename "$0") adopt --phx-new VERSION"
      echo "Phoenix installer: ${B}phx_new $PHX_NEW_VERSION${R} (the phoenix mix.lock" \
        "locks; --phx-new names another)."
    fi
    resolve_installer

    ECTO_FLAG=()
    grep -q '{:ecto_sql,' "$WORKSPACE_PATH/$MIX_FILE" || ECTO_FLAG=(--no-ecto)
    APP_PORT=$(first_free_port 4000)

    build_setup_flags "${ECTO_FLAG[@]}" && \
    ensure_build_volumes && \
    ensure_workbench_image && \
    adopt_project

  elif [[ "$1" == "add" ]]; then
    shift

    # The one flag of 'add' that is the workbench's and not the
    # installer's: it says whether an archived cartridge may be planned
    # at all, so it is taken out here and handed to 'expand', never to
    # 'mix workbench.install.FEATURE' — which knows nothing about it and
    # parses its switches strictly.
    ADD_FORCE=()
    ADD_ARGS=()
    while [ $# -gt 0 ]; do
      case "$1" in
        --archived) ADD_FORCE=(--archived); shift ;;
        *) ADD_ARGS+=("$1"); shift ;;
      esac
    done
    set -- "${ADD_ARGS[@]}"

    if [[ "$EXISTING_PROJECT" == true ]]; then
      if [ $# -gt 0 ]; then
        require_clean_workspace add

        # The cartridge expands to the inserts to run: itself for a
        # plain one, its missing members for a collection
        # (chiefs_setup). Only the 'plan> ' lines are the plan; the
        # rest is mix noise. Each insert then runs as its own container
        # and its own commit, so 'eject' reverts one cartridge alone —
        # a collection leaves no commit of its own.
        PLAN=$(expand_plan "${ADD_FORCE[@]}" "$@") || terminate "Could not expand '$1'."

        if [ -z "$PLAN" ]; then
          echo "Nothing to insert: the project already carries every cartridge of '$1'."
        else
          # The plan is read on its own descriptor, not on stdin: the
          # container each insert runs in attaches to stdin and drains
          # whatever is there, and a plan left on stdin is eaten after
          # the first line — the loop then ends on EOF, quietly and with
          # a zero exit, having inserted one cartridge of the several
          # the collection asked for.
          # The insert failing and the commit failing are two different
          # accidents and want two different endings: a failed insert
          # wrote a half of something nobody asked for, and goes; a
          # failed commit leaves a cartridge that did land, and stays
          # for the reader to commit by hand.
          while IFS= read -r INSERT <&3; do
            # shellcheck disable=SC2086  # word splitting intended: $INSERT is 'NAME [ARGV]', one word per option
            # The services the cartridge brings go into its commit too:
            # the composes are rendered again before it (rebake_composes),
            # so one commit is the whole cartridge and one revert takes
            # all of it away.
            if entrypoint_run add $INSERT
            then rebake_composes; workspace_commit "Insert $INSERT" || exit 1
            else undo_failed_insert "$INSERT"; exit 1
            fi
          done 3<<< "$PLAN"

          composes_left_note
        fi

      else args_error "Missing feature name. Try: ./$(basename "$0") add health_probe"; fi
    else terminate "There is no project to add features to."; fi

  elif [[ "$1" == "eject" ]]; then
    shift
    if [[ "$EXISTING_PROJECT" == true ]]; then
      [ $# -gt 0 ] || args_error "Missing feature name. Try: ./$(basename "$0") eject credo"
      FEATURE=$1
      require_clean_workspace eject
      # The latest insert of this cartridge: its subject starts with the
      # feature name, whole word (so 'dashboard' never matches
      # 'dashboard_extras').
      SHA=$(active_inserts | awk -F'\x1f' -v f="$FEATURE" '$2 == "Insert " f || index($2, "Insert " f " ") == 1 { print $1; exit }')
      [ -n "$SHA" ] || terminate \
        "No 'Insert $FEATURE' commit in the workspace: nothing to eject." \
        "The workbench commits each cartridge it inserts; one installed by" \
        "hand has no commit to revert."

      # What stands on this cartridge, asked of the project: `requires`
      # off each manifest, installed off each cartridge's own mark. The
      # insert side has kept the mirror of this rule from the start — a
      # cartridge whose requires are missing refuses, naming what to put
      # in first — while eject reverted the commit and left whoever was
      # standing on it standing on nothing. Asked after the commit is
      # found, so an eject with nothing to revert costs no container.
      DEPENDENTS=$(workspace_igniter workbench.dependents "$FEATURE" --json 2>/dev/null)
      if [ -z "$DEPENDENTS" ]; then
        # The project could not be asked (no image yet, dependencies not
        # compiled). Unjudged rather than refused, as everywhere else
        # here: a check that cannot run is not a verdict.
        echo "${B}Note${R} could not ask the project what builds on $FEATURE; ejecting anyway."
      else
        DEPENDENTS=$(echo "$DEPENDENTS" | json_answer | tr -d '[]"' | tr ',' ' ' | xargs)
        if [ -n "$DEPENDENTS" ]; then
          CHAIN=$(
            for d in $DEPENDENTS; do printf './%s eject %s && ' "$(basename "$0")" "$d"; done | \
            sed 's/ && $//'
          )
          # terminate says its pieces on one line, so this reads as
          # sentences and not as a block: one dependent takes the
          # singular and no talk of order, since there is none to give.
          if [ "$(echo "$DEPENDENTS" | wc -w)" -eq 1 ]
          then VERB="builds"; THEM="it";   ORDER=""
          else VERB="build";  THEM="them"; ORDER=", in this order"
          fi
          terminate \
            "${DEPENDENTS// /, } $VERB on $FEATURE: ejecting $FEATURE would" \
            "leave $THEM standing on nothing. Take $THEM out first$ORDER: $CHAIN"
        fi
      fi

      echo "Reverting $(workspace_git log --format='%h %s' -n 1 "$SHA")"
      # The revert is staged, not committed: the composes are then
      # rendered again for the project without the cartridge, and the
      # two make one commit. A compose is never reverted as text — a
      # cartridge inserted since wrote its block right beside this
      # one's, and the revert would conflict on a file that can simply
      # be written again: a conflict on the workbench's own composes is
      # settled by keeping the file and rendering it, and any other
      # conflict is the reader's to settle, as before.
      OURS=()
      for f in "$COMPOSE_FILE" "$PROD_COMPOSE_FILE" "$SCALED_COMPOSE_FILE"; do
        compose_is_ours "$f" && OURS+=( "$f" )
      done

      if ! workspace_git revert --no-commit "$SHA" > /dev/null 2>&1; then
        UNMERGED=$(git_read diff --name-only --diff-filter=U 2>/dev/null)
        FOREIGN=$(grep -vxF -f <(printf '%s\n' "${OURS[@]}") <<< "$UNMERGED")
        if [ -n "$UNMERGED" ] && [ -z "$FOREIGN" ]; then
          # shellcheck disable=SC2086  # word splitting intended: file names, none with spaces
          workspace_git checkout --ours -- $UNMERGED > /dev/null 2>&1 && workspace_git add -- $UNMERGED
        else
          # Said before the revert is abandoned, while the markers are
          # in the files: which files, where, and who wrote there since
          # — a cartridge inserted after this one, which is the usual
          # case and whose eject first clears the way, or a commit of
          # the reader's own.
          REPORT=$'\n'"$(revert_conflicts "$SHA" $UNMERGED)"$'\n'"Newest first: the order to eject them in."$'\n'
          workspace_git revert --abort 2>/dev/null || workspace_git reset -q --hard HEAD
          terminate \
            "The revert does not apply: files the cartridge wrote were written" \
            "again since it was inserted, so they are no longer the cartridge's alone.${REPORT}Eject" \
            "what came after it first, or revert it by hand in the workspace."
        fi
      fi

      rebake_composes
      if workspace_git add -A && workspace_git commit -q --no-verify --no-edit --cleanup=strip; then
        echo "Ejected ${B}$FEATURE${R}: $(workspace_git log --format='%h %s' -n 1)" \
          "(as $GIT_NAME <$GIT_EMAIL>)."
        eject_outside_tree "$FEATURE"
        composes_left_note
      else
        workspace_git revert --abort 2>/dev/null || workspace_git reset -q --hard HEAD
        terminate "The eject could not be committed; the workspace is back where it was."
      fi

    else terminate "There is no project."; fi

  elif [[ "$1" == "stacks" ]]; then
    shift
    # The usable hexpm/elixir images, asked of Docker Hub itself.
    # The API prunes server-side (name=-slim: ~1M tags down to the slim
    # ones, so every page arrives useful); the grep keeps what the API
    # cannot say — the exact tag shape, debian only, no release
    # candidates. config.conf keeps no copy of this list.
    # The five pages are asked for at once and not one after another.
    # They do not depend on each other, and the wait was the whole cost:
    # 10.3 s in a row, 0.27 s in parallel, byte for byte the same 482
    # tags (measured 2026-09-03). curl takes the whole errand in one
    # process through --config, so there are no background jobs to reap.
    # Each page lands in its own file rather than on a shared stdout,
    # where parallel bodies could interleave inside a line.
    stacks_list() {
      local dir page
      dir=$(mktemp -d)
      { for page in 1 2 3 4 5; do
          printf 'url = "https://hub.docker.com/v2/repositories/hexpm/elixir/tags?page_size=100&page=%s&name=-slim"\noutput = "%s/%s.json"\n' \
            "$page" "$dir" "$page"
        done
      } | curl -fs --parallel --config -
      cat "$dir"/*.json 2>/dev/null | grep -o '"name":"[^"]*"' | cut -d'"' -f4 | \
        grep -E '^[0-9]+\.[0-9]+\.[0-9]+-erlang-[0-9][0-9.]*-debian-.+-slim$' | \
        grep -v -- -rc | sort -urV
      rm -rf "$dir"
    }

    case "$1" in
      use)
        TAG="$2"
        [ -n "$TAG" ] || args_error "Missing tag. Try: ./$(basename "$0") stacks use 1.19.2-erlang-28.1-debian-trixie-20251103-slim"
        echo "$TAG" | grep -qE '^[0-9][0-9.]*-erlang-[0-9][0-9.]*-debian-.+$' || \
          terminate "That does not look like a hexpm/elixir tag (ELIXIR-erlang-OTP-debian-DEBIAN)."
        docker manifest inspect "hexpm/elixir:$TAG" > /dev/null || \
          terminate "hexpm/elixir:$TAG is not on Docker Hub."
        ELIXIR="${TAG%%-erlang-*}"
        ERLANG="${TAG#*-erlang-}"; ERLANG="${ERLANG%%-debian-*}"
        DEBIAN="${TAG##*-debian-}"
        require_stack_floor "$ELIXIR"
        sed -i "s|^export ELIXIR_VERSION=.*|export ELIXIR_VERSION=\"$ELIXIR\"|" "$WORKBENCH_PATH/config.conf"
        sed -i "s|^export ERLANG_VERSION=.*|export ERLANG_VERSION=\"$ERLANG\"|" "$WORKBENCH_PATH/config.conf"
        sed -i "s|^export DEBIAN_VERSION=.*|export DEBIAN_VERSION=\"$DEBIAN\"|" "$WORKBENCH_PATH/config.conf"
        echo "config.conf now says ${B}elixir $ELIXIR · erlang $ERLANG · $DEBIAN${R}." ;;
      --json)
        # The whole filtered list: the consoles derive everything from it
        # (the three version combos, the reverse lookup). -n trims only
        # the human listing below. The configured tag can predate the
        # recent window (hexpm rebuilds only the newest patches): when
        # the Hub still has it, it belongs in the list.
        LIST=$(stacks_list) || terminate "Docker Hub did not answer."
        CURRENT="${ELIXIR_VERSION}-erlang-${ERLANG_VERSION}-debian-${DEBIAN_VERSION}"
        if ! echo "$LIST" | grep -q "^$CURRENT\$"; then
          curl -fs "https://hub.docker.com/v2/repositories/hexpm/elixir/tags?name=$CURRENT" | \
            grep -q "\"name\":\"$CURRENT\"" && \
            LIST=$(printf '%s\n%s' "$LIST" "$CURRENT" | sort -urV)
        fi
        printf '['; FIRST=true
        echo "$LIST" | while read -r t; do
          [[ "$FIRST" == true ]] && FIRST=false || printf ','
          printf '\n  "%s"' "$t"
        done; printf '\n]\n' ;;
      ""|-n)
        [[ "$1" == "-n" ]] && N="$2" || N=12
        CURRENT="${ELIXIR_VERSION}-erlang-${ERLANG_VERSION}-debian-${DEBIAN_VERSION}"
        LIST=$(stacks_list | head -n "$N") || terminate "Docker Hub did not answer."
        echo "Usable hexpm/elixir images (highest first; pick one: ./$(basename "$0") stacks use TAG):"
        echo "$LIST" | while read -r t; do
          if [[ "$t" == "$CURRENT" ]]
          then echo "  ${B}* $t${R} (config.conf)"
          else echo "    $t"; fi
        done
        echo "$LIST" | grep -q "^$CURRENT\$" || \
          echo "  ${B}* $CURRENT${R} (config.conf — not among the recent $N)" ;;
      *) args_error invalid ;;
    esac

  elif [[ "$1" == "engine" ]]; then
    shift
    # Which Docker the script talks to: the CLI's context, per user and
    # kept across terminals. On Linux there are two — the native engine
    # ('default') and Docker Desktop's VM ('desktop-linux') — and the VM
    # falls under a compile through its file sharing, so the workbench
    # wants the native one there. Images, volumes and containers are
    # not shared between them: what one built the other has not.
    engine_say() {
      local name; name=$(docker context show)
      echo "The workbench talks to ${B}$name${R}" \
        "($(docker context inspect --format '{{.Endpoints.docker.Host}}' "$name"))."
    }
    case "$1" in
      "")
        engine_say
        echo
        docker context ls --format '  {{if .Current}}*{{else}} {{end}} {{.Name}}\t{{.DockerEndpoint}}' ;;
      toggle)
        # Between the two Linux engines; elsewhere there is one to use.
        if [[ "$(docker context show)" == "default" ]] && docker context inspect desktop-linux > /dev/null 2>&1
        then docker context use desktop-linux > /dev/null 2>&1
        else docker context use default > /dev/null 2>&1; fi
        engine_say ;;
      native)  docker context use default > /dev/null 2>&1 && engine_say ;;
      desktop) docker context use desktop-linux > /dev/null 2>&1 && engine_say ;;
      *)       docker context use "$1" > /dev/null 2>&1 && engine_say ;;
    esac

  elif [[ "$1" == "console" ]]; then
    shift
    # The console: a Phoenix LiveView app in console/, run as a container
    # that drives this very workbench — Docker's socket mounted, and the
    # workbench mounted at the same absolute path as on the host, so the
    # relative paths in config.conf and the composes' bind mounts mean
    # the same thing to the daemon whichever side asks. It runs as this
    # user, in the socket's group, and shells out to wb.sh as jobs.
    # The workspace is mounted a second time, at /app/src with its build
    # and deps volumes over it — the arrangement the app service and
    # every one-off container have — and WORKSPACE_MOUNT says so: the
    # image is the workbench's, so wb.sh run in here does its mix and git
    # in this container instead of starting another (toolchain_here),
    # and the resident (the project's own BEAM, beside the console)
    # compiles from the app's own source path into the app's own
    # volumes, and finds what it compiled. The console's own build
    # lives apart, under /app/console, and keeps MIX_BUILD_ROOT /
    # MIX_DEPS_PATH: its source has no fixed mount point, so there is
    # no path in the image for a volume to take its ownership from.
    # The container is thereby bound to the workspace config.conf named
    # when it started; named another, wb.sh in here notices the mounts
    # are not that workspace's and goes back to containers. The
    # host's loopback is reachable as host.docker.internal (APP_HOST):
    # that is where the app's port answers from inside this container,
    # for the probes the console calls itself; the doors the browser
    # opens stay on localhost.
    CONSOLE_NAME="workbench_console"
    CONSOLE_DIR="$WORKBENCH_PATH/console"

    case "$1" in
      ""|up)
        # Bare, it stays in the foreground: its output here, and Ctrl+C
        # (or the terminal closing) takes it down. 'up' leaves it running
        # and returns, as the workbench's own 'up' does.
        CONSOLE_FOLLOW=false
        [ -z "${1:-}" ] && CONSOLE_FOLLOW=true
        # The console runs on the workbench's image; built once, it serves
        # an empty workspace too, where 'new' is the first act.
        ensure_workbench_image || terminate "The workbench image did not build."
        # From inside the console — the job its page runs to bind it to
        # the workspace config.conf names now — this container cannot
        # replace itself: removing it would end the job that asked. A
        # helper container on this same image, the socket and the
        # workbench mounted, runs this very command from outside a
        # moment later, once the job has ended. The port is kept
        # (below), so the page reconnects where it is.
        if [ -n "$WORKSPACE_MOUNT" ]; then
          docker run --detach --rm \
            --user "$(id -u):$(id -g)" \
            --group-add "$(stat -c %g /var/run/docker.sock)" \
            --volume /var/run/docker.sock:/var/run/docker.sock \
            --volume "$WORKBENCH_PATH:$WORKBENCH_PATH" \
            --workdir "$WORKBENCH_PATH" \
            --env HOME=/home/elixir \
            "$WORKBENCH_IMAGE" sh -c "sleep 2; ./$(basename "$0") console up" > /dev/null && \
          echo "The console starts again in a moment, for ${B}$WORKSPACE_PATH${R}," \
            "on the same address: this page reconnects on its own."
          exit 0
        fi
        # The port: the one the console already has, so its address
        # survives a start-again; the first free one from 4100 otherwise.
        CONSOLE_PORT=$(docker port "$CONSOLE_NAME" 4000/tcp 2>/dev/null | sed -n 's/.*://p' | head -n 1)
        [ -n "$CONSOLE_PORT" ] || CONSOLE_PORT=$(first_free_port 4100)
        # The project's docs and coverage report, on an origin of their
        # own: the next port, kept the same way.
        REPORTS_PORT=$(docker port "$CONSOLE_NAME" 4001/tcp 2>/dev/null | sed -n 's/.*://p' | head -n 1)
        [ -n "$REPORTS_PORT" ] || REPORTS_PORT=$(first_free_port $((CONSOLE_PORT + 1)))
        docker rm -f "$CONSOLE_NAME" > /dev/null 2>&1
        # The socket's group as the container sees it — not the host's:
        # under Docker Desktop the mounted socket is the VM's, root-owned.
        SOCKET_GID=$(docker run --rm --volume /var/run/docker.sock:/var/run/docker.sock \
          "$WORKBENCH_IMAGE" stat -c %g /var/run/docker.sock)
        # The workspace's directory and its two mount points made here,
        # as this user: a bind mount's missing target lands root-owned.
        if ! { mkdir -p "$WORKSPACE_PATH" && ensure_build_volumes; }; then
          terminate "The workspace's directory or build volumes could not be made."
        fi
        docker run --detach \
          --name "$CONSOLE_NAME" \
          --user "$(id -u):$(id -g)" \
          --group-add "$SOCKET_GID" \
          --volume /var/run/docker.sock:/var/run/docker.sock \
          --volume "$WORKBENCH_PATH:$WORKBENCH_PATH" \
          --volume workbench_console_build:/app/console/build \
          --volume workbench_console_deps:/app/console/deps \
          --volume "$WORKSPACE_PATH:/app/src" \
          --volume "$WORKBENCH_BUILD_VOLUME:/app/src/_build" \
          --volume "${ELIXIR_PROJECT_NAME}_deps:/app/src/deps" \
          --env WORKSPACE_MOUNT=/app/src \
          --env "WORKSPACE_MOUNT_PATH=$WORKSPACE_PATH" \
          --env "WORKSPACE_MOUNT_PROJECT=$ELIXIR_PROJECT_NAME" \
          --env "WORKSPACE_MOUNT_IMAGE=$WORKBENCH_IMAGE" \
          --env MIX_BUILD_ROOT=/app/console/build \
          --env MIX_DEPS_PATH=/app/console/deps \
          --env "WORKBENCH_PATH=$WORKBENCH_PATH" \
          --add-host host.docker.internal:host-gateway \
          --env APP_HOST=host.docker.internal \
          --workdir "$CONSOLE_DIR" \
          --env HOME=/home/elixir \
          --env "WORKBENCH_DIR=$WORKBENCH_PATH" \
          --env "WORKBENCH_PATH=$WORKBENCH_PATH" \
          --env PORT=4000 \
          --env "CONSOLE_PUBLIC_PORT=$CONSOLE_PORT" \
          --env "REPORTS_PUBLIC_PORT=$REPORTS_PORT" \
          --publish "127.0.0.1:$CONSOLE_PORT:4000" \
          --publish "127.0.0.1:$REPORTS_PORT:4001" \
          "$WORKBENCH_IMAGE" sh -c "mix deps.get && mix phx.server" > /dev/null || \
          terminate "The console did not start."
        if [[ "$CONSOLE_FOLLOW" == true ]]; then
          echo "The console is coming up on ${B}http://localhost:$CONSOLE_PORT${R}" \
            "(Ctrl+C takes it down)."
          # Whichever way the following ends — Ctrl+C, the terminal gone,
          # the container stopping on its own — the container goes with it.
          trap 'docker rm -f "$CONSOLE_NAME" > /dev/null 2>&1; echo; echo "Console down."; exit 0' INT TERM HUP
          docker logs --follow "$CONSOLE_NAME"
          docker rm -f "$CONSOLE_NAME" > /dev/null 2>&1
          echo "Console down."
        else
          echo "The console is coming up on ${B}http://localhost:$CONSOLE_PORT${R}" \
            "(first run compiles it: ./$(basename "$0") console logs)."
        fi ;;
      down)  docker rm -f "$CONSOLE_NAME" > /dev/null 2>&1 && echo "Console down." || echo "The console was not up." ;;
      logs)  docker logs --follow "$CONSOLE_NAME" ;;
      build)
        # The image again, from the seed as it is now: the installer the
        # workspace was made with, or the one 'new' would pick.
        resolve_installer && build_workbench_image ;;
      *)     args_error invalid ;;
    esac

  elif [[ "$1" == "bake" ]]; then
    shift
    if [[ "$EXISTING_PROJECT" == true ]]; then
      parse_deploy_args "$@"
      [ ${#DEPLOY_REST[@]} -eq 0 ] || \
        args_error "bake takes --deploy, --replicas and --balancer only; nothing goes on to docker compose."
      require_clean_workspace bake

      # --deploy prod|scaled: that file alone, written again for the
      # project as it is now — its ports kept, the services its
      # cartridges ask for, the scaled shape as asked or as the file has
      # it — and committed, as the dev file is below. The release image
      # the file names is not built here: that is 'build --deploy', or
      # up's. Until 2026-09-10 the two were baked only on the way to
      # their own up or build, and the console's Bake button had to
      # build the image to rewrite a YAML; since 2026-09-27 this is the
      # one verb that writes them after birth, with add and eject.
      if [[ "$DEPLOY_ARG" == "prod" ]]; then
        bake_prod_compose && \
        if workspace_dirty; then
          workspace_commit "Bake $PROD_COMPOSE_FILE" && \
          echo "The prod compose says what the project asks for now: the next up --deploy prod brings it up."
        else
          echo "$PROD_COMPOSE_FILE is already what the project asks for: nothing to bake."
        fi

      elif [[ "$DEPLOY_ARG" == "scaled" ]]; then
        bake_scaled_compose && \
        if workspace_dirty; then
          workspace_commit "Bake $SCALED_COMPOSE_FILE" && \
          echo "The scaled compose says what the project asks for now: the next up --deploy scaled brings it up."
        else
          echo "$SCALED_COMPOSE_FILE is already what the project asks for: nothing to bake."
        fi

      else
        # A workspace baked before the volumes moved over _build and deps
        # has neither directory yet.
        ensure_build_volumes
        # The workspace keeps its ports; the compose is where they live.
        compose_ports

        # The dev Dockerfile too: the seed may have moved since this
        # project was born — where Mix compiles, what the image carries —
        # and the workspace keeps the copy its app's image is built from. The
        # Phoenix installer stays the one stamped in it: that is the
        # project's generator, not config.conf's next choice.
        PHX_STAMPED=$(sed -n 's/^ARG PHX_NEW="\(.*\)"/\1/p' "$WORKSPACE_PATH/$LOCAL_DOCKERFILE" 2>/dev/null)
        PHX_NEW_KEPT="$PHX_NEW_VERSION"; PHX_NEW_VERSION="${PHX_STAMPED:-$PHX_NEW_VERSION}"
        create_local_dockerfile
        PHX_NEW_VERSION="$PHX_NEW_KEPT"
        if ! cmp -s "$SCRIPTS_DIR/$LOCAL_DOCKERFILE" "$WORKSPACE_PATH/$LOCAL_DOCKERFILE"; then
          cp "$SCRIPTS_DIR/$LOCAL_DOCKERFILE" "$WORKSPACE_PATH/$LOCAL_DOCKERFILE" && \
          docker build \
            --build-arg UID="$(id -u)" \
            --build-arg GID="$(id -g)" \
            --file "$WORKSPACE_PATH/$LOCAL_DOCKERFILE" --tag "$LOCAL_IMAGE" "$SCRIPTS_DIR" && \
          echo "$LOCAL_DOCKERFILE baked again, and the image with it."
        fi

        bake_compose "$LOCAL_IMAGE" "$LOCAL_DOCKERFILE" "$COMPOSE_FILE" && \
        if workspace_dirty; then
          workspace_commit "Bake $COMPOSE_FILE" && \
          echo "The compose says what the project asks for now: the next up brings it up."
        else
          echo "$COMPOSE_FILE is already what the project asks for: nothing to bake."
        fi
      fi
    else terminate "There is no project."; fi

  elif [[ "$1" == "commit" ]]; then
    shift
    if [[ "$EXISTING_PROJECT" == true ]]; then
      # The message: the words that follow, or a file with a title and
      # a body — the console's, whose jobs travel as argv and cannot
      # carry a line break.
      if [[ "$1" == "--message-file" ]]; then
        [ -r "$2" ] || terminate "No message file at '$2'."
        workspace_commit --hooks "$(cat "$2")"
      else
        workspace_commit --hooks "${*:-Workbench: commit pending changes}"
      fi
    else terminate "There is no project to commit."; fi

  elif [[ "$1" == "catalog" ]]; then
    shift
    # The catalog is the workbench's, not the workspace's: with a project
    # it is read through the project (the package is a dependency there
    # already, compiled); without one, off the package itself.
    if [[ "$EXISTING_PROJECT" == true ]]
    then CATALOG_READER=workspace_igniter
    else CATALOG_READER=package_igniter; fi
    case "$1" in
      --json) [[ -z "$2" || "$2" == "--brief" ]] || args_error invalid
              $CATALOG_READER workbench.catalog --json ${2:+"$2"} \
                --covers /app/workbench/assets/covers 2>/dev/null | json_answer ;;
      "")     $CATALOG_READER workbench.catalog ;;
      *)      args_error invalid ;;
    esac

  elif [[ "$1" == "status" ]]; then
    shift
    case "$1" in
      --json) shift; status_json "$@" ;;
      "")     if [[ "$EXISTING_PROJECT" == true ]]
              then status_report
              else terminate "There is no project in $WORKSPACE_PATH."; fi ;;
      *)      args_error invalid ;;
    esac

  elif [[ "$1" == "config" ]]; then
    shift
    # The one writer of config.conf: 'set KEY=VALUE …' writes each value
    # in place — comments and order stay — on the same sed 'stacks use'
    # writes the three versions with. A key the file does not export is
    # refused, so a typo never grows a new line. The console saves its
    # form through here, as a job.
    case "$1" in
      set)
        shift
        [ $# -gt 0 ] || args_error "Missing assignments. Try: ./$(basename "$0") config set ELIXIR_VERSION=\"1.19.6\""
        for ASSIGNMENT in "$@"; do
          KEY="${ASSIGNMENT%%=*}"; VALUE="${ASSIGNMENT#*=}"
          echo "$KEY" | grep -qE '^[A-Z][A-Z0-9_]*$' || terminate "Not a key: '$KEY' (KEY=VALUE, keys are UPPER_CASE)."
          grep -qE "^export $KEY=" "$WORKBENCH_PATH/config.conf" || terminate "config.conf does not export $KEY."
          ESCAPED=$(printf '%s' "$VALUE" | sed 's/[&|\\]/\\&/g')
          sed -i "s|^export $KEY=.*|export $KEY=\"$ESCAPED\"|" "$WORKBENCH_PATH/config.conf"
          echo "config.conf now says ${B}$KEY=\"$VALUE\"${R}."
        done ;;
      *) args_error "Try: ./$(basename "$0") config set KEY=VALUE [KEY=VALUE …]" ;;
    esac

  elif [[ "$1" == "expand" ]]; then
    shift
    # The planning half of 'add', on its own: what inserting CARTRIDGE
    # with these options would run, one per line — or as JSON — minus
    # what the project already carries. Nothing is written.
    if [[ "$EXISTING_PROJECT" == true ]]; then
      [[ "$1" == "--json" ]] && { EXPAND_JSON=true; shift; } || EXPAND_JSON=false
      # Same flag as 'add', and for the same reason: the plan of an
      # archived cartridge is only drawn when it is asked for by name.
      [[ "$1" == "--archived" ]] && { EXPAND_FORCE=(--archived); shift; } || EXPAND_FORCE=()
      if [ $# -gt 0 ]; then
        PLAN=$(expand_plan "${EXPAND_FORCE[@]}" "$@") || terminate "Could not expand '$1'."
        if $EXPAND_JSON
        then echo "$PLAN" | plan_json
        else echo "$PLAN"; fi
      else args_error "Missing cartridge name. Try: ./$(basename "$0") expand chiefs_setup"; fi
    else terminate "There is no project to expand a cartridge against."; fi

  elif [[ "$1" == "up" ]]; then
    COMPOSE_COMMAND=$1; shift
    if [[ "$EXISTING_PROJECT" == true ]]; then
      parse_deploy_args "$@"

      refuse_shape up

      # Every deployment of a workspace shares one compose project, but
      # not the same services: dev has 'app', prod adds 'migrate', the
      # scaled one has app1..N plus balancer and migrate, and a bake with
      # another --replicas/--no-balancer changes that set between runs.
      # Without --remove-orphans the containers of the previous shape
      # stay up, unmanaged and invisible to 'ps'. No file is written on
      # the way (2026-09-27): each deployment goes up as baked, as dev
      # always did, and a file that is behind is 'bake's to mend — the
      # status and the console say when one is.
      if [[ "$DEPLOY_ARG" == "scaled" ]]; then
        resolve_compose_file scaled && \
        check_ports "$COMPOSE_TARGET" && \
        docker compose \
          --file "$COMPOSE_TARGET" \
          "$COMPOSE_COMMAND" --detach --build --remove-orphans && \
        scaled_deployed_message

      elif [[ "$DEPLOY_ARG" == "prod" ]]; then
        resolve_compose_file prod && \
        refuse_old_pod "$COMPOSE_TARGET" && \
        check_ports "$COMPOSE_TARGET" && \
        docker compose \
          --file "$COMPOSE_TARGET" \
          "$COMPOSE_COMMAND" --detach --build --remove-orphans && \
        deployed_message

      else
        refuse_old_pod "$WORKSPACE_PATH/$COMPOSE_FILE" && \
        check_ports "$WORKSPACE_PATH/$COMPOSE_FILE" && \
        workspace_compose "$COMPOSE_COMMAND" --detach --remove-orphans && \
        deployed_message
      fi

    else terminate "There is no project to deploy."; fi

  elif [[ "$1" == "build" ]]; then
    shift
    if [[ "$EXISTING_PROJECT" == true ]]; then
      parse_deploy_args "$@"

      refuse_shape build

      if [[ "$DEPLOY_ARG" == "scaled" ]]; then
        # Said before building: whether the image comes out distributed is
        # decided by rel/env.sh.eex, which mix release bakes into it, so
        # installing the feature afterwards means building again.
        clustering_warning
        # Every replica shares one image: building app1 builds them all.
        resolve_compose_file scaled && \
        docker compose \
          --file "$COMPOSE_TARGET" build app1 "${DEPLOY_REST[@]}"

      elif [[ "$DEPLOY_ARG" == "prod" ]]; then
        resolve_compose_file prod && \
        docker compose \
          --file "$COMPOSE_TARGET" build app "${DEPLOY_REST[@]}"

      else
        # Rebuilds the workspace's own dev image (APP:local) from its
        # project-owned Dockerfile.local; the next 'up' recreates the
        # containers with it.
        workspace_compose build app "${DEPLOY_REST[@]}"
      fi

    else terminate "There is no project to build."; fi

  elif [[ "$1" == "logs" ]]; then
    shift
    if [[ "$EXISTING_PROJECT" == true ]]; then
      case "$1" in
        --deploy) DEPLOY_ARG="$2"; shift 2 ;;
        -e|--env) env_flag_error ;;
        *)        DEPLOY_ARG=dev ;;
      esac

      resolve_compose_file "$DEPLOY_ARG" && \
      docker compose --file "$COMPOSE_TARGET" logs --follow "$@"

    else terminate "There is no project."; fi

  elif [[ "$1" == "stop" ]] || [[ "$1" == "down" ]] || [[ "$1" == "ps" ]] || [[ "$1" == "restart" ]]; then
    COMPOSE_COMMAND=$1; shift
    if [[ "$EXISTING_PROJECT" == true ]]; then
      case "$1" in
        --deploy) DEPLOY_ARG="$2"; shift 2 ;;
        -e|--env) env_flag_error ;;
        *)        DEPLOY_ARG=dev ;;
      esac

      # 'down' clears the project, orphans of other deployments included;
      # 'stop' and 'ps' do not accept the flag. What follows the flag
      # names services: 'restart app' is the one act on a single
      # container that leaves the deployment whole — the same service,
      # the same image, up again — which is why it is here and 'stop
      # SERVICE' is not.
      [[ "$COMPOSE_COMMAND" == "down" ]] && ORPHANS="--remove-orphans" || ORPHANS=""

      resolve_compose_file "$DEPLOY_ARG" && \
      docker compose --file "$COMPOSE_TARGET" "$COMPOSE_COMMAND" ${ORPHANS:+"$ORPHANS"} "$@"

    else terminate "There is no project."; fi

  elif [[ "$1" == "iex" ]] || [[ "$1" == "bash" ]]; then
    SESSION_KIND=$1; shift
    if [[ "$EXISTING_PROJECT" == true ]]; then
      case "$1" in
        --deploy) DEPLOY_ARG="$2"; shift 2 ;;
        -e|--env) env_flag_error ;;
        *)        DEPLOY_ARG=dev ;;
      esac

      # The service to attach to: 'app' everywhere but in the scaled
      # deployment, where the replicas are app1..appN.
      SERVICE="${1:-app}"
      resolve_compose_file "$DEPLOY_ARG"

      app_is_running "$COMPOSE_TARGET" "$SERVICE" || terminate \
        "The $SERVICE container of the $DEPLOY_ARG deployment is not running." \
        "Start it with: ./$(basename "$0") up --deploy $DEPLOY_ARG"

      # A remote shell stops the node it is attached to when its input
      # reaches EOF — the release's 'remote' and dev's 'iex --remsh'
      # alike, measured 2026-09-16 — so a redirected or piped stdin
      # would take the application down instead of just detaching.
      if [[ "$SESSION_KIND" == "iex" ]] && [ ! -t 0 ]
      then
        if [[ "$DEPLOY_ARG" == "dev" ]]
        then rpc_hint="exec -T $SERVICE elixir --sname wb_rpc --rpc-eval $ELIXIR_PROJECT_NAME 'EXPRESSION'"
        else rpc_hint="exec -T $SERVICE /app/bin/$ELIXIR_PROJECT_NAME rpc 'EXPRESSION'"; fi
        terminate \
        "'iex' attaches to the running node with a remote shell, which stops" \
        "the node when its input reaches EOF: it needs an interactive" \
        "terminal. To evaluate one expression without attaching, use:" \
        "  docker compose --file $COMPOSE_TARGET \\" \
        "    $rpc_hint"
      fi

      # Only the dev image carries Mix and the mounted source; prod and
      # scaled run the release, whose shell is 'bin/<app> remote'. Dev's
      # server boots as the named node '<app>@<container>' (its
      # Dockerfile.local's CMD), and '--remsh <app>' finds it on the
      # container's own hostname: iex on the VM that serves the port,
      # never a second one.
      if [[ "$DEPLOY_ARG" == "dev" ]]
      then
        # IEx colours its results on the node that evaluates them — the
        # app's, booted with no terminal, so its IEx has colours off —
        # and is told to colour first, by an rpc that leaves no VM behind.
        if [[ "$SESSION_KIND" == "iex" ]]
        then SESSION_COMMAND=(sh -c "elixir --sname \"wb_cfg_\$\$\" --rpc-eval $ELIXIR_PROJECT_NAME 'IEx.configure(colors: [enabled: true])' >/dev/null 2>&1; exec iex --remsh $ELIXIR_PROJECT_NAME")
        else SESSION_COMMAND=(bash); fi
        WORKDIR_FLAGS=( --workdir /app/src )
      else
        if [[ "$SESSION_KIND" == "iex" ]]
        then SESSION_COMMAND=("/app/bin/$ELIXIR_PROJECT_NAME" remote)
        else SESSION_COMMAND=(bash); fi
        WORKDIR_FLAGS=()
      fi

      docker compose --file "$COMPOSE_TARGET" \
        exec "${WORKDIR_FLAGS[@]}" "$SERVICE" "${SESSION_COMMAND[@]}"

    else terminate "There is no project."; fi

  elif [[ "$1" == "mix" ]]; then
    shift
    if [[ "$EXISTING_PROJECT" == true ]]; then
      # Warm path: exec on the running app container (fast, no startup).
      # Cold path: one-off container (starts the database dependency too).
      # compose exec and run take --env as docker run does.
      if app_is_running; then
        workspace_compose exec "${COLOR_ENV[@]/#/--env=}" --workdir /app/src app mix "$@"
      else
        workspace_compose run \
          --rm \
          "${COLOR_ENV[@]/#/--env=}" \
          --name "${APP_NAME}_workbench_mix" \
          --workdir /app/src \
          app mix "$@"
      fi

    else terminate "There is no project."; fi

  elif [[ "$1" == "delete" ]]; then
    if [[ "$EXISTING_PROJECT" == true ]]; then
      confirm \
        "This action will delete all project files from $WORKSPACE_PATH" \
        "along with its containers, images and database volumes." && \
      if [ -f "$WORKSPACE_PATH/$COMPOSE_FILE" ]; then
        workspace_compose down \
          --volumes \
          --rmi local \
          --remove-orphans
      fi && \
      # The workbench's build is not the compose's to remove.
      { docker volume rm "$WORKBENCH_BUILD_VOLUME" > /dev/null 2>&1 || true; } && \
      wipe_workspace && \
      docker rmi "$LOCAL_IMAGE" 2>/dev/null; \
      rm -f "$SCRIPTS_DIR/$LOCAL_DOCKERFILE"

    else terminate "There is no project to delete."; fi

  elif [[ "$1" == "prune" ]]; then
    shift
    prune_workbench "$@"

  elif [[ "$1" == "k6" ]]; then
    shift
    if [[ "$EXISTING_PROJECT" == true ]]; then
      # A load test against a deployment that is up: the k6 cartridge
      # puts the tool in the compose under a profile 'up' never starts,
      # with the source of the scripts mounted, and BASE_URL set for the
      # topology — the app on localhost in the pod, the balancer or the
      # 'app' alias on the bridge — so the same script runs on any of
      # the three. Everything after the script goes to k6 itself.
      case "$1" in
        --deploy) DEPLOY_ARG="$2"; shift 2 ;;
        *)        DEPLOY_ARG=dev ;;
      esac
      resolve_compose_file "$DEPLOY_ARG"
      grep -q '^  k6:' "$COMPOSE_TARGET" || terminate \
        "The $DEPLOY_ARG deployment carries no k6: insert the cartridge and bake" \
        "(./$(basename "$0") add k6, then ./$(basename "$0") bake; prod and scaled bake on their next up)."
      SCRIPT="${1:-smoke.js}"; [ $# -gt 0 ] && shift
      [ -f "$WORKSPACE_PATH/k6/$SCRIPT" ] || terminate \
        "No k6/$SCRIPT in the workspace. The scripts live in the project's k6/ directory."
      docker compose --file "$COMPOSE_TARGET" --profile tools run --rm k6 run "/scripts/$SCRIPT" "$@"
    else terminate "There is no project."; fi

  elif [[ "$1" == "demo" ]]; then
    WORKBENCH_SCRIPT="$WORKBENCH_SELF"; shift;

    # One deployment end to end. The database needs no step of its own:
    # the dev image creates it on boot, the release deployments migrate
    # into the one postgres created.
    parse_deploy_args "$@"

    "$WORKBENCH_SCRIPT" new && \
    "$WORKBENCH_SCRIPT" up --deploy "$DEPLOY_ARG" && \
    {
      # Following the logs blocks the demo while the application is
      # tried out. Ctrl+C hits the whole foreground process group, so
      # without the no-op trap it would also kill this script and the
      # delete step would never run ('' instead of ':' would not do:
      # children inherit an ignored SIGINT and the follower would not
      # detach).
      trap ':' INT
      "$WORKBENCH_SCRIPT" logs
      trap - INT
      "$WORKBENCH_SCRIPT" delete
    }

  elif [[ "$1" == "help" ]]; then
    help
  else args_error invalid; fi
else help; fi
