#!/bin/bash
# Dockerized workbench script (Igniter edition)
# v0.11.0
#
# Thin Docker wrapper: project creation and Elixir configuration are
# delegated to the :workbench_igniter package (igniter/) via
# `mix workbench.setup` and `mix workbench.install.*` tasks.
#
# The workbench lives permanently in this directory; projects are generated
# into WORKSPACE_PATH (config.conf). Each workspace owns its
# docker-compose.yml — baked with real values (name, ports, images) at
# creation — which is the source of truth for its orchestration: several
# workspaces can run simultaneously without port conflicts. The workbench
# is mounted read-only at /app/workbench so the igniter tasks are available
# inside the containers.

# CONFIGURATION ================================================================

  # The workbench is wherever this script lives; run everything from here.
  WORKBENCH_PATH="$( cd "$( dirname "$0" )" && pwd )"
  cd "$WORKBENCH_PATH" || exit 1

  # Environment overrides survive config.conf (e.g. WORKSPACE_PATH=./x ./wb.sh),
  # for a second workspace beside the configured one without editing it.
  WORKSPACE_PATH_OVERRIDE="$WORKSPACE_PATH"
  PROJECT_NAME_OVERRIDE="$PROJECT_NAME"

  # -y|--yes before the command answers every confirmation, for scripts
  # and for whatever drives the workbench without a terminal. Exported,
  # so 'demo' hands it to the commands it runs.
  if [ "$1" == "-y" ] || [ "$1" == "--yes" ]; then WB_YES=true; shift; fi
  export WB_YES="${WB_YES:-false}"

  SCRIPT_CONFIG_FILE="config.conf"
  # shellcheck source=config.conf disable=SC1091  # followed under -x; a plain run need not read the user's config
  source "./$SCRIPT_CONFIG_FILE"

  # Workbench configuration --------------------------------------------------

    WORKBENCH_VERSION=$( sed '3!d' "$0" | sed -n 's/^.*v\(.*\).*/\1/p' )
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
    # Dev toolchain dockerfile: baked from the seed into scripts/ on each
    # `new`, then copied into the workspace under the same name.
    PROD_DOCKERFILE="Dockerfile"
    PROD_COMPOSE_FILE="docker-compose.prod.yml"
    SCALED_COMPOSE_FILE="docker-compose.scaled.yml"
    SCALED_COMPOSE_SEED="docker-compose.scaled.seed.yml"
    # Replicas the scaled deployment starts unless --replicas says
    # otherwise; the balancer sits in front of them.
    DEFAULT_REPLICAS=4
    LOCAL_DOCKERFILE="Dockerfile.local"
    LOCAL_DOCKERFILE_SEED="Dockerfile.seed.local"
    COMPOSE_FILE="docker-compose.yml"
    COMPOSE_SEED="docker-compose.seed.yml"
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
    if [ "${WB_ANSI:-}" == "always" ]
    then
      COLOR_ENV=("ELIXIR_ERL_OPTIONS=-elixir ansi_enabled true")
      GIT_COLOR_ENV=(GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=color.ui GIT_CONFIG_VALUE_0=always)
      export COMPOSE_ANSI=always
    else
      COLOR_ENV=()
      GIT_COLOR_ENV=()
    fi

    # Elixir project files - - - - - - - - - - - - - - - - - - - - - - - - - -
    LOWER_CASE=$( echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' )
    ELIXIR_PROJECT_NAME=$( echo "$LOWER_CASE" | tr ' ' '_' )
    MIX_FILE="mix.exs"
    EXISTING_PROJECT=$(
      [ -f "$WORKSPACE_PATH/$MIX_FILE" ] && echo true || echo false
    )

  # Docker ---------------------------------------------------------------------

    APP_NAME=$( echo "$LOWER_CASE" | tr ' ' '-' )
    # The workspace's own dev image name. Standalone it is built from the
    # project's Dockerfile.local; with the workbench present, `new` seeds
    # it as an alias (docker tag) of the shared toolchain image.
    LOCAL_IMAGE="$APP_NAME:local"
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
    if [ "$EXISTING_PROJECT" == true ] && [ -f "$WORKSPACE_PATH/$COMPOSE_FILE" ] && \
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
    fi
    # Bare toolchain image, shared by every workspace of the same stack
    # and installer: another installer is another image, and a workspace
    # keeps the one that made its project. A workspace made before the
    # stamp names no installer, and keeps the bare tag it was built with.
    if [ -n "$PHX_NEW_VERSION" ]
    then TOOLCHAIN_IMAGE="workbench:${ELIXIR_VERSION}-${ERLANG_VERSION}-phx${PHX_NEW_VERSION}"
    else TOOLCHAIN_IMAGE="workbench:${ELIXIR_VERSION}-${ERLANG_VERSION}"
    fi
    # Ports the services bind INSIDE the containers; the host ports are
    # chosen per workspace and mapped to these in its compose file.
    APP_INTERNAL_PORT="4000"
    PGADMIN_INTERNAL_PORT="5050"
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
    # toolchain. './wb.sh console' runs the console on the toolchain
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
    if [ "${GIT_IDENTITY:-user}" == "user" ] && command -v git > /dev/null 2>&1; then
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

    # Colors
    C1="\x1B[38;5;1m" # Dark-red
    C2="\x1B[4;34m"   # Blue underline
    # Format
    B="\x1B[1m" # Bold
    R="\x1B[0m" # Reset

    Li=$C2 # Link color

# FUNCTIONS ====================================================================

  # If echo handles -e option, overrides the command
  if [ "$(echo -e)" == "" ]; then echo() { command echo -e "$@"; } fi

  # confirm <MESSAGE>
    # Prints MESSAGE and spects input prompt for continue or exit the script
  confirm() {
    echo "⚠️  ${B}Warning${R} $*"
    if [ "$WB_YES" == true ]; then echo "Continuing (--yes)."; echo; return; fi
    read -r -n 1 -p $'Should continue? [y/N] ' INPUT
    if [ "$INPUT" != "y" ]; then exit 0; fi
    echo
  }

  # args_error <ERROR>
    # Prints a default messages for argument errors.
  args_error() {
    if   [ "$1" == "missing" ];  then echo "Missing arguments."
    elif [ "$1" == "too_many" ]; then echo "Too many arguments."
    elif [ "$1" == "invalid" ];  then echo "Invalid argument."
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
    # Prints the first host port available starting from BASE.
  first_free_port() {
    local port=$1
    while (exec 3<>"/dev/tcp/127.0.0.1/$port") 2>/dev/null; do
      exec 3>&- 3<&-
      port=$((port + 1))
    done
    echo "$port"
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
    [ "$(printf '%s\n' "$ELIXIR_FLOOR" "$1" | sort -V | head -n 1)" == "$ELIXIR_FLOOR" ] || \
      terminate \
        "Elixir $1 is below the workbench's floor, $ELIXIR_FLOOR: since 1.18 Mix locks" \
        "the build and deps directories, which the workbench relies on to compile the" \
        "workspace from two sides. Pick a newer stack: ./$(basename "$0") stacks"
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
    [ "$(phx_new_release_status "$1")" == "404" ] || return 0

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
    # Compose file each environment deploys with. dev is the workspace's
    # own docker-compose.yml; prod and scaled are baked on demand.
  compose_file_for() {
    case "$1" in
      scaled)  echo "$SCALED_COMPOSE_FILE" ;;
      prod)    echo "$PROD_COMPOSE_FILE" ;;
      *)       echo "$COMPOSE_FILE" ;;
    esac
  }

  # resolve_compose_file <ENV>
    # Sets COMPOSE_TARGET to the environment's compose file, or
    # terminates when it has not been baked yet (no deployment of that
    # environment ever ran). It assigns instead of echoing on purpose:
    # called from a command substitution, 'terminate' would only exit the
    # subshell and its message would be captured as the file name.
  resolve_compose_file() {
    COMPOSE_TARGET="$WORKSPACE_PATH/$(compose_file_for "$1")"

    [ -f "$COMPOSE_TARGET" ] || terminate \
      "This workspace has no '$1' deployment ($(basename "$COMPOSE_TARGET")" \
      "does not exist). Create it with: ./$(basename "$0") up --deploy $1"
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

  # create_local_dockerfile
    # Bakes the local (dev toolchain) dockerfile from its seed.
  create_local_dockerfile() {
    local seed_path="$SCRIPTS_DIR/$LOCAL_DOCKERFILE_SEED"
    local file_path="$SCRIPTS_DIR/$LOCAL_DOCKERFILE"

    cp "$seed_path" "$file_path"

    sed -i "s/%{elixir_version}/$ELIXIR_VERSION/" "$file_path"
    sed -i "s/%{erlang_version}/$ERLANG_VERSION/" "$file_path"
    sed -i "s/%{debian_version}/$DEBIAN_VERSION/" "$file_path"
    sed -i "s/%{phx_new_version}/$PHX_NEW_VERSION/" "$file_path"
  }

  # prepare_workspace
    # Ensures an empty workspace directory (confirming first when a project
    # already exists there) and bakes the local dockerfile from seed.
  prepare_workspace() {
    if [ "$EXISTING_PROJECT" == true ]; then
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
  register_igniter_package() {
    local file_path="$WORKSPACE_PATH/$MIX_FILE"

    sed -i 's/deps: deps(),/deps: deps() ++ workbench_dep(),/' "$file_path" && \
    sed -i '/^  defp deps do/i\
\  # Workbench igniter tasks, available while the workbench is mounted.\
\  defp workbench_dep do\
\    path = "#{System.get_env("WORKBENCH_PATH", "/app/workbench")}/igniter"\
\
\    if File.exists?(path),\
\      do: [{:workbench_igniter, path: path, only: [:dev, :test], runtime: false}],\
\      else: []\
\  end\
' "$file_path"
  }

  # bake_compose <IMAGE> <DOCKERFILE> <TARGET_FILE>
    # Generates a compose file into the workspace from the seed, with the
    # real configuration values baked in. The workspace's compose is the
    # source of truth of its orchestration (name, ports, images); the
    # start command is each image's own CMD.
  bake_compose() {
    local image="$1"
    local dockerfile="$2"
    local file_path="$WORKSPACE_PATH/$3"

    cp "$SCRIPTS_DIR/$COMPOSE_SEED" "$file_path"

    sed -i "s/%{app_name}/$ELIXIR_PROJECT_NAME/"                 "$file_path"
    sed -i "s/%{compose_image}/$image/"                          "$file_path"
    sed -i "s/%{compose_dockerfile}/$dockerfile/"                "$file_path"
    sed -i "s/%{uid}/$(id -u)/"                                  "$file_path"
    sed -i "s/%{gid}/$(id -g)/"                                  "$file_path"
    sed -i "s/%{app_port}/$APP_PORT/"                            "$file_path"
    sed -i "s/%{internal_port}/$APP_INTERNAL_PORT/g"             "$file_path"
    sed -i "s/%{pgadmin_port}/$PGADMIN_PORT/"                    "$file_path"
    sed -i "s/%{pgadmin_internal_port}/$PGADMIN_INTERNAL_PORT/g" "$file_path"
    sed -i "s/%{postgres_image_version}/$POSTGRES_IMAGE_VERSION/" "$file_path"
    sed -i "s/%{pgadmin_image_version}/$PGADMIN_IMAGE_VERSION/"  "$file_path"

    # The one-shot 'migrate' service is the production deployment's:
    # the dev image migrates itself on boot ('mix setup' in the
    # Dockerfile.local CMD), so the dev compose drops the service, and
    # the prod compose hands the app's wait over to it — the migration
    # ran to completion, so the database it needed was healthy.
    if [ "$dockerfile" == "$LOCAL_DOCKERFILE" ]
    then
      sed -i '/^  # One-shot migration/,/^  database:/{/^  database:/!d}' "$file_path"
    else
      sed -i '/^  app:/,/^  # One-shot migration/{
        s/^      database:$/      migrate:/
        s/condition: service_healthy$/condition: service_completed_successfully/
      }' "$file_path"
    fi

    # Remove the database & pgadmin services on projects without a
    # database server (the network holder and the pod structure remain).
    # Nothing to migrate either: the migrator goes first, so the app's
    # depends_on — on it or on the database — is the next three lines.
    if ! workspace_needs_database
    then
      sed -i '/^  # One-shot migration/,/^  database:/{/^  database:/!d}' "$file_path"
      sed -i '/^  database:/,/^volumes:/{/^volumes:/!d}' "$file_path"
      sed -i '/^    depends_on:/,+2d'       "$file_path"
      sed -i "/# pgAdmin port/,/:$PGADMIN_INTERNAL_PORT\$/d" "$file_path"
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
    # user — and the toolchain image carries the same two, which is
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
    # the compose file there starts with the seed's own first line, or
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
      [ -f "$file" ] && head -n 1 "$file" | grep -q '^# Compose seed, baked by wb.sh' && return 0
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
    # build volumes, which docker refuses while the app mounts them.
    # Every shape is confirmed: the console runs it under --yes and
    # asks for the reader's word itself.
  prune_workbench() {
    local here="" p v projects="" containers="" networks="" volumes=""
    [ "$EXISTING_PROJECT" == true ] && here=$(compose_project_name)
    case "$1" in
      --images)
        confirm "This action will remove every untagged image: the layers a prod bake leaves behind." && \
        docker image prune --force ;;
      --build)
        [ "$EXISTING_PROJECT" == true ] || terminate "There is no project."
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
          [ "$p" == "$here" ] && continue
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
      *) args_error invalid ;;
    esac
  }

  # workspace_needs_database
    # Whether the project runs on a database server: an Ecto repo in
    # config.exs, and not the SQLite adapter (a file, no service).
  workspace_needs_database() {
    grep -q "ecto_repos" "$WORKSPACE_PATH/config/config.exs" 2>/dev/null && \
    ! grep -q "ecto_sqlite3" "$WORKSPACE_PATH/$MIX_FILE" 2>/dev/null
  }

  # workspace_app_port
    # Reads the application host port from the workspace's compose file.
  workspace_app_port() {
    sed -n "s/^ *- \([0-9]*\):$APP_INTERNAL_PORT\$/\1/p" \
      "$WORKSPACE_PATH/$COMPOSE_FILE" | \
    head -n 1
  }

  # workspace_pgadmin_port
    # Reads the pgAdmin host port from the workspace's compose file
    # (nothing on projects without Ecto, where the service is dropped).
  workspace_pgadmin_port() {
    sed -n "s/^ *- \([0-9]*\):$PGADMIN_INTERNAL_PORT\$/\1/p" \
      "$WORKSPACE_PATH/$COMPOSE_FILE" | \
    head -n 1
  }

  # Where the toolchain runs -------------------------------------------------
    # Four runners below need the toolchain and nothing else: mix on the
    # project (workspace_igniter), git that writes (workspace_git), and
    # the entrypoint's new and add (entrypoint_run). Each has two ways:
    # here, when this side is the toolchain — the console's container,
    # see WORKSPACE_MOUNT — or a container on the toolchain image with
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
    # it — all three checks, see WORKSPACE_MOUNT.
  toolchain_here() {
    [ -n "$WORKSPACE_MOUNT" ] && \
    [ "${WORKSPACE_MOUNT_PATH:-}" == "$WORKSPACE_PATH" ] && \
    [ "${WORKSPACE_MOUNT_PROJECT:-}" == "$ELIXIR_PROJECT_NAME" ]
  }

  # toolchain_env [NAME=VALUE...] <COMMAND...>
    # COMMAND run here, in this container's toolchain, the way a fresh
    # toolchain container would run it: the console's own two Mix
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
    # the workbench. Here when this is the toolchain; else through the
    # workspace's compose (app service: the dev image, the volumes) when
    # it has one, and on a bare toolchain container before it does —
    # 'new' runs before the compose exists. -T asks for no terminal, as
    # compose spells it, for a run whose output is read. NAME is the
    # entrypoint's own command (new, add, expand…), and names the
    # container after it and this process: two at once — the console
    # reads on every page it serves — must not fight over one name.
  entrypoint_run() {
    local tty_flags=("${DOCKER_TTY_FLAGS[@]}")
    if [ "$1" == "-T" ]; then tty_flags=(); shift; fi
    local name="$1"
    if toolchain_here; then
      entrypoint_here "$@"
    elif [ -f "$WORKSPACE_PATH/$COMPOSE_FILE" ]; then
      # On the workspace's own dev image — the one its Dockerfile.local
      # built, installer stamped — and never as the compose's `app`:
      # `add` and `expand` compile the project and ask nothing of the
      # database or the .env, and the app service would put them in the
      # app's build. This used to be a compose one-off, which also waited
      # for the database to be healthy.
      ensure_build_volumes
      docker run \
        "${tty_flags[@]}" \
        "${COLOR_ENV[@]/#/--env=}" \
        --name "${APP_NAME}_workbench_${name}_$$" \
        --rm \
        --volume "$SOURCE_CODE_VOLUME" \
        --volume "$WORKBENCH_VOLUME" \
        "${BUILD_VOLUMES[@]}" \
        "$LOCAL_IMAGE" "${CONTAINER_ENTRYPOINT[@]}" "$@"
    else
      ensure_build_volumes
      docker run \
        "${tty_flags[@]}" \
        "${COLOR_ENV[@]/#/--env=}" \
        --name "${APP_NAME}_workbench_${name}_$$" \
        --rm \
        --volume "$SOURCE_CODE_VOLUME" \
        --volume "$WORKBENCH_VOLUME" \
        "${BUILD_VOLUMES[@]}" \
        "$TOOLCHAIN_IMAGE" "${CONTAINER_ENTRYPOINT[@]}" "$@"
    fi
  }

  # entrypoint_here [ARGS...]
    # The entrypoint run in this container. It works from /app, where the
    # workspace is 'src' — WORKSPACE_MOUNT — as in a container of its
    # own; the workbench, at its host path here, is named by it.
  entrypoint_here() {
    (cd "$(dirname "$WORKSPACE_MOUNT")" && \
     toolchain_env bash "$WORKBENCH_PATH/scripts/entrypoint.sh" "$@")
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
      (cd "$WORKSPACE_MOUNT" && toolchain_env mix do deps.get, deps.compile, "$@")
    else
      ensure_build_volumes
      docker run \
        "${DOCKER_TTY_FLAGS[@]}" \
        "${COLOR_ENV[@]/#/--env=}" \
        --rm \
        --name "${APP_NAME}_workbench_$1_$$" \
        --volume "$SOURCE_CODE_VOLUME" \
        --volume "$WORKBENCH_VOLUME" \
        "${BUILD_VOLUMES[@]}" \
        --workdir /app/src \
        "$LOCAL_IMAGE" sh -c \
          'exec mix do deps.get, deps.compile, "$@"' \
          mix "$@"
    fi
  }

  # package_igniter <TASK> [ARGS...]
    # A mix task of the igniter package run on the package itself, in the
    # toolchain image, with no project under it. The catalog belongs to
    # the workbench and not to the workspace: it has to answer when the
    # workspace is empty, which is when the New project card needs it.
    # Its build goes under its own root so it never collides with a
    # host's build of the same package.
  package_igniter() {
    docker image inspect "$TOOLCHAIN_IMAGE" > /dev/null 2>&1 || terminate \
      "No toolchain image $TOOLCHAIN_IMAGE yet, and the catalog is read" \
      "with it. Create a project first: ./$(basename "$0") new"
    docker run \
      --rm \
      "${COLOR_ENV[@]/#/--env=}" \
      --name "workbench_package_$1_$$" \
      --volume "$WORKBENCH_PATH/igniter:/app/igniter" \
      --volume "$WORKBENCH_VOLUME" \
      --volume workbench_package_build:/app/igniter/_build \
      --volume workbench_package_deps:/app/igniter/deps \
      --workdir /app/igniter \
      "$TOOLCHAIN_IMAGE" sh -c \
        'mix deps.get > /dev/null 2>&1; exec mix "$@"' \
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
      name=${line%% *}; [ "$name" == "$line" ] && argv="" || argv=${line#* }
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
    # toolchain container otherwise.
  # git_read <ARGS...>
    # A read-only git query on the workspace: with a git on this side
    # (the console container has one; a host may) it runs here — a
    # container start costs seconds and 'status' asks three times —
    # and in the toolchain container otherwise. What writes (init, add,
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
      docker run \
        --rm \
        "${GIT_COLOR_ENV[@]/#/--env=}" \
        "${GIT_IDENTITY_ENV[@]/#/--env=}" \
        --volume "$SOURCE_CODE_VOLUME" \
        --workdir /app/src \
        "$LOCAL_IMAGE" git "$@"
    fi
  }

  # workspace_dirty
    # Succeeds when the workspace has changes git does not have.
  workspace_dirty() {
    [ -n "$(git_read status --porcelain 2>/dev/null)" ]
  }

  # workspace_commit <MESSAGE>
    # Commits everything in the workspace under MESSAGE, when there is
    # anything to commit, and says who signed it.
  workspace_commit() {
    [ -d "$WORKSPACE_PATH/.git" ] || workspace_git init -q
    if workspace_dirty; then
      workspace_git add -A && \
      workspace_git commit -q -m "$1" && \
      echo "Committed ${B}$1${R} (as $GIT_NAME <$GIT_EMAIL>)."
    else
      echo "Nothing to commit."
    fi
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

    workspace_git checkout -- . > /dev/null 2>&1 && \
    workspace_git clean -fdq && \
    echo "Undid what ${B}$1${R} had written before it failed:" \
      "the workspace is back at $(git_read log --format='%h %s' -n 1)."
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
    sed -n 's/^name: //p' "$WORKSPACE_PATH/$COMPOSE_FILE" | head -n 1
  }

  # workspace_containers [FORMAT]
    # Every container of the workspace's compose project, whichever
    # deployment created it — dev and prod share their service names, so
    # the image is what tells them apart. FORMAT is compose's --format.
  workspace_containers() {
    docker compose --project-name "$(compose_project_name)" \
      ps --all --format "${1:-json}" 2>/dev/null
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

  # status_json [--fast]
    # The workspace as one JSON object: whether it holds a project, where
    # it is, its ports, which deployments were baked, which one is up,
    # the containers of its compose project with their addresses, its
    # git, and — 'project' — what 'mix workbench.status --json' says of
    # the cartridges it carries. That last one boots Mix in a container
    # and costs seconds, where the rest costs tenths: '--fast' leaves it
    # out ('project' is then null, as it is when there is no project),
    # for the readings that follow an up or a down, where nothing about
    # the cartridges could have changed.
    # Without a project it still answers, with 'exists' false, so the
    # console can draw the empty workspace instead of an error.
  status_json() {
    local port pgadmin project
    if [ "$EXISTING_PROJECT" != true ]; then
      printf '{\n'
      printf '  "exists": false,\n'
      printf '  "workspace": %s,\n' "$(json_string "$WORKSPACE_PATH")"
      printf '  "compose_project": null,\n'
      printf '  "ports": {"app": null, "pgadmin": null},\n'
      printf '  "baked": {"dev": false, "prod": false, "scaled": false},\n'
      printf '  "deployment": null,\n'
      printf '  "containers": [],\n'
      printf '  "addresses": {},\n'
      printf '  "git": %s,\n' "$(git_json)"
      printf '  "project": null\n'
      printf '}\n'
      return
    fi
    port=$(workspace_app_port)
    pgadmin=$(workspace_pgadmin_port)
    if [ "$1" == "--fast" ]
    then project=""
    else project=$(workspace_igniter workbench.status --json 2>/dev/null | json_answer); fi

    # printf, never echo, and every value as an argument rather than
    # part of the format: what goes in here is JSON already, full of the
    # \n and \\ that a JSON string is made of, and none of it is this
    # script's to read as an escape.
    printf '{\n'
    printf '  "exists": true,\n'
    printf '  "workspace": %s,\n' "$(json_string "$WORKSPACE_PATH")"
    printf '  "compose_project": %s,\n' "$(json_string "$(compose_project_name)")"
    printf '  "ports": {"app": %s, "pgadmin": %s},\n' "${port:-null}" "${pgadmin:-null}"
    printf '  "baked": {\n'
    printf '    "dev": true,\n'
    printf '    "prod": %s,\n' "$([ -f "$WORKSPACE_PATH/$PROD_COMPOSE_FILE" ] && echo true || echo false)"
    printf '    "scaled": %s\n' "$([ -f "$WORKSPACE_PATH/$SCALED_COMPOSE_FILE" ] && echo true || echo false)"
    printf '  },\n'
    printf '  "deployment": %s,\n' "$(d=$(workspace_deployment); [ -n "$d" ] && json_string "$d" || echo null)"
    printf '  "containers": %s,\n' "$(workspace_containers | json_array)"
    printf '  "addresses": %s,\n' "$(workspace_addresses)"
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
    local port pgadmin containers
    port=$(workspace_app_port)
    pgadmin=$(workspace_pgadmin_port)
    containers=$(workspace_containers '{{.Service}} {{.State}}{{if .Health}}/{{.Health}}{{end}} ({{.Image}})')

    echo "${B}Workspace${R}  $WORKSPACE_PATH"
    echo "${B}Project${R}    $(compose_project_name)"
    echo "  app      ${Li}http://localhost:$port${R}"
    [ -n "$pgadmin" ] && echo "  pgAdmin  ${Li}http://localhost:$pgadmin${R}"
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
    workspace_igniter workbench.status 2>/dev/null | sed 's/^/  /'
  }

  # bake_prod_compose
    # Generates the workspace's production compose file (used by the
    # 'up --deploy prod' and 'build --deploy prod' commands): same seed and
    # application port as the dev compose, versioned production image,
    # the one-shot 'migrate' service the app waits for (bake_compose
    # keeps it for this Dockerfile), and — the production image being
    # self-contained — no source code volume nor build identity (its
    # Dockerfile runs as nobody).
  bake_prod_compose() {
    APP_PORT=$(workspace_app_port)
    PGADMIN_PORT=$(first_free_port 5050)
    APP_VERSION=$(
      sed -n 's/^.*version: "\(.*\)".*/\1/p' "$WORKSPACE_PATH/$MIX_FILE" | \
      head -n 1
    )

    bake_compose \
      "$APP_NAME:$APP_VERSION-prod" \
      "$PROD_DOCKERFILE" \
      "$PROD_COMPOSE_FILE" && \
    # The app's volumes go whole — the source mount and the two build
    # volumes with their comment, everything up to depends_on. This
    # took two lines once, the key and the mount, and when the build
    # volumes joined the block the rest was left standing under
    # env_file, where compose read 'build:/app/src/_build' as a file.
    # The top-level declaration goes with them: a release has no
    # _build and no deps to keep.
    sed -i '/^    volumes:/,/^    depends_on:/{/^    depends_on:/!d}' "$WORKSPACE_PATH/$PROD_COMPOSE_FILE" && \
    sed -i '/^volumes:/,/^$/d' "$WORKSPACE_PATH/$PROD_COMPOSE_FILE" && \
    sed -i '/^      # These arguments/,/GID:/d' \
      "$WORKSPACE_PATH/$PROD_COMPOSE_FILE"
  }

  # parse_deploy_args [ARGS...]
    # Reads the options 'up' and 'build' share into DEPLOY_ARG,
    # REPLICAS and BALANCER, leaving everything it did
    # not consume in DEPLOY_REST (passed through to docker compose).
    # --replicas and --balancer only shape how the scaled compose file
    # is baked, so 'logs', 'ps', 'stop' and 'down' never need them: the
    # file they act on is the same either way.
  parse_deploy_args() {
    DEPLOY_ARG=dev
    REPLICAS=$DEFAULT_REPLICAS
    BALANCER=true
    DEPLOY_REST=()

    while [ $# -gt 0 ]; do
      case "$1" in
        --deploy)      DEPLOY_ARG="$2";          shift 2 ;;
        -e|--env)      env_flag_error ;;
        --replicas)    REPLICAS="$2"; shift 2 ;;
        --balancer)    BALANCER=true;  shift ;;
        --no-balancer) BALANCER=false; shift ;;
        *)             DEPLOY_REST+=( "$1" );  shift ;;
      esac
    done

    case "$REPLICAS" in
      ''|*[!0-9]*|0) args_error "--replicas expects a positive integer." ;;
    esac
  }

  # bake_scaled_compose
    # Generates the workspace's scaled compose file from its seed: the
    # production image replicated REPLICAS times on a bridge
    # network, each replica with its own host port. Leaves the chosen
    # ports in the REPLICA_PORTS array.
  bake_scaled_compose() {
    local file_path="$WORKSPACE_PATH/$SCALED_COMPOSE_FILE"
    local services depends upstream
    local port=4000
    local i=1

    APP_VERSION=$(
      sed -n 's/^.*version: "\(.*\)".*/\1/p' "$WORKSPACE_PATH/$MIX_FILE" | \
      head -n 1
    )

    cp "$SCRIPTS_DIR/$SCALED_COMPOSE_SEED" "$file_path"

    # The balancer takes the first free port: it is the deployment's single
    # entry point. Every replica publishes its own too, so a specific
    # node can still be addressed — which is how the cross-node
    # behaviour is demonstrated.
    if [ "$BALANCER" == true ]; then
      BALANCER_PORT=$(first_free_port $port)
      port=$((BALANCER_PORT + 1))
    fi

    services=$(mktemp)
    depends=$(mktemp)
    upstream=$(mktemp)
    REPLICA_PORTS=()

    while [ "$i" -le "$REPLICAS" ]; do
      port=$(first_free_port $port)
      REPLICA_PORTS+=( "$port" )

      printf '  app%s:\n    <<: *app\n    ports:\n      - %s:%s\n\n' \
        "$i" "$port" "$APP_INTERNAL_PORT" >> "$services"
      printf '      app%s:\n        condition: service_started\n' \
        "$i" >> "$depends"
      printf '        server app%s:%s;\n' \
        "$i" "$APP_INTERNAL_PORT" >> "$upstream"

      port=$((port + 1))
      i=$((i + 1))
    done

    # 'r' queues the generated block after the marker line, 'd' drops the
    # marker: no escaping of newlines into a sed replacement.
    sed -i -e "/%{app_services}/r $services"     -e "/%{app_services}/d"     "$file_path"
    sed -i -e "/%{balancer_depends}/r $depends"  -e "/%{balancer_depends}/d" "$file_path"
    sed -i -e "/%{upstream_servers}/r $upstream" -e "/%{upstream_servers}/d" "$file_path"
    rm -f "$services" "$depends" "$upstream"

    sed -i "s/%{app_name}/$ELIXIR_PROJECT_NAME/g"                  "$file_path"
    sed -i "s/%{compose_image}/$APP_NAME:$APP_VERSION-prod/g"      "$file_path"
    sed -i "s/%{compose_dockerfile}/$PROD_DOCKERFILE/g"            "$file_path"
    sed -i "s/%{balancer_port}/$BALANCER_PORT/"                    "$file_path"
    sed -i "s/%{nginx_image_version}/$NGINX_IMAGE_VERSION/"        "$file_path"
    sed -i "s/%{postgres_image_version}/$POSTGRES_IMAGE_VERSION/"  "$file_path"

    # Without the clustering feature the release is not distributed, so
    # DNSCluster would poll DNS forever, connect to nobody and warn about
    # it on every boot. Leaving the variable unset keeps it out of the
    # supervision tree (runtime.exs falls back to :ignore).
    clustering_installed || sed -i '/^    DNS_CLUSTER_QUERY:/d' "$file_path"

    # Without a balancer the replicas are only reachable on their own
    # ports; its nginx config goes with it.
    if [ "$BALANCER" == false ]; then
      sed -i '/^  # Single entry point/,/^$/d' "$file_path"
      sed -i '/^configs:/,$d'                  "$file_path"
    fi

    # Projects without a database server have nothing to migrate and no
    # database: drop both services and the app anchor's references to them.
    if ! workspace_needs_database
    then
      sed -i '/^  # One-shot migration/,/^configs:/{/^configs:/!d}' "$file_path"
      sed -i '/^  depends_on:$/,+2d'                                "$file_path"
      sed -i '/^    DATABASE_URL:/d'                                "$file_path"
    fi
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
    if [ "$BALANCER" == true ]; then
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
    if [ "$BALANCER" == true ]; then
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
    print_command() { echo "  ${B}$1${R}"; }
    section_content() {
      for arg in "$@"
      do
        echo "  $arg"
      done
      echo
    }

    local script_name
    script_name=$(basename "$0")

    section "NAME"
    section_content "$(sed -n '2s/# //p' "$0")"

    section "VERSION"
    section_content \
      "$WORKBENCH_VERSION"

    section "SYNTAXIS"
    section_content \
      "./$script_name [-y, --yes] [COMMAND]" \
      "- --yes: Answer every confirmation ('new' over an existing project," \
      "  'delete'), for scripts and tools driving the workbench."

    section "DESCRIPTION"
    section_content \
      "This is a script for creating ${B}Elixir${R} (${Li}https://elixir-lang.org${R}) projects" \
      "with the ${B}Phoenix${R} (${Li}https://www.phoenixframework.org${R}) framework and" \
      "deploying them on 'localhost' using a specific service architecture with" \
      "Docker containers. It eliminates the need to install anything other than" \
      "${B}Docker Desktop${R} (${Li}https://www.docker.com/products/docker-desktop${R}) in order" \
      "to create, develop and deploy the project as 'dev' or 'prod' enviroment." \
      "" \
      "The workbench stays permanently in this directory. Projects are" \
      "generated into the ${B}WORKSPACE_PATH${R} directory (config.conf), each one" \
      "owning its docker-compose.yml with its name, ports and images baked" \
      "in — several workspaces can run simultaneously without conflicts." \
      "The Elixir configuration is delegated to the ${B}workbench_igniter${R}" \
      "package (igniter/): 'new' runs 'mix workbench.setup' inside the" \
      "container, which only makes a stock phx.new project bootable here." \
      "Features are cartridges, added one commit each with the 'add'" \
      "command — 'add chiefs_setup' inserts the workbench's own picks." \
      "" \
      "Current workspace: $WORKSPACE_PATH"

    section "COMMANDS"
    print_command "login [USER] [TOKEN]"
    section_content \
      "Login account in order to download private images." \
      "- USER:  Github username. " \
      "- TOKEN: Authentication token (classic). "

    print_command "new [OPTIONS]"
    section_content \
      "Create a new ${B}vanilla${R} project in the workspace: 'mix phx.new'" \
      "plus only what this workbench needs to run it. Step by step:" \
      "  1. 'mix phx.new' generates the stock project." \
      "  2. The workbench_igniter package is registered in its mix.exs." \
      "  3. 'mix workbench.setup' binds the dev endpoint to 0.0.0.0 (the" \
      "     published port never reaches loopback), writes .env and" \
      "     .env.sample (the compose env_file) and lists .env in .gitignore." \
      "  4. 'mix phx.gen.release --docker' adds the production Dockerfile," \
      "     .dockerignore and rel/overlays, which phx.new does not generate" \
      "     but 'up --deploy prod' needs. Distributed releases are not set up:" \
      "     that is the 'clustering' feature." \
      "  5. The workspace gets its Dockerfile.local and docker-compose.yml." \
      "  6. The first commit, 'New project: …', signed as GIT_IDENTITY says:" \
      "     the baseline every inserted cartridge is a commit on top of." \
      "The Elixir project keeps its phx.new configuration untouched: install" \
      "the workbench features with the 'add' command — 'add chiefs_setup'" \
      "inserts the workbench's own picks, one commit each." \
      "- OPTIONS: It can accept all option flags from the task 'mix phx.new'" \
      "  (${Li}https://hexdocs.pm/phoenix/Mix.Tasks.Phx.New.html${R})." \
      "- --phx-new VERSION: the Phoenix installer to generate with, for" \
      "  this run. PHX_NEW_VERSION (config.conf) holds a standing choice;" \
      "  empty — the ordinary case — hex decides, and what it decides is" \
      "  the newest release that runs on this stack, said out loud when" \
      "  that is not hex's newest. A named version is refused if hex does" \
      "  not have it — a typo has no requirement to weigh — and otherwise" \
      "  weighed against the stack: phx_new declares on hex the Elixir it" \
      "  runs on, and a stack that does not meet it is refused here, not" \
      "  halfway into the image. Whichever way it is decided, the version" \
      "  is stamped into the workspace's own Dockerfile.local and config" \
      "  is never written: the generator the base cartridges take their" \
      "  delta with is the project's, for good, not a default that moves."

    print_command "add [FEATURE] [OPTIONS]"
    section_content \
      "Install a workbench feature on the existing project, one commit" \
      "per inserted cartridge ('Insert FEATURE …'), so 'eject' can revert" \
      "each alone. Needs a clean tree: commit pending changes first." \
      "A collection (chiefs_setup) is expanded first and each missing" \
      "member is inserted as its own commit." \
      "- FEATURE: One of: chiefs_setup, ansi, toolchain, versioning," \
      "  healthcheck, rest, graphql, coveralls, exdoc, guidelines," \
      "  enhancements, auth0, openai, credo, githooks, exmachina, mock," \
      "  exdebug, psql_extras, osmon, clustering, healthcheck2, ash," \
      "  mailer, gettext, ecto, esbuild, tailwind, html, live, dashboard." \
      "- OPTIONS: Flags for the 'mix workbench.install.FEATURE' task."

    print_command "eject [FEATURE]"
    section_content \
      "Take a cartridge out: reverts its 'Insert FEATURE' commit (the" \
      "latest one). Needs a clean tree, and refuses when the cartridge's" \
      "files changed since — that is no longer the cartridge's alone." \
      "It also refuses while something the project carries builds on it" \
      "('mix workbench.dependents FEATURE'), naming them in the order to" \
      "take them out: inserting names what to put in first, and this is" \
      "the same rule read backwards."

    print_command "stacks [--json | -n N | use TAG]"
    section_content \
      "The usable technology stacks, asked of Docker Hub itself: the" \
      "recent hexpm/elixir -debian-*-slim images. config.conf keeps no" \
      "list — this is the list." \
      "- (nothing): the recent ones, the configured one marked." \
      "- --json: every usable tag, one array, for tools." \
      "- use TAG: check the image exists and write the three versions" \
      "  into config.conf."

    print_command "engine [native | desktop | toggle | NAME]"
    section_content \
      "Which Docker the script talks to — the CLI's context, kept per" \
      "user across terminals. On Linux there are two: the native engine" \
      "('native', context 'default') and Docker Desktop's VM ('desktop')," \
      "and the VM falls under a compile through its file sharing, so the" \
      "workbench wants the native one there. Nothing is shared between" \
      "them: images, volumes and containers built on one are not on the" \
      "other." \
      "- (nothing): the current one, and the list." \
      "- toggle: the other one."

    print_command "console [up|down|logs|build]"
    section_content \
      "The workbench's console: a Phoenix LiveView page that shows the" \
      "workspace and drives this script — as a container, with Docker's" \
      "socket and the workbench mounted, on the first free port from 4100," \
      "published on 127.0.0.1 only: it runs this script with --yes." \
      "- up (default): build the image if missing — and the toolchain" \
      "  it stands on, when the daemon has none — and start it." \
      "- down, logs: stop it, follow its output." \
      "- build: build the image again (the Docker CLI in it follows the host)."

    print_command "bake"
    section_content \
      "Bake the workspace's compose again from the seed, for the project" \
      "as it is now — with the database and pgAdmin when it runs on a" \
      "database server, without them when it does not (or on SQLite) —" \
      "keeping its ports, as one commit. What 'add ecto' asks for next." \
      "The toolchain Dockerfile is baked again too when the seed moved," \
      "keeping the project's own Phoenix installer, and its image rebuilt." \
      "Needs a clean tree. The prod and scaled composes are baked at" \
      "their own deployment."

    print_command "commit [MESSAGE | --message-file PATH]"
    section_content \
      "Commit everything the workspace has, from the toolchain container" \
      "(the project's git hooks can run mix there), signed as the" \
      "GIT_IDENTITY of config.conf: 'user' takes the host's git identity" \
      "when there is one, 'workbench' signs as the workbench." \
      "- MESSAGE: Default: 'Workbench: commit pending changes'." \
      "- --message-file: The message off a file, title and body: how the" \
      "  console's Git screen hands over what the reader wrote."

    print_command "catalog [--json]"
    section_content \
      "List every cartridge the workbench has: name, version, how it is" \
      "enabled and what it installs — with the options of its installer" \
      "and which of its box covers exist, in the JSON form. Read by the" \
      "igniter package ('mix workbench.catalog'): through the project" \
      "when there is one, off the package itself when the workspace is" \
      "empty — the catalog is the workbench's, not the workspace's." \
      "- --json: One JSON array, for tools."

    print_command "config set KEY=VALUE [KEY=VALUE …]"
    section_content \
      "Write values into config.conf in place — comments and order stay." \
      "A key the file does not export is refused. The one writer of the" \
      "file besides 'stacks use': the console saves its form through it."

    print_command "expand [--json] CARTRIDGE [OPTIONS]"
    section_content \
      "What 'add CARTRIDGE OPTIONS' would insert, without inserting it:" \
      "the cartridge itself, or — for a collection — the members its" \
      "options choose, minus what the project already carries. One" \
      "'NAME [ARGV]' per line, in the order 'add' runs them." \
      "- --json: One JSON array of {name, argv}, for tools."

    print_command "status [--json [--fast]]"
    section_content \
      "Where the workspace stands: its ports, which deployments were" \
      "baked and which is up, its containers with their addresses, its" \
      "git, and which cartridges the project carries ('mix" \
      "workbench.status': each cartridge answers off the same mark its" \
      "installer checks, so this and 'add' never disagree)." \
      "- --json: One JSON object, for tools. Answers on an empty" \
      "  workspace too, with 'exists' false." \
      "- --fast: the same without asking the cartridges, which boots" \
      "  Mix in a container: tenths of a second instead of seconds," \
      "  'project' null."

    print_command "up [--deploy TARGET] [--replicas N] [--no-balancer]"
    section_content \
      "Deploy the application on localhost, detached: the terminal stays" \
      "free and the containers keep running ('logs' follows their output)." \
      "- TARGET: Deployment to bring up (Defalut: dev)." \
      "  ${B}prod${R} deploys the release image on the dev compose's pod layout." \
      "  A one-shot 'migrate' service runs the migrations first and the" \
      "  app waits for it — the release phase of every platform, under" \
      "  Compose's name for it." \
      "  ${B}scaled${R} deploys production replicas behind an nginx balancer:" \
      "  each one gets its own IP and host port, and they all share the" \
      "  'app' network alias. It replaces the pod network layout of the" \
      "  dev compose, so the database is reached by name, not on" \
      "  localhost. Meant for seeing a replicated deployment work, not" \
      "  for developing." \
      "  With the 'clustering' feature installed the replicas also form a" \
      "  real BEAM cluster: Docker's DNS answers that shared alias with" \
      "  every address, which is what DNSCluster queries to connect them." \
      "  Without it they run isolated, which is a valid deployment for a" \
      "  stateless application — the command warns and carries on." \
      "- N: Replicas of the scaled deployment (Default: $DEFAULT_REPLICAS)." \
      "- --no-balancer: Skip the nginx front and publish only the" \
      "  per-replica ports. Both options are baked into the compose file," \
      "  so 'logs', 'ps', 'stop' and 'down' never need them."

    print_command "build [--deploy TARGET] [OPTIONS]"
    section_content \
      "(Re)build the workspace's app image without deploying it: the" \
      "dev image from the project's Dockerfile.local, or the production" \
      "release image ('up --deploy prod' also rebuilds it on each deploy)." \
      "- TARGET: Deployment whose image to build (Defalut: dev). 'scaled'" \
      "  builds the same production image every replica shares, and takes" \
      "  the same --replicas and --no-balancer as 'up'. Whether that image is" \
      "  distributed is baked in by the 'clustering' feature, so" \
      "  installing it afterwards means building again." \
      "- OPTIONS: Flags for 'docker compose build', e.g. --no-cache."

    print_command "logs [--deploy TARGET] [SERVICE...]"
    section_content \
      "Follow the workspace containers logs (Ctrl+C detaches, the" \
      "containers keep running)." \
      "- TARGET: Deployment whose logs to read (Defalut: dev)." \
      "- SERVICE: Restrict to some services (app, database, pgadmin;" \
      "  migrate too with '--deploy prod'; app1..appN, balancer and" \
      "  migrate with '--deploy scaled')."

    print_command "stop | down | ps | restart [--deploy TARGET] [SERVICE...]"
    section_content \
      "Stop, remove, list or restart the workspace containers ('stop'" \
      "keeps them for a fast restart with 'up'; 'down' removes them;" \
      "'restart' brings the named services up again, the deployment" \
      "left whole)." \
      "- TARGET: Deployment to act on (Defalut: dev)." \
      "- SERVICE: Restrict to some services (app, database, pgadmin;" \
      "  migrate too with '--deploy prod'; app1..appN, balancer and" \
      "  migrate with '--deploy scaled')."

    print_command "prune [--images | --build]"
    section_content \
      "Remove what no live workspace uses — never this workspace's" \
      "deployment, never the console: the stopped containers of other" \
      "compose projects with their anonymous volumes, and the networks" \
      "and named volumes of those projects that nothing mounts (a" \
      "database's data goes with them). Always asks first." \
      "- --images: Instead, remove the untagged images every prod bake" \
      "  leaves behind." \
      "- --build: Instead, remove this workspace's two build volumes, so" \
      "  the next 'up' compiles from scratch. Refused while the app" \
      "  mounts them: bring the deployment down first."

    print_command "iex | bash [--deploy TARGET] [SERVICE]"
    section_content \
      "Open an IEx shell (or a plain shell) on a running container of the" \
      "workspace; exiting does not stop the application." \
      "- TARGET: Deployment to attach to (Defalut: dev). Outside" \
      "  dev the container runs the release, which carries no Mix, so" \
      "  'iex' opens its remote shell ('bin/<app> remote') instead." \
      "- SERVICE: Service to attach to (Defalut: app). The scaled" \
      "  deployment names its replicas app1..appN."

    print_command "mix [ARGS...]"
    section_content \
      "Run a mix task: on the running app container when the system is" \
      "up (fast), or on a one-off container otherwise. The database" \
      "needs no command of its own: the dev image creates and migrates" \
      "it on boot, the release deployments migrate before the app" \
      "starts — and a dev reset with the seeds is 'mix ecto.reset'." \
      "- ARGS: The task and its options, e.g.: cover, docs, test," \
      "  ecto.reset."

    print_command "delete"
    section_content \
      "Deletes the workspace project files and its Docker compose project."

    print_command "demo [--deploy TARGET]"
    section_content \
      "Runs consecutively new, up, logs & delete commands: the logs" \
      "block the demo while the application is tried out, and Ctrl+C" \
      "moves on to the teardown." \
      "- TARGET: Deployment to run end to end (Defalut: dev)."

    print_command "help"
    section_content \
      "Displays the help section for the workbench script."

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
    [ "$ECTO" == false ] && SETUP_FLAGS+=( --no-ecto )
    true
  }

  # resolve_installer
    # The Phoenix installer, in order of authority: PHX_NEW_VERSION as
    # it stands (--phx-new for one run, the workspace's stamp), the
    # setting in config.conf, hex for everyone else — and with it the
    # toolchain image's tag, which carries the installer. Shared by
    # 'new', which stamps the answer into the workspace, and by
    # 'console', which builds the toolchain its image stands on when
    # the daemon has none.
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
      if [ "$PHX_NEW_NAMED" == "setting" ]; then
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

      if [ "$PHX_NEW_VERSION" == "$PHX_NEW_NEWEST" ]
      then echo "Phoenix installer: ${B}phx_new $PHX_NEW_VERSION${R} (the newest on hex; --phx-new names another)."
      # Not the newest, and never silently: nobody named a version and
      # the answer is not the obvious one, so the reason travels with it.
      else echo "Phoenix installer: ${B}phx_new $PHX_NEW_VERSION${R} (the newest that runs on Elixir" \
        "$ELIXIR_VERSION; hex's newest is $PHX_NEW_NEWEST, which needs Elixir $PHX_NEW_NEWEST_REQUIREMENT)."
      fi
    fi

    TOOLCHAIN_IMAGE="workbench:${ELIXIR_VERSION}-${ERLANG_VERSION}-phx${PHX_NEW_VERSION}"
  }

  # build_toolchain
    # The toolchain image, off the baked scripts/Dockerfile.local: the
    # stack, the installer, git, and the UID/GID of this user.
  build_toolchain() {
    ( cd "$SCRIPTS_DIR" && \
      docker build \
        --build-arg UID="$(id -u)" \
        --build-arg GID="$(id -g)" \
        --file "$LOCAL_DOCKERFILE" --tag "$TOOLCHAIN_IMAGE" . )
  }

  # create_project <SETUP_COMMAND> [PHOENIX_NEW_OPTIONS...]
    # Body of the 'new' command: prepares the workspace, builds the
    # toolchain image, generates the Phoenix project, registers the
    # igniter package and runs SETUP_COMMAND (the 'workbench_setup'
    # entrypoint branch) with the SETUP_FLAGS its builder left. Finally
    # bakes the workspace's own dockerfile and compose file.
  create_project() {
    local setup_command="$1"; shift

    prepare_workspace && \
    ensure_build_volumes && \
    build_toolchain && \
    docker tag "$TOOLCHAIN_IMAGE" "$LOCAL_IMAGE" && \
    entrypoint_run new "$ELIXIR_PROJECT_NAME" "$@" && \
    register_igniter_package && \
    entrypoint_run "$setup_command" "${SETUP_FLAGS[@]}" && \
    # The project keeps its own baked copy of the toolchain dockerfile,
    # so a standalone clone (no workbench) can rebuild the same dev
    # image: the compose build points at it.
    cp "$SCRIPTS_DIR/$LOCAL_DOCKERFILE" "$WORKSPACE_PATH/$LOCAL_DOCKERFILE" && \
    # The workspace owns its orchestration: compose with real values.
    # Its build points to the project-owned Dockerfile.local — and must
    # stay there: its app service also runs the workbench one-off
    # commands (add, mix), which need the toolchain. The
    # production deployment never touches this file: 'up --deploy prod'
    # bakes docker-compose.prod.yml from the same seed with the
    # production Dockerfile.
    bake_compose "$LOCAL_IMAGE" "$LOCAL_DOCKERFILE" "$COMPOSE_FILE"
  }

