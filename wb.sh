#!/bin/bash
# Dockerized workbench script (Igniter edition)
# v0.8.0
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
  cd "$WORKBENCH_PATH"

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
  source "./$SCRIPT_CONFIG_FILE"

  # Workbench configuration --------------------------------------------------

    WORKBENCH_VERSION=$( sed '3!d' $0 | sed -n 's/^.*v\(.*\).*/\1/p' )
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
    CONTAINER_ENTRYPOINT="bash workbench/scripts/entrypoint.sh"
    # TTY flags only when running from an interactive terminal (CI-safe).
    if [ -t 0 ]
    then DOCKER_TTY_FLAGS="--tty --interactive"
    else DOCKER_TTY_FLAGS=""
    fi

    # Elixir project files - - - - - - - - - - - - - - - - - - - - - - - - - -
    LOWER_CASE=$( echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' )
    ELIXIR_PROJECT_NAME=$( echo $LOWER_CASE | tr ' ' '_' )
    MIX_FILE="mix.exs"
    EXISTING_PROJECT=$(
      [ -f "$WORKSPACE_PATH/$MIX_FILE" ] && echo true || echo false
    )

    # Git - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    if [ -d "$WORKSPACE_PATH/.git" ]
    then REPO_URL=$(
      git -C "$WORKSPACE_PATH" config --get remote.origin.url | \
      sed 's/\.git$//'
    )
    else REPO_URL="https://github.com/user/repo"
    fi

  # Docker ---------------------------------------------------------------------

    APP_NAME=$( echo "$LOWER_CASE" | tr ' ' '-' )
    # Bare toolchain image, shared by every workspace of the same stack —
    # the Phoenix installer included: it is the generator the base
    # cartridges take their delta with, so another installer is another
    # image, and a workspace keeps the one that made its project.
    TOOLCHAIN_IMAGE="workbench:${ELIXIR_VERSION}-${ERLANG_VERSION}-phx${PHX_NEW_VERSION}"
    # The workspace's own dev image name. Standalone it is built from the
    # project's Dockerfile.local; with the workbench present, `new` seeds
    # it as an alias (docker tag) of the shared toolchain image.
    LOCAL_IMAGE="$APP_NAME:local"
    # An existing workspace names itself: its compose carries the compose
    # project name and the dev image baked at creation, so every command
    # but the creating ones reads them from there — config.conf may since
    # have moved on to name the next project, and several workspaces can
    # be driven from one workbench.
    if [ $EXISTING_PROJECT == true ] && [ -f "$WORKSPACE_PATH/$COMPOSE_FILE" ] && \
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
    fi
    # Ports the services bind INSIDE the containers; the host ports are
    # chosen per workspace and mapped to these in its compose file.
    APP_INTERNAL_PORT="4000"
    PGADMIN_INTERNAL_PORT="5050"
    SOURCE_CODE_VOLUME="$WORKSPACE_PATH:/app/src"
    WORKBENCH_VOLUME="$WORKBENCH_PATH:/app/workbench:ro"

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
    echo "⚠️  ${B}Warning${R} $@"
    if [ "$WB_YES" == true ]; then echo "Continuing (--yes)."; echo; return; fi
    read -n 1 -p $'Should continue? [y/N] ' INPUT
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
    # spelling: 'setup' and 'demo' keep --env, where it really is MIX_ENV.
  env_flag_error() {
    terminate \
      "Deployments are selected with ${B}--deploy${R}, not --env:" \
      "  ./$(basename $0) $COMMAND_NAME --deploy dev|prod|scaled" \
      "(--env stays on 'setup' and 'demo', where it means MIX_ENV.)"
  }

  # warning <MESSAGE>
    # Prints a warning without interrupting: the command carries on.
  warning() { echo "⚠️  ${B}Warning${R} $@"; echo; }

  # terminate <MESSAGE>
    # Print error and terminate with sigerr 1
  terminate() { echo "${B}${C1}Error${R} $@"; echo; exit 1; }

  # first_free_port <BASE>
    # Prints the first host port available starting from BASE.
  first_free_port() {
    local port=$1
    while (exec 3<>"/dev/tcp/127.0.0.1/$port") 2>/dev/null; do
      exec 3>&- 3<&-
      port=$((port + 1))
    done
    echo $port
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
      "does not exist). Create it with: ./$(basename $0) up --deploy $1"
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

    cp $seed_path $file_path

    sed -i "s/%{elixir_version}/$ELIXIR_VERSION/" $file_path
    sed -i "s/%{erlang_version}/$ERLANG_VERSION/" $file_path
    sed -i "s/%{debian_version}/$DEBIAN_VERSION/" $file_path
    sed -i "s/%{phx_new_version}/$PHX_NEW_VERSION/" $file_path
  }

  # prepare_workspace
    # Ensures an empty workspace directory (confirming first when a project
    # already exists there) and bakes the local dockerfile from seed.
  prepare_workspace() {
    if [ $EXISTING_PROJECT == true ]; then
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

    sed -i "s/%{app_name}/$ELIXIR_PROJECT_NAME/"                 $file_path
    sed -i "s/%{compose_image}/$image/"                          $file_path
    sed -i "s/%{compose_dockerfile}/$dockerfile/"                $file_path
    sed -i "s/%{uid}/$(id -u)/"                                  $file_path
    sed -i "s/%{gid}/$(id -g)/"                                  $file_path
    sed -i "s/%{app_port}/$APP_PORT/"                            $file_path
    sed -i "s/%{internal_port}/$APP_INTERNAL_PORT/g"             $file_path
    sed -i "s/%{pgadmin_port}/$PGADMIN_PORT/"                    $file_path
    sed -i "s/%{pgadmin_internal_port}/$PGADMIN_INTERNAL_PORT/g" $file_path
    sed -i "s/%{postgres_image_version}/$POSTGRES_IMAGE_VERSION/" $file_path
    sed -i "s/%{pgadmin_image_version}/$PGADMIN_IMAGE_VERSION/"  $file_path

    # Remove the database & pgadmin services on projects without a
    # database server (the network holder and the pod structure remain).
    if ! workspace_needs_database
    then
      sed -i '/^  database:/,$d'            $file_path
      sed -i '/^    depends_on:/,+2d'       $file_path
      sed -i "/# pgAdmin port/,/:$PGADMIN_INTERNAL_PORT\$/d" $file_path
    fi
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

  # workspace_igniter <TASK> [ARGS...]
    # Runs a workbench.* mix task of the igniter package on the workspace,
    # on a bare toolchain container: the source and the workbench mounted,
    # no compose. The running app container has no workbench mounted (the
    # package is not a dependency of the project once it leaves the
    # workbench), and a compose one-off would bring the database up for
    # a task that only reads the source. The package is compiled first,
    # in the same Mix boot as the task (a boot costs seconds), so the
    # task sees its current source; what mix prints on its way to the
    # task (the package, a dependency, the project) lands before the
    # answer — the --json readers keep from the first JSON line on
    # (json_answer).
  # json_answer
    # Keeps a mix task's output from its first JSON line on: mix prints
    # what it compiles on the way to the task (a new dependency, the
    # project, the package itself) on stdout, before the task answers.
  json_answer() { sed -n '/^[[{]/,$p'; }

  workspace_igniter() {
    docker run \
      $DOCKER_TTY_FLAGS \
      --rm \
      --name "${APP_NAME}_workbench_$1" \
      --volume $SOURCE_CODE_VOLUME \
      --volume $WORKBENCH_VOLUME \
      --workdir /app/src \
      $LOCAL_IMAGE sh -c \
        'exec mix do deps.compile workbench_igniter, "$@"' \
        mix "$@"
  }

  # workspace_git [ARGS...]
    # Runs git on the workspace from the toolchain container — where the
    # project's git hooks can run mix, and as the workspace's own user —
    # signing as GIT_NAME <GIT_EMAIL>.
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
    docker run \
      --rm \
      --env GIT_AUTHOR_NAME="$GIT_NAME" \
      --env GIT_AUTHOR_EMAIL="$GIT_EMAIL" \
      --env GIT_COMMITTER_NAME="$GIT_NAME" \
      --env GIT_COMMITTER_EMAIL="$GIT_EMAIL" \
      --volume $SOURCE_CODE_VOLUME \
      --workdir /app/src \
      $LOCAL_IMAGE git "$@"
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

  # require_clean_workspace <ACTION>
    # Every cartridge is one commit, so 'eject' can revert it alone: the
    # commands that write cartridges refuse a tree with changes git does
    # not have, instead of folding them into the cartridge's commit.
  require_clean_workspace() {
    if [ ! -d "$WORKSPACE_PATH/.git" ] || workspace_dirty; then
      terminate \
        "The workspace has changes git does not have, and '$1' needs a" \
        "clean tree: each cartridge is one commit, so 'eject' can revert" \
        "it alone. Commit them first: ./$(basename $0) commit \"MESSAGE\""
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
    # TEXT as a JSON string literal.
  json_string() {
    printf '"%s"' "$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g')"
  }

  # json_array
    # One JSON array from stdin: objects one per line (compose's ps
    # --format json), or an array already, or nothing.
  json_array() {
    local input
    input=$(cat)
    case "$input" in
      \[*) echo "$input" ;;
      "")  echo "[]" ;;
      *)   echo "[$(echo "$input" | paste -sd, -)]" ;;
    esac
  }

  # status_json
    # The workspace as one JSON object: where it is, its ports, which
    # deployments were baked, the containers of its compose project, and
    # — 'project' — what 'mix workbench.status --json' says of the
    # cartridges it carries (null when that could not be asked).
  status_json() {
    local port pgadmin project
    port=$(workspace_app_port)
    pgadmin=$(workspace_pgadmin_port)
    project=$(workspace_igniter workbench.status --json 2>/dev/null | json_answer)

    echo "{"
    echo "  \"workspace\": $(json_string "$WORKSPACE_PATH"),"
    echo "  \"compose_project\": $(json_string "$(compose_project_name)"),"
    echo "  \"ports\": {\"app\": ${port:-null}, \"pgadmin\": ${pgadmin:-null}},"
    echo "  \"baked\": {"
    echo "    \"dev\": true,"
    echo "    \"prod\": $([ -f "$WORKSPACE_PATH/$PROD_COMPOSE_FILE" ] && echo true || echo false),"
    echo "    \"scaled\": $([ -f "$WORKSPACE_PATH/$SCALED_COMPOSE_FILE" ] && echo true || echo false)"
    echo "  },"
    echo "  \"containers\": $(workspace_containers | json_array),"
    echo "  \"git\": $(git_json),"
    echo "  \"project\": ${project:-null}"
    echo "}"
  }

  # git_json
    # The workspace's git as JSON: whether it is a repository, whether
    # the tree is clean, HEAD, who signs, and the cartridges inserted by
    # commit — newest first — which 'eject' reverts.
  git_json() {
    local inserts
    if [ ! -d "$WORKSPACE_PATH/.git" ]; then echo '{"repo": false}'; return; fi
    inserts=$(
      active_inserts | \
      while IFS=$'\x1f' read -r sha subject date; do
        printf '{"sha": "%s", "feature": "%s", "subject": %s, "date": "%s"},' \
          "$sha" "$(echo "$subject" | awk '{print $2}')" "$(json_string "$subject")" "$date"
      done
    )
    echo "{\"repo\": true, \"clean\": $(workspace_dirty && echo false || echo true)," \
      "\"head\": $(json_string "$(git_read log --format='%h %s' -n 1 2>/dev/null)")," \
      "\"identity\": $(json_string "$GIT_NAME <$GIT_EMAIL>")," \
      "\"inserts\": [${inserts%,}]}"
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
    echo "${B}Deployments${R}  (baked compose files; up with: ./$(basename $0) up --deploy TARGET)"
    for target in dev prod scaled; do
      if [ -f "$WORKSPACE_PATH/$(compose_file_for $target)" ]
      then echo "  $(printf '%-7s' $target) baked"
      else echo "  $(printf '%-7s' $target) -"; fi
    done
    echo
    echo "${B}Containers${R}  (dev and prod share their names: the image tells them apart)"
    if [ -n "$containers" ]
    then echo "$containers" | sed 's/^/  /'
    else echo "  none"; fi
    echo
    echo "${B}Git${R}  (commits the workbench makes, signed as $GIT_NAME <$GIT_EMAIL>)"
    if [ -d "$WORKSPACE_PATH/.git" ]; then
      if workspace_dirty; then echo "  tree: changes git does not have (./$(basename $0) commit)"
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
    # and — the production image being self-contained — no source code
    # volume nor build identity (its Dockerfile runs as nobody).
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
    sed -i '/^    volumes:/,+1d' "$WORKSPACE_PATH/$PROD_COMPOSE_FILE" && \
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

    while [ $i -le $REPLICAS ]; do
      port=$(first_free_port $port)
      REPLICA_PORTS+=( $port )

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
    sed -i -e "/%{app_services}/r $services"     -e "/%{app_services}/d"     $file_path
    sed -i -e "/%{balancer_depends}/r $depends"  -e "/%{balancer_depends}/d" $file_path
    sed -i -e "/%{upstream_servers}/r $upstream" -e "/%{upstream_servers}/d" $file_path
    rm -f "$services" "$depends" "$upstream"

    sed -i "s/%{app_name}/$ELIXIR_PROJECT_NAME/g"                  $file_path
    sed -i "s/%{compose_image}/$APP_NAME:$APP_VERSION-prod/g"      $file_path
    sed -i "s/%{compose_dockerfile}/$PROD_DOCKERFILE/g"            $file_path
    sed -i "s/%{balancer_port}/$BALANCER_PORT/"                    $file_path
    sed -i "s/%{nginx_image_version}/$NGINX_IMAGE_VERSION/"        $file_path
    sed -i "s/%{postgres_image_version}/$POSTGRES_IMAGE_VERSION/"  $file_path

    # Without the clustering feature the release is not distributed, so
    # DNSCluster would poll DNS forever, connect to nobody and warn about
    # it on every boot. Leaving the variable unset keeps it out of the
    # supervision tree (runtime.exs falls back to :ignore).
    clustering_installed || sed -i '/^    DNS_CLUSTER_QUERY:/d' $file_path

    # Without a balancer the replicas are only reachable on their own
    # ports; its nginx config goes with it.
    if [ "$BALANCER" == false ]; then
      sed -i '/^  # Single entry point/,/^$/d' $file_path
      sed -i '/^configs:/,$d'                  $file_path
    fi

    # Projects without a database server have nothing to migrate and no
    # database: drop both services and the app anchor's references to them.
    if ! workspace_needs_database
    then
      sed -i '/^  # One-shot migration/,/^configs:/{/^configs:/!d}' $file_path
      sed -i '/^  depends_on:$/,+2d'                                $file_path
      sed -i '/^    DATABASE_URL:/d'                                $file_path
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
      "here and run: ./$(basename $0) add clustering"
  }

  # deployed_message
    # Printed after a successful 'up' of the dev or prod compose.
  deployed_message() {
    echo
    echo "Application deploying at ${Li}http://localhost:$(workspace_app_port)${R}" \
      "(first boot compiles: give it a moment)."
    echo "Follow the logs with ${B}./$(basename $0) logs${R}," \
      "stop everything with ${B}./$(basename $0) stop${R}."
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
    echo "Stop everything with ${B}./$(basename $0) down --deploy scaled${R}."
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

    local script_name=$(basename "$0")

    section "NAME"
    section_content "$(sed -n '2s/# //p' $0)"

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
      "  (${Li}https://hexdocs.pm/phoenix/Mix.Tasks.Phx.New.html${R})."

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
      "files changed since — that is no longer the cartridge's alone."

    print_command "console [up|down|logs|build]"
    section_content \
      "The workbench's console: a Phoenix LiveView page that shows the" \
      "workspace and drives this script — as a container, with Docker's" \
      "socket and the workbench mounted, on the first free port from 4100." \
      "- up (default): build the image if missing and start it." \
      "- down, logs: stop it, follow its output." \
      "- build: build the image again (the Docker CLI in it follows the host)."

    print_command "bake"
    section_content \
      "Bake the workspace's compose again from the seed, for the project" \
      "as it is now — with the database and pgAdmin when it runs on a" \
      "database server, without them when it does not (or on SQLite) —" \
      "keeping its ports, as one commit. What 'add ecto' asks for next." \
      "Needs a clean tree. The prod and scaled composes are baked at" \
      "their own deployment."

    print_command "commit [MESSAGE]"
    section_content \
      "Commit everything the workspace has, from the toolchain container" \
      "(the project's git hooks can run mix there), signed as the" \
      "GIT_IDENTITY of config.conf: 'user' takes the host's git identity" \
      "when there is one, 'workbench' signs as the workbench." \
      "- MESSAGE: Default: 'Workbench: commit pending changes'."

    print_command "catalog [--json]"
    section_content \
      "List every cartridge the workbench has: name, version, how it is" \
      "enabled and what it installs — with the options of its installer" \
      "and which of its box covers exist, in the JSON form. Read by the" \
      "igniter package ('mix workbench.catalog'), so it needs a project" \
      "to run on." \
      "- --json: One JSON array, for tools."

    print_command "status [--json]"
    section_content \
      "Where the workspace stands: its ports, which deployments were" \
      "baked, its containers, and which cartridges the project carries" \
      "('mix workbench.status': each cartridge answers off the same mark" \
      "its installer checks, so this and 'add' never disagree)." \
      "- --json: One JSON object, for tools."

    print_command "setup [-e, --env ENV]"
    section_content \
      "Set or reset the database (if any) and run the seeding script." \
      "- ENV: Enviroment database to setup (Defalut: dev)."

    print_command "up [--deploy TARGET] [--replicas N] [--no-balancer]"
    section_content \
      "Deploy the application on localhost, detached: the terminal stays" \
      "free and the containers keep running ('logs' follows their output)." \
      "- TARGET: Deployment to bring up (Defalut: dev). 'setup' and 'demo'" \
      "  keep --env: there it means MIX_ENV, not a compose file." \
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
      "  app1..appN, balancer and migrate with '--deploy scaled')."

    print_command "stop | down | ps [--deploy TARGET]"
    section_content \
      "Stop, remove or list the workspace containers ('stop' keeps them" \
      "for a fast restart with 'up'; 'down' removes them)." \
      "- TARGET: Deployment to act on (Defalut: dev)."

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
      "up (fast), or on a one-off container otherwise." \
      "- ARGS: The task and its options, e.g.: cover, docs, test."

    print_command "delete"
    section_content \
      "Deletes the workspace project files and its Docker compose project."

    print_command "demo [-e, --env ENV]"
    section_content \
      "Runs consecutively new, setup, up, logs & delete commands: the" \
      "logs block the demo while the application is tried out, and" \
      "Ctrl+C moves on to the teardown." \
      "- ENV: Enviroment to run end to end, database included (Defalut:" \
      "  dev). It is --env and not --deploy because it reaches 'setup'" \
      "  too, where the value is MIX_ENV."

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

  # create_project <SETUP_COMMAND> [PHOENIX_NEW_OPTIONS...]
    # Body of the 'new' command: prepares the workspace, builds the
    # toolchain image, generates the Phoenix project, registers the
    # igniter package and runs SETUP_COMMAND (the 'workbench_setup'
    # entrypoint branch) with the SETUP_FLAGS its builder left. Finally
    # bakes the workspace's own dockerfile and compose file.
  create_project() {
    local setup_command="$1"; shift

    prepare_workspace && \
    cd "$SCRIPTS_DIR" && \
    docker build \
      --build-arg UID="$(id -u)" \
      --build-arg GID="$(id -g)" \
      --file $LOCAL_DOCKERFILE --tag $TOOLCHAIN_IMAGE . && \
    docker tag $TOOLCHAIN_IMAGE $LOCAL_IMAGE && \
    cd "$WORKBENCH_PATH" && \
    docker run \
      $DOCKER_TTY_FLAGS \
      --name "${APP_NAME}_workbench_new" \
      --rm \
      --volume $SOURCE_CODE_VOLUME \
      --volume $WORKBENCH_VOLUME \
      $TOOLCHAIN_IMAGE $CONTAINER_ENTRYPOINT new \
      $ELIXIR_PROJECT_NAME "$@" && \
    register_igniter_package && \
    docker run \
      $DOCKER_TTY_FLAGS \
      --name "${APP_NAME}_workbench_${setup_command}" \
      --rm \
      --volume $SOURCE_CODE_VOLUME \
      --volume $WORKBENCH_VOLUME \
      $TOOLCHAIN_IMAGE $CONTAINER_ENTRYPOINT $setup_command "${SETUP_FLAGS[@]}" && \
    # The project keeps its own baked copy of the toolchain dockerfile,
    # so a standalone clone (no workbench) can rebuild the same dev
    # image: the compose build points at it.
    cp "$SCRIPTS_DIR/$LOCAL_DOCKERFILE" "$WORKSPACE_PATH/$LOCAL_DOCKERFILE" && \
    # The workspace owns its orchestration: compose with real values.
    # Its build points to the project-owned Dockerfile.local — and must
    # stay there: its app service also runs the workbench one-off
    # commands (setup, add, mix), which need the toolchain. The
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

      echo $GITHUB_TOKEN | docker login $REGISTRY_SERVER \
        --username $GITHUB_USER \
        --password-stdin
    fi

  elif [ "$1" == "new" ]; then
    shift

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
    ENTRYPOINT_COMMAND=$1; shift

    if [ $EXISTING_PROJECT == true ]; then
      if [ $# -gt 0 ]; then
        require_clean_workspace add

        # The cartridge expands to the inserts to run: itself for a
        # plain one, its missing members for a collection
        # (chiefs_setup). Only the 'plan> ' lines are the plan; the
        # rest is mix noise. Each insert then runs as its own container
        # and its own commit, so 'eject' reverts one cartridge alone —
        # a collection leaves no commit of its own.
        RAW_PLAN=$(
          workspace_compose run \
            --rm -T \
            --name "${APP_NAME}_workbench_expand" \
            --volume $WORKBENCH_VOLUME \
            app $CONTAINER_ENTRYPOINT expand $@
        ) || terminate "Could not expand '$1'."
        PLAN=$(echo "$RAW_PLAN" | tr -d '\r' | sed -n 's/^plan> //p')

        if [ -z "$PLAN" ]; then
          echo "Nothing to insert: the project already carries every cartridge of '$1'."
        else
          while IFS= read -r INSERT; do
            workspace_compose run \
              --rm \
              --name "${APP_NAME}_workbench_${ENTRYPOINT_COMMAND}" \
              --volume $WORKBENCH_VOLUME \
              app $CONTAINER_ENTRYPOINT add $INSERT && \
            workspace_commit "Insert $INSERT" || exit 1
          done <<< "$PLAN"

          if workspace_needs_database && \
             ! grep -q "^  database:" "$WORKSPACE_PATH/$COMPOSE_FILE"; then
            echo "The project now runs on a database and the compose has none:" \
              "./$(basename $0) bake bakes it in, then ./$(basename $0) setup creates it."
          fi
        fi

      else args_error "Missing feature name. Try: ./$(basename $0) add healthcheck"; fi
    else terminate "There is no project to add features to."; fi

  elif [ "$1" == "eject" ]; then
    shift
    if [ $EXISTING_PROJECT == true ]; then
      [ $# -gt 0 ] || args_error "Missing feature name. Try: ./$(basename $0) eject credo"
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

      echo "Reverting $(workspace_git log --format='%h %s' -n 1 $SHA)"
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

  elif [ "$1" == "console" ]; then
    shift
    # The console: a Phoenix LiveView app in console/, run as a container
    # that drives this very workbench — Docker's socket mounted, and the
    # workbench mounted at the same absolute path as on the host, so the
    # relative paths in config.conf and the composes' bind mounts mean
    # the same thing to the daemon whichever side asks. It runs as this
    # user, in the socket's group, and shells out to wb.sh as jobs.
    CONSOLE_IMAGE="workbench-console:${ELIXIR_VERSION}-${ERLANG_VERSION}"
    CONSOLE_NAME="workbench_console"
    CONSOLE_DIR="$WORKBENCH_PATH/console"

    console_build() {
      docker build \
        --build-arg "TOOLCHAIN=$TOOLCHAIN_IMAGE" \
        --build-arg "DOCKER_VERSION=$(docker version --format '{{.Server.Version}}')" \
        --build-arg "COMPOSE_VERSION=$(docker compose version --short | sed 's/-.*//')" \
        --tag "$CONSOLE_IMAGE" "$CONSOLE_DIR"
    }

    case "$1" in
      ""|up)
        # A toolchain built before the installer was part of the tag
        # (workbench:ELIXIR-OTP) still serves the console.
        docker image inspect "$TOOLCHAIN_IMAGE" > /dev/null 2>&1 || \
          { LEGACY_TOOLCHAIN="workbench:${ELIXIR_VERSION}-${ERLANG_VERSION}" && \
            docker image inspect "$LEGACY_TOOLCHAIN" > /dev/null 2>&1 && \
            TOOLCHAIN_IMAGE="$LEGACY_TOOLCHAIN"; } || \
          terminate "No toolchain image $TOOLCHAIN_IMAGE yet: create a project first (new builds it)."
        docker image inspect "$CONSOLE_IMAGE" > /dev/null 2>&1 || console_build || terminate "The console image did not build."
        docker rm -f "$CONSOLE_NAME" > /dev/null 2>&1
        CONSOLE_PORT=$(first_free_port 4100)
        # The socket's group as the container sees it — not the host's:
        # under Docker Desktop the mounted socket is the VM's, root-owned.
        SOCKET_GID=$(docker run --rm --volume /var/run/docker.sock:/var/run/docker.sock \
          "$CONSOLE_IMAGE" stat -c %g /var/run/docker.sock)
        docker run --detach \
          --name "$CONSOLE_NAME" \
          --user "$(id -u):$(id -g)" \
          --group-add "$SOCKET_GID" \
          --volume /var/run/docker.sock:/var/run/docker.sock \
          --volume "$WORKBENCH_PATH:$WORKBENCH_PATH" \
          --workdir "$CONSOLE_DIR" \
          --env HOME=/home/elixir \
          --env "WORKBENCH_DIR=$WORKBENCH_PATH" \
          --env PORT=4000 \
          --publish "$CONSOLE_PORT:4000" \
          "$CONSOLE_IMAGE" > /dev/null && \
        echo "The console is coming up on ${B}http://localhost:$CONSOLE_PORT${R}" \
          "(first run compiles it: ./$(basename $0) console logs)." ;;
      down)  docker rm -f "$CONSOLE_NAME" > /dev/null 2>&1 && echo "Console down." || echo "The console was not up." ;;
      logs)  docker logs --follow "$CONSOLE_NAME" ;;
      build) console_build ;;
      *)     args_error invalid ;;
    esac

  elif [ "$1" == "bake" ]; then
    if [ $EXISTING_PROJECT == true ]; then
      require_clean_workspace bake
      # The workspace keeps its ports; the compose is where they live.
      APP_PORT=$(workspace_app_port)
      PGADMIN_PORT=$(workspace_pgadmin_port)
      [ -n "$APP_PORT" ]     || APP_PORT=$(first_free_port 4000)
      [ -n "$PGADMIN_PORT" ] || PGADMIN_PORT=$(first_free_port 5050)

      bake_compose "$LOCAL_IMAGE" "$LOCAL_DOCKERFILE" "$COMPOSE_FILE" && \
      if workspace_dirty; then
        workspace_commit "Bake $COMPOSE_FILE" && \
        if workspace_needs_database; then
          echo "The compose now has the database: ./$(basename $0) setup creates it."
        fi
      else
        echo "$COMPOSE_FILE is already what the project asks for: nothing to bake."
      fi
    else terminate "There is no project."; fi

  elif [ "$1" == "commit" ]; then
    shift
    if [ $EXISTING_PROJECT == true ]; then
      workspace_commit "${*:-Workbench: commit pending changes}"
    else terminate "There is no project to commit."; fi

  elif [ "$1" == "catalog" ]; then
    shift
    if [ $EXISTING_PROJECT == true ]; then
      case "$1" in
        --json) workspace_igniter workbench.catalog --json \
                  --covers /app/workbench/assets/covers 2>/dev/null | json_answer ;;
        "")     workspace_igniter workbench.catalog ;;
        *)      args_error invalid ;;
      esac

    else terminate \
      "There is no project: the catalog is read by the igniter package" \
      "on the workspace. Create one with: ./$(basename $0) new"; fi

  elif [ "$1" == "status" ]; then
    shift
    if [ $EXISTING_PROJECT == true ]; then
      case "$1" in
        --json) status_json ;;
        "")     status_report ;;
        *)      args_error invalid ;;
      esac

    else terminate "There is no project in $WORKSPACE_PATH."; fi

  elif [ "$1" == "setup" ]; then
    ENTRYPOINT_COMMAND=$1; shift

    if [ $EXISTING_PROJECT == true ]; then
      # --env, not --deploy: this one really is MIX_ENV. It sets up a
      # database, it does not pick a compose file.
      [ $# -gt 1 ] && [ "$1" == "--env" ] || [ "$1" == "-e" ] && \
        ENV_ARG="$2" || \
        ENV_ARG=dev

      workspace_compose run \
        --rm \
        --name "${APP_NAME}_workbench_${ENTRYPOINT_COMMAND}" \
        --volume $WORKBENCH_VOLUME \
        app $CONTAINER_ENTRYPOINT $ENTRYPOINT_COMMAND $ENV_ARG

    else terminate "There is no project to setup."; fi

  elif [ "$1" == "up" ]; then
    COMPOSE_COMMAND=$1; shift
    if [ $EXISTING_PROJECT == true ]; then
      parse_deploy_args "$@"

      # Every deployment of a workspace shares one compose project, but
      # not the same services: dev has 'app', the scaled one has app1..N
      # plus balancer and migrate, and --replicas/--no-balancer change
      # that set between runs. Without --remove-orphans the containers of
      # the previous shape stay up, unmanaged and invisible to 'ps'.
      if [ "$DEPLOY_ARG" == "scaled" ]; then
        bake_scaled_compose && \
        docker compose \
          --file "$WORKSPACE_PATH/$SCALED_COMPOSE_FILE" \
          $COMPOSE_COMMAND --detach --build --remove-orphans && \
        scaled_deployed_message

      elif [ "$DEPLOY_ARG" == "prod" ]; then
        bake_prod_compose && \
        docker compose \
          --file "$WORKSPACE_PATH/$PROD_COMPOSE_FILE" \
          $COMPOSE_COMMAND --detach --build --remove-orphans && \
        deployed_message

      else
        workspace_compose $COMPOSE_COMMAND --detach --remove-orphans && \
        deployed_message
      fi

    else terminate "There is no project to deploy."; fi

  elif [ "$1" == "build" ]; then
    shift
    if [ $EXISTING_PROJECT == true ]; then
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
    if [ $EXISTING_PROJECT == true ]; then
      case "$1" in
        --deploy) DEPLOY_ARG="$2"; shift 2 ;;
        -e|--env) env_flag_error ;;
        *)        DEPLOY_ARG=dev ;;
      esac

      resolve_compose_file $DEPLOY_ARG && \
      docker compose --file "$COMPOSE_TARGET" logs --follow $@

    else terminate "There is no project."; fi

  elif [ "$1" == "stop" ] || [ "$1" == "down" ] || [ "$1" == "ps" ]; then
    COMPOSE_COMMAND=$1; shift
    if [ $EXISTING_PROJECT == true ]; then
      case "$1" in
        --deploy) DEPLOY_ARG="$2"; shift 2 ;;
        -e|--env) env_flag_error ;;
        *)        DEPLOY_ARG=dev ;;
      esac

      # 'down' clears the project, orphans of other deployments included;
      # 'stop' and 'ps' do not accept the flag.
      [ "$COMPOSE_COMMAND" == "down" ] && ORPHANS="--remove-orphans" || ORPHANS=""

      resolve_compose_file $DEPLOY_ARG && \
      docker compose --file "$COMPOSE_TARGET" $COMPOSE_COMMAND $ORPHANS

    else terminate "There is no project."; fi

  elif [ "$1" == "iex" ] || [ "$1" == "bash" ]; then
    SESSION_KIND=$1; shift
    if [ $EXISTING_PROJECT == true ]; then
      case "$1" in
        --deploy) DEPLOY_ARG="$2"; shift 2 ;;
        -e|--env) env_flag_error ;;
        *)        DEPLOY_ARG=dev ;;
      esac

      # The service to attach to: 'app' everywhere but in the scaled
      # deployment, where the replicas are app1..appN.
      SERVICE="${1:-app}"
      resolve_compose_file $DEPLOY_ARG

      app_is_running "$COMPOSE_TARGET" "$SERVICE" || terminate \
        "The $SERVICE container of the $DEPLOY_ARG deployment is not running." \
        "Start it with: ./$(basename $0) up --deploy $DEPLOY_ARG"

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
        then SESSION_COMMAND="iex -S mix"
        else SESSION_COMMAND="bash"; fi
        WORKDIR_FLAGS=( --workdir /app/src )
      else
        if [ "$SESSION_KIND" == "iex" ]
        then SESSION_COMMAND="/app/bin/$ELIXIR_PROJECT_NAME remote"
        else SESSION_COMMAND="bash"; fi
        WORKDIR_FLAGS=()
      fi

      docker compose --file "$COMPOSE_TARGET" \
        exec "${WORKDIR_FLAGS[@]}" $SERVICE $SESSION_COMMAND

    else terminate "There is no project."; fi

  elif [ "$1" == "mix" ]; then
    shift
    if [ $EXISTING_PROJECT == true ]; then
      # Warm path: exec on the running app container (fast, no startup).
      # Cold path: one-off container (starts the database dependency too).
      if app_is_running; then
        workspace_compose exec --workdir /app/src app mix $@
      else
        workspace_compose run \
          --rm \
          --name "${APP_NAME}_workbench_mix" \
          --workdir /app/src \
          app mix $@
      fi

    else terminate "There is no project."; fi

  elif [ "$1" == "delete" ]; then
    if [ $EXISTING_PROJECT == true ]; then
      confirm \
        "This action will delete all project files from $WORKSPACE_PATH" \
        "along with its containers, images and database volumes." && \
      if [ -f "$WORKSPACE_PATH/$COMPOSE_FILE" ]; then
        workspace_compose down \
          --volumes \
          --rmi local \
          --remove-orphans
      fi && \
      wipe_workspace && \
      docker rmi $LOCAL_IMAGE 2>/dev/null; \
      rm -f "$SCRIPTS_DIR/$LOCAL_DOCKERFILE"

    else terminate "There is no project to delete."; fi

  elif [ "$1" == "demo" ]; then
    WORKBENCH_SCRIPT="$WORKBENCH_PATH/$(basename $0)"; shift;

    # The demo runs one environment end to end, database included, so it
    # takes --env like 'setup' does and hands it to both.
    [ $# -gt 1 ] && [ "$1" == "--env" ] || [ "$1" == "-e" ] && \
      ENV_ARG="$2" || \
      ENV_ARG=dev

    "$WORKBENCH_SCRIPT" new && \
    "$WORKBENCH_SCRIPT" setup --env $ENV_ARG && \
    "$WORKBENCH_SCRIPT" up --deploy $ENV_ARG && \
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