# SCRIPT =======================================================================

if [ $# -gt 0 ]; then
  # The invoked command, for messages written before any branch shifts it.
  COMMAND_NAME="$1"

  if   [ "$1" == "login" ]; then
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

  elif [ "$1" == "new" ]; then
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
        *) PHX_NEW_ARGS+=("$1"); shift ;;
      esac
    done
    set -- "${PHX_NEW_ARGS[@]}"
    require_stack_floor "$ELIXIR_VERSION"
    resolve_installer

    # Host ports for this workspace: first available ones.
    APP_PORT=$(first_free_port 4000)
    PGADMIN_PORT=$(first_free_port 5050)

    # The vanilla creation: config.conf only names the project, the
    # workspace and the stack versions, since they shape the project
    # generation and the images, not the Elixir configuration — that
    # arrives afterwards, as cartridges ('./wb.sh add').
    build_setup_flags "$@" && \
    create_project workbench_setup "$@" && \
    workspace_commit "New project: $ELIXIR_PROJECT_NAME"

  elif [ "$1" == "add" ]; then
    shift

    if [ "$EXISTING_PROJECT" == true ]; then
      if [ $# -gt 0 ]; then
        require_clean_workspace add

        # The cartridge expands to the inserts to run: itself for a
        # plain one, its missing members for a collection
        # (chiefs_setup). Only the 'plan> ' lines are the plan; the
        # rest is mix noise. Each insert then runs as its own container
        # and its own commit, so 'eject' reverts one cartridge alone —
        # a collection leaves no commit of its own.
        PLAN=$(expand_plan "$@") || terminate "Could not expand '$1'."

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
            if entrypoint_run add $INSERT
            then workspace_commit "Insert $INSERT" || exit 1
            else undo_failed_insert "$INSERT"; exit 1
            fi
          done 3<<< "$PLAN"

          if workspace_needs_database && \
             ! grep -q "^  database:" "$WORKSPACE_PATH/$COMPOSE_FILE"; then
            echo "The project now runs on a database and the compose has none:" \
              "./$(basename "$0") bake bakes it in, and the next up creates it."
          fi
        fi

      else args_error "Missing feature name. Try: ./$(basename "$0") add healthcheck"; fi
    else terminate "There is no project to add features to."; fi

  elif [ "$1" == "eject" ]; then
    shift
    if [ "$EXISTING_PROJECT" == true ]; then
      [ $# -gt 0 ] || args_error "Missing feature name. Try: ./$(basename "$0") eject credo"
      FEATURE=$1
      require_clean_workspace eject
      # The latest insert of this cartridge: its subject starts with the
      # feature name, whole word (so 'healthcheck' never matches
      # 'healthcheck2').
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
      if workspace_git revert --no-edit "$SHA" > /dev/null; then
        echo "Ejected ${B}$FEATURE${R}: $(workspace_git log --format='%h %s' -n 1)" \
          "(as $GIT_NAME <$GIT_EMAIL>)."
      else
        workspace_git revert --abort 2>/dev/null
        terminate \
          "The revert does not apply: files the cartridge wrote changed since" \
          "it was inserted, so they are no longer the cartridge's alone." \
          "Revert it by hand in the workspace, or undo those changes first."
      fi

    else terminate "There is no project."; fi

  elif [ "$1" == "stacks" ]; then
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
          [ "$FIRST" == true ] && FIRST=false || printf ','
          printf '\n  "%s"' "$t"
        done; printf '\n]\n' ;;
      ""|-n)
        [ "$1" == "-n" ] && N="$2" || N=12
        CURRENT="${ELIXIR_VERSION}-erlang-${ERLANG_VERSION}-debian-${DEBIAN_VERSION}"
        LIST=$(stacks_list | head -n "$N") || terminate "Docker Hub did not answer."
        echo "Usable hexpm/elixir images (highest first; pick one: ./$(basename "$0") stacks use TAG):"
        echo "$LIST" | while read -r t; do
          if [ "$t" == "$CURRENT" ]
          then echo "  ${B}* $t${R} (config.conf)"
          else echo "    $t"; fi
        done
        echo "$LIST" | grep -q "^$CURRENT\$" || \
          echo "  ${B}* $CURRENT${R} (config.conf — not among the recent $N)" ;;
      *) args_error invalid ;;
    esac

  elif [ "$1" == "engine" ]; then
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
        if [ "$(docker context show)" == "default" ] && docker context inspect desktop-linux > /dev/null 2>&1
        then docker context use desktop-linux > /dev/null 2>&1
        else docker context use default > /dev/null 2>&1; fi
        engine_say ;;
      native)  docker context use default > /dev/null 2>&1 && engine_say ;;
      desktop) docker context use desktop-linux > /dev/null 2>&1 && engine_say ;;
      *)       docker context use "$1" > /dev/null 2>&1 && engine_say ;;
    esac

  elif [ "$1" == "console" ]; then
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
    # image is the toolchain, so wb.sh run in here does its mix and git
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
    CONSOLE_IMAGE="workbench-console:${ELIXIR_VERSION}-${ERLANG_VERSION}"
    CONSOLE_NAME="workbench_console"
    CONSOLE_DIR="$WORKBENCH_PATH/console"

    # ensure_toolchain
      # The toolchain image the console's is built on, built here when
      # the daemon has none — with the installer 'new' would pick, so
      # the project to come finds it built and builds nothing twice. It
      # used to send the reader to 'new' instead: on a daemon pruned
      # clean the console could not start until a project existed,
      # which put the first act behind the very screen that offers it.
      # A toolchain built before the installer was part of the tag
      # (workbench:ELIXIR-OTP) still serves.
    ensure_toolchain() {
      docker image inspect "$TOOLCHAIN_IMAGE" > /dev/null 2>&1 && return
      LEGACY_TOOLCHAIN="workbench:${ELIXIR_VERSION}-${ERLANG_VERSION}"
      docker image inspect "$LEGACY_TOOLCHAIN" > /dev/null 2>&1 && \
        { TOOLCHAIN_IMAGE="$LEGACY_TOOLCHAIN"; return; }
      echo "No toolchain image yet: the console's is built on it, so it comes first (minutes)."
      resolve_installer && \
      create_local_dockerfile && \
      build_toolchain
    }

    console_build() {
      docker build \
        --build-arg "TOOLCHAIN=$TOOLCHAIN_IMAGE" \
        --build-arg "DOCKER_VERSION=$(docker version --format '{{.Server.Version}}')" \
        --build-arg "COMPOSE_VERSION=$(docker compose version --short | sed 's/-.*//')" \
        --tag "$CONSOLE_IMAGE" "$CONSOLE_DIR"
    }

    case "$1" in
      ""|up)
        # The console's image is built on the toolchain's; built once,
        # the console serves an empty workspace too, where 'new' is the
        # first act.
        docker image inspect "$CONSOLE_IMAGE" > /dev/null 2>&1 || {
          # shellcheck disable=SC2015  # terminate is wanted when either step fails
          ensure_toolchain && console_build || terminate "The console image did not build."
        }
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
            "$CONSOLE_IMAGE" sh -c "sleep 2; ./$(basename "$0") console" > /dev/null && \
          echo "The console starts again in a moment, for ${B}$WORKSPACE_PATH${R}," \
            "on the same address: this page reconnects on its own."
          exit 0
        fi
        # The port: the one the console already has, so its address
        # survives a start-again; the first free one from 4100 otherwise.
        CONSOLE_PORT=$(docker port "$CONSOLE_NAME" 4000/tcp 2>/dev/null | sed -n 's/.*://p' | head -n 1)
        [ -n "$CONSOLE_PORT" ] || CONSOLE_PORT=$(first_free_port 4100)
        docker rm -f "$CONSOLE_NAME" > /dev/null 2>&1
        # The socket's group as the container sees it — not the host's:
        # under Docker Desktop the mounted socket is the VM's, root-owned.
        SOCKET_GID=$(docker run --rm --volume /var/run/docker.sock:/var/run/docker.sock \
          "$CONSOLE_IMAGE" stat -c %g /var/run/docker.sock)
        # The workspace's directory and its two mount points made here,
        # as this user: a bind mount's missing target lands root-owned.
        mkdir -p "$WORKSPACE_PATH" && ensure_build_volumes && \
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
          --env "WORKBENCH_PATH=$WORKBENCH_PATH" \
          --add-host host.docker.internal:host-gateway \
          --env APP_HOST=host.docker.internal \
          --workdir "$CONSOLE_DIR" \
          --env HOME=/home/elixir \
          --env "WORKBENCH_DIR=$WORKBENCH_PATH" \
          --env "WORKBENCH_PATH=$WORKBENCH_PATH" \
          --env PORT=4000 \
          --publish "127.0.0.1:$CONSOLE_PORT:4000" \
          "$CONSOLE_IMAGE" > /dev/null && \
        echo "The console is coming up on ${B}http://localhost:$CONSOLE_PORT${R}" \
          "(first run compiles it: ./$(basename "$0") console logs)." ;;
      down)  docker rm -f "$CONSOLE_NAME" > /dev/null 2>&1 && echo "Console down." || echo "The console was not up." ;;
      logs)  docker logs --follow "$CONSOLE_NAME" ;;
      build) ensure_toolchain && console_build ;;
      *)     args_error invalid ;;
    esac

  elif [ "$1" == "bake" ]; then
    if [ "$EXISTING_PROJECT" == true ]; then
      require_clean_workspace bake
      # A workspace baked before the volumes moved over _build and deps
      # has neither directory yet.
      ensure_build_volumes
      # The workspace keeps its ports; the compose is where they live.
      APP_PORT=$(workspace_app_port)
      PGADMIN_PORT=$(workspace_pgadmin_port)
      [ -n "$APP_PORT" ]     || APP_PORT=$(first_free_port 4000)
      [ -n "$PGADMIN_PORT" ] || PGADMIN_PORT=$(first_free_port 5050)

      # The toolchain Dockerfile too: the seed may have moved since this
      # project was born — where Mix compiles, what the image carries —
      # and the workspace keeps the copy its image is built from. The
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
          --file "$WORKSPACE_PATH/$LOCAL_DOCKERFILE" --tag "$TOOLCHAIN_IMAGE" "$SCRIPTS_DIR" && \
        docker tag "$TOOLCHAIN_IMAGE" "$LOCAL_IMAGE" && \
        echo "$LOCAL_DOCKERFILE baked again, and the image with it."
      fi

      bake_compose "$LOCAL_IMAGE" "$LOCAL_DOCKERFILE" "$COMPOSE_FILE" && \
      if workspace_dirty; then
        workspace_commit "Bake $COMPOSE_FILE" && \
        if workspace_needs_database; then
          echo "The compose now has the database: the next up creates it."
        fi
      else
        echo "$COMPOSE_FILE is already what the project asks for: nothing to bake."
      fi
    else terminate "There is no project."; fi

  elif [ "$1" == "commit" ]; then
    shift
    if [ "$EXISTING_PROJECT" == true ]; then
      # The message: the words that follow, or a file with a title and
      # a body — the console's, whose jobs travel as argv and cannot
      # carry a line break.
      if [ "$1" == "--message-file" ]; then
        [ -r "$2" ] || terminate "No message file at '$2'."
        workspace_commit "$(cat "$2")"
      else
        workspace_commit "${*:-Workbench: commit pending changes}"
      fi
    else terminate "There is no project to commit."; fi

  elif [ "$1" == "catalog" ]; then
    shift
    # The catalog is the workbench's, not the workspace's: with a project
    # it is read through the project (the package is a dependency there
    # already, compiled); without one, off the package itself.
    if [ "$EXISTING_PROJECT" == true ]
    then CATALOG_READER=workspace_igniter
    else CATALOG_READER=package_igniter; fi
    case "$1" in
      --json) $CATALOG_READER workbench.catalog --json \
                --covers /app/workbench/assets/covers 2>/dev/null | json_answer ;;
      "")     $CATALOG_READER workbench.catalog ;;
      *)      args_error invalid ;;
    esac

  elif [ "$1" == "status" ]; then
    shift
    case "$1" in
      --json) status_json "$2" ;;
      "")     if [ "$EXISTING_PROJECT" == true ]
              then status_report
              else terminate "There is no project in $WORKSPACE_PATH."; fi ;;
      *)      args_error invalid ;;
    esac

  elif [ "$1" == "config" ]; then
    shift
    # The one writer of config.conf: 'set KEY=VALUE …' writes each value
    # in place — comments and order stay — on the same sed 'stacks use'
    # writes the three versions with. A key the file does not export is
    # refused, so a typo never grows a new line. The console saves its
    # form through here, as a job.
    case "$1" in
      set)
        shift
        [ $# -gt 0 ] || args_error "Missing assignments. Try: ./$(basename "$0") config set PROJECT_NAME=\"My App\""
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

  elif [ "$1" == "expand" ]; then
    shift
    # The planning half of 'add', on its own: what inserting CARTRIDGE
    # with these options would run, one per line — or as JSON — minus
    # what the project already carries. Nothing is written.
    if [ "$EXISTING_PROJECT" == true ]; then
      [ "$1" == "--json" ] && { EXPAND_JSON=true; shift; } || EXPAND_JSON=false
      if [ $# -gt 0 ]; then
        PLAN=$(expand_plan "$@") || terminate "Could not expand '$1'."
        if $EXPAND_JSON
        then echo "$PLAN" | plan_json
        else echo "$PLAN"; fi
      else args_error "Missing cartridge name. Try: ./$(basename "$0") expand chiefs_setup"; fi
    else terminate "There is no project to expand a cartridge against."; fi

  elif [ "$1" == "up" ]; then
    COMPOSE_COMMAND=$1; shift
    if [ "$EXISTING_PROJECT" == true ]; then
      parse_deploy_args "$@"

      # Every deployment of a workspace shares one compose project, but
      # not the same services: dev has 'app', prod adds 'migrate', the
      # scaled one has app1..N plus balancer and migrate, and
      # --replicas/--no-balancer change that set between runs. Without --remove-orphans the containers of
      # the previous shape stay up, unmanaged and invisible to 'ps'.
      if [ "$DEPLOY_ARG" == "scaled" ]; then
        bake_scaled_compose && \
        docker compose \
          --file "$WORKSPACE_PATH/$SCALED_COMPOSE_FILE" \
          "$COMPOSE_COMMAND" --detach --build --remove-orphans && \
        scaled_deployed_message

      elif [ "$DEPLOY_ARG" == "prod" ]; then
        bake_prod_compose && \
        docker compose \
          --file "$WORKSPACE_PATH/$PROD_COMPOSE_FILE" \
          "$COMPOSE_COMMAND" --detach --build --remove-orphans && \
        deployed_message

      else
        workspace_compose "$COMPOSE_COMMAND" --detach --remove-orphans && \
        deployed_message
      fi

    else terminate "There is no project to deploy."; fi

  elif [ "$1" == "build" ]; then
    shift
    if [ "$EXISTING_PROJECT" == true ]; then
      parse_deploy_args "$@"

      if [ "$DEPLOY_ARG" == "scaled" ]; then
        # Said before building: whether the image comes out distributed is
        # decided by rel/env.sh.eex, which mix release bakes into it, so
        # installing the feature afterwards means building again.
        clustering_warning
        # Every replica shares one image: building app1 builds them all.
        bake_scaled_compose && \
        docker compose \
          --file "$WORKSPACE_PATH/$SCALED_COMPOSE_FILE" build app1 "${DEPLOY_REST[@]}"

      elif [ "$DEPLOY_ARG" == "prod" ]; then
        bake_prod_compose && \
        docker compose \
          --file "$WORKSPACE_PATH/$PROD_COMPOSE_FILE" build app "${DEPLOY_REST[@]}"

      else
        # Rebuilds the workspace's own dev image (APP:local) from its
        # project-owned Dockerfile.local; the next 'up' recreates the
        # containers with it.
        workspace_compose build app "${DEPLOY_REST[@]}"
      fi

    else terminate "There is no project to build."; fi

  elif [ "$1" == "logs" ]; then
    shift
    if [ "$EXISTING_PROJECT" == true ]; then
      case "$1" in
        --deploy) DEPLOY_ARG="$2"; shift 2 ;;
        -e|--env) env_flag_error ;;
        *)        DEPLOY_ARG=dev ;;
      esac

      resolve_compose_file "$DEPLOY_ARG" && \
      docker compose --file "$COMPOSE_TARGET" logs --follow "$@"

    else terminate "There is no project."; fi

  elif [ "$1" == "stop" ] || [ "$1" == "down" ] || [ "$1" == "ps" ] || [ "$1" == "restart" ]; then
    COMPOSE_COMMAND=$1; shift
    if [ "$EXISTING_PROJECT" == true ]; then
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
      [ "$COMPOSE_COMMAND" == "down" ] && ORPHANS="--remove-orphans" || ORPHANS=""

      resolve_compose_file "$DEPLOY_ARG" && \
      docker compose --file "$COMPOSE_TARGET" "$COMPOSE_COMMAND" ${ORPHANS:+"$ORPHANS"} "$@"

    else terminate "There is no project."; fi

  elif [ "$1" == "iex" ] || [ "$1" == "bash" ]; then
    SESSION_KIND=$1; shift
    if [ "$EXISTING_PROJECT" == true ]; then
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

      # The release remote shell stops the node it is attached to when its
      # input reaches EOF, so a redirected or piped stdin would take the
      # application down instead of just detaching. Only dev is safe: its
      # 'iex -S mix' runs its own VM inside the container.
      if [ "$SESSION_KIND" == "iex" ] && [ "$DEPLOY_ARG" != "dev" ] && [ ! -t 0 ]
      then terminate \
        "'iex --deploy $DEPLOY_ARG' opens the release remote shell, which stops" \
        "the node when its input reaches EOF: it needs an interactive" \
        "terminal. To evaluate one expression without attaching, use:" \
        "  docker compose --file $COMPOSE_TARGET \\" \
        "    exec -T $SERVICE /app/bin/$ELIXIR_PROJECT_NAME rpc 'EXPRESSION'"
      fi

      # Only the dev image carries Mix and the mounted source; prod and
      # scaled run the release, whose shell is 'bin/<app> remote'.
      if [ "$DEPLOY_ARG" == "dev" ]
      then
        if [ "$SESSION_KIND" == "iex" ]
        then SESSION_COMMAND=(iex -S mix)
        else SESSION_COMMAND=(bash); fi
        WORKDIR_FLAGS=( --workdir /app/src )
      else
        if [ "$SESSION_KIND" == "iex" ]
        then SESSION_COMMAND=("/app/bin/$ELIXIR_PROJECT_NAME" remote)
        else SESSION_COMMAND=(bash); fi
        WORKDIR_FLAGS=()
      fi

      docker compose --file "$COMPOSE_TARGET" \
        exec "${WORKDIR_FLAGS[@]}" "$SERVICE" "${SESSION_COMMAND[@]}"

    else terminate "There is no project."; fi

  elif [ "$1" == "mix" ]; then
    shift
    if [ "$EXISTING_PROJECT" == true ]; then
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

  elif [ "$1" == "delete" ]; then
    if [ "$EXISTING_PROJECT" == true ]; then
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

  elif [ "$1" == "prune" ]; then
    shift
    prune_workbench "$@"

  elif [ "$1" == "demo" ]; then
    WORKBENCH_SCRIPT="$WORKBENCH_PATH/$(basename "$0")"; shift;

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

  elif [ "$1" == "help" ]; then
    help
  else args_error invalid; fi
else help; fi
