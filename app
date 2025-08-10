#!/bin/bash
# Dockerized workbench script
# v0.4.1

# CONFIGURATION ================================================================

  SCRIPT_CONFIG_FILE="config.conf"
  source ./$SCRIPT_CONFIG_FILE

  # Workbench configuration --------------------------------------------------

    if [ "$STRIPE" == true ]; then AUTH0="true"; fi
    if [ "$OPENAI" == true ]; then AUTH0="true"; fi
    if [ "$CODING_GUIDELINES_URL" != "" ]
    then CODING_GUIDELINES="true"
    else CODING_GUIDELINES="false"
    fi

    # Directory name to allocate the script files upon creation.
    WORKBENCH_DIR="_workbench"
    WORKBENCH_README_FILE="README.md"
    WORKBENCH_VERSION=$( sed '3!d' $0 | sed -n 's/^.*v\(.*\).*/\1/p' )
    EXISTING_PROJECT=$(
      [ $(basename $PWD) == $WORKBENCH_DIR ] && echo true || echo false
    )
    SOURCE_CODE_PATH=$(
      [ $EXISTING_PROJECT == true ] && echo $(dirname $PWD) || echo $PWD
    )

    # Directories - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    SCRIPTS_DIR="scripts"
    CONTEXTS_DIR="contexts"
    PGADMIN_DIR="pgadmin"
    SEEDS_DIR="seeds"

    # Script files - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    ENTRYPOINT_FILE="entrypoint.sh"
    AUTH0_CONTEXT_FILE="auth0.sh"
    OPENAI_CONTEXT_FILE="open_ai.sh"
    CUSTOM_SCHEMAS_CONTEXT_FILE="schemas.sh"
    DEV_DOCKERFILE="Dockerfile.dev"
    PROD_DOCKERFILE="Dockerfile"
    COMPOSE_FILE="docker-compose.yml"
    CONTAINER_ENTRYPOINT="bash $ENTRYPOINT_FILE"

    # Seed files - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    ENV_SEED="seed.env"
    README_SEED="README.seed.md"
    CHANGELOG_SEED="CHANGELOG.seed.md"
    DEV_DOCKERFILE_SEED="Dockerfile.seed.dev"
    DOCKERIGNORE_SEED=".dockerignore.seed"
    PROD_DOCKERFILE_SEED="Dockerfile.seed.prod"
    PGADMIN_SERVERS_SEED="servers.seed.json"
    PGADMIN_PASS_SEED="pgpass.seed"
    TOOLS_VERSIONS_SEED="seed.tool-versions"

    # Elixir project files - - - - - - - - - - - - - - - - - - - - - - - - - -
    LOWER_CASE=$( echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' )
    ELIXIR_PROJECT_NAME=$( echo $LOWER_CASE | tr ' ' '_' )
    ELIXIR_MODULE=$(
      echo $LOWER_CASE | sed -E 's/(^| )(\w)/\U\2/g' | sed 's/ //g'
    )
    ASSETS_DIR="assets"
    PROJECT_DIR="lib/${ELIXIR_PROJECT_NAME}"
    WEB_DIR="lib/${ELIXIR_PROJECT_NAME}_web"
    CONTROLLERS_DIR="$WEB_DIR/controllers"
    PLUGS_DIR="$WEB_DIR/plugs"
    ENV_FILE=".env"
    MIX_FILE="mix.exs"
    APPLICATION_FILE="$PROJECT_DIR/application.ex"
    WEB_MODULE_FILE="lib/${ELIXIR_PROJECT_NAME}_web.ex"
    ROUTER_FILE="$WEB_DIR/router.ex"
    CONFIG_FILE="config/config.exs"
    DEV_FILE="config/dev.exs"
    TEST_FILE="config/test.exs"
    RUNTIME_FILE="config/runtime.exs"
    HOMEPAGE_FILE="$CONTROLLERS_DIR/page_html/home.html.heex"
    README_FILE="README.md"
    CHANGELOG_FILE="CHANGELOG.md"
    DOCKERIGNORE=".dockerignore"
    PROD_DOCKERFILE="Dockerfile"
    GITIGNORE_FILE=".gitignore"
    FORMATTER_FILE=".formatter.exs"
    TOOLS_VERSIONS_FILE=".tool-versions"
    # Unit testing directories
    TEST_DIR="test"
    APP_TEST_DIR="$TEST_DIR/$ELIXIR_PROJECT_NAME"
    WEB_TEST_DIR="$TEST_DIR/${ELIXIR_PROJECT_NAME}_web"
    CTRL_TEST_DIR="$WEB_TEST_DIR/controllers"
    PLUGS_TEST_DIR="$WEB_TEST_DIR/plugs"
    MIX_TEST_DIR="$TEST_DIR/mix"
    SUPPORT_DIR="$TEST_DIR/support"
    FIXTURES_DIR="$SUPPORT_DIR/fixtures"
    # Unit testing seeds directories
    TESTS_SEED_DIR="test"
    APP_SEED_DIR="$TESTS_SEED_DIR/app"
    WEB_SEED_DIR="$TESTS_SEED_DIR/web"
    CTRL_SEED_DIR="$WEB_SEED_DIR/controllers"
    PLUGS_SEED_DIR="$WEB_SEED_DIR/plugs"
    MIX_SEED_DIR="$TESTS_SEED_DIR/mix"
    SUPPORT_SEED_DIR="$TESTS_SEED_DIR/support"
    FIXTURES_SEED_DIR="$SUPPORT_SEED_DIR/fixtures"

    # Production database - - - - - - - - - - - - - - - - - - - - - - - - - - -
    DB_NAME="${ELIXIR_PROJECT_NAME}_prod"

    # PGAdmin configuration files - - - - - - - - - - - - - - - - - - - - - - -
    SERVERS_FILE="servers.json"
    PASS_FILE="pgpass"
    PROJECT_PGADMIN_PATH="priv/repo/$PGADMIN_DIR"
    PGADMIN_PATH="$SOURCE_CODE_PATH/$PROJECT_PGADMIN_PATH"

    # Git - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    GIT_DIR=$( [ $EXISTING_PROJECT == true ] && echo "../.git" || echo ".git" )
    if [ -d $GIT_DIR ]
    then REPO_URL=$(git config --get remote.origin.url | sed 's/\.git$//')
    else REPO_URL="https://github.com/user/repo"
    fi
    REPO_OWNER=$( echo $REPO_URL | sed -E 's|https://[^/]+/([^/]+)/.*|\1|' )
    REPO_NAME=$(  echo $REPO_URL | sed 's|.*/||' )

  # docker-compose.yml script export variables -------------------------------

    # Docker compose project configuration
    export APP_NAME=$( echo "$LOWER_CASE" | tr ' ' '-' )
    export APP_VERSION=$(
      [ $EXISTING_PROJECT == true ] && [ -f $MIX_FILE ] && \
        sed -n 's/^.*version: "\(.*\)".*/\1/p' "../$MIX_FILE" | head -n 1 || \
        echo $INIT_VERSION
    )

    # Docker images
    DEV_IMAGE="$APP_NAME:$WORKBENCH_VERSION-dev"
    PROD_IMAGE="$APP_NAME:$APP_VERSION"
    export SOURCE_CODE_VOLUME="$SOURCE_CODE_PATH:/app/src"
    export COMPOSE_PROJECT_NAME=$APP_NAME
    export COMPOSE_DOCKERFILE=$PROD_DOCKERFILE
    export COMPOSE_IMAGE=$PROD_IMAGE
    # Elixir app configuration
    export APP_INTERNAL_PORT="4000"
    export ENV_PATH="$SOURCE_CODE_PATH/$ENV_FILE"
    # Database configuration
    export DB_INTERNAL_PORT="5432"
    export DB_USER="postgres"
    export DB_PASS="postgres"
    export DB_HOST="database_host"
    # PGAdmin configuration
    export PGADMIN_INTERNAL_PORT="5050"
    export PGADMIN_EMAIL="pgadmin4@pgadmin.org"
    export PGADMIN_PASSWORD="pass"
    export PGADMIN_SERVERS_PATH="$PGADMIN_PATH/$SERVERS_FILE"
    export PGADMIN_PASS_PATH="$PGADMIN_PATH/$PASS_FILE"

  # Implementations for elixir project  --------------------------------------

    # PSQL extras implementation
    # https://hex.pm/packages/ecto_psql_extras
    PSQL_EXTRAS_VERSION="~> 0.8"
    # Flame on implementation
    # https://hex.pm/packages/flame_on
    FLAMEON_VERSION="~> 0.7"
    # Credo implementation
    # https://hex.pm/packages/credo
    CREDO_VERSION="~> 1.7"
    # Git hooks implementation
    # https://hex.pm/packages/git_hooks
    GITHOOKS_VERSION="~> 0.7"
    # Ex Machina implementation
    # https://hex.pm/packages/ex_machina
    EXMACHINA_VERSION="~> 2.8"
    # Mock implementation
    # https://hex.pm/packages/mock
    MOCK_VERSION="~> 0.3"
    # ExDebug implementation
    # https://hex.pm/packages/ex_debug
    EXDEBUG_VERSION="~> 1.0"
    # ExDoc documentation implementation
    # https://hex.pm/packages/ex_doc
    EXDOC_VERSION="~> 0.38"
    # API REST documentation implementation
    # https://hex.pm/packages/open_api_spex
    OPEN_API_VERSION="~> 3.21"
    # Coveralls report implementation
    # https://hex.pm/packages/excoveralls
    COVERALLS_VERSION="~> 0.18"
    MINIMUM_COVERAGE="80"
    # Schemas enhancements implementation
    # https://hex.pm/packages/ecto_enum
    ECTO_ENUM_VERSION="~> 1.4"
    # DbSchema documentation enhancements implementation
    # https://hex.pm/packages/html_entities
    HTML_ENTITIES_VERSION="~> 0.5"

    # Auth0 implementation
    # https://hex.pm/packages/auth0_jwks
    AUTH0_JWKS_VERSION="~> 0.3"
    AUTH0_PROD_JS="https://cdn.auth0.com/js/auth0-spa-js"
    AUTH0_PROD_JS+="/2.0/auth0-spa-js.production.js"

  # Format codes -------------------------------------------------------------

    # Colors
    C1="\x1B[38;5;1m" # Dark-red
    C2="\x1B[4;34m"   # Blue underline
    C3="\x1B[38;5;2m" # Green
    # Format             
    B="\x1B[1m" # Bold
    R="\x1B[0m" # Reset

    Li=$C2 # Link color

# FUNCTIONS ====================================================================

  # If echo handles -e option, overrides the command
  if [ "$(echo -e)" == "" ]; then echo() { command echo -e "$@"; } fi

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
    section_content "./$script_name [COMMAND]"
    
    section "DESCRIPTION"
    section_content \
      "This is a script for creating ${B}Elixir${R} (${Li}https://elixir-lang.org${R}) projects" \
      "with the ${B}Phoenix${R} (${Li}https://www.phoenixframework.org${R}) framework and" \
      "deploying them on 'localhost' using a specific service architecture with" \
      "Docker containers. It eliminates the need to install anything other than" \
      "${B}Docker Desktop${R} (${Li}https://www.docker.com/products/docker-desktop${R}) in order" \
      "to create, develop and deploy the project as 'dev' or 'prod' enviroment."

    section "COMMANDS"
    print_command "login [USER] [TOKEN]"
    section_content \
      "Login account in order to download private images." \
      "- USER:  Github username. " \
      "- TOKEN: Authentication token (classic). "

    print_command "new [OPTIONS]"
    section_content \
      "Create a new project and configures it according to config.conf." \
      "- OPTIONS: It can accept all option flags from the task 'mix phx.new'" \
      "  (${Li}https://hexdocs.pm/phoenix/Mix.Tasks.Phx.New.html${R})."

    print_command "setup [-e, --env ENV]"
    section_content \
      "Set or reset the database (if any) and run the seeding script." \
      "- ENV: Enviroment database to setup (Defalut: dev)."

    print_command "up [-e, --env ENV]"
    section_content \
      "Deploy the application on localhost." \
      "- ENV: Enviroment to deploy (Defalut: dev)."

    print_command "run [ARGS...]"
    section_content \
      "Deploy the application executing custom entrypoint commands." \
      "- ARGS: Command(s) to be executed as back-end entrypoint. "

    print_command "delete"
    section_content \
      "Deletes project files and Docker compose project."

    print_command "demo [-e, --env ENV]"
    section_content \
      "Runs consecutively new, setup, up & delete commands." \
      "- ENV: Enviroment to deploy (Defalut: dev)."

    print_command "prune"
    section_content \
      "Stops all containers and prune Docker."

    print_command "remove-workbench"
    section_content \
      "Removes the workbench script along with all its files, leaving the " \
      "generated project files untouched."

    print_command "help"
    section_content \
      "Displays the help section for the workbench script."

    section "LICENSE"
    section_content \
      "MIT license (${Li}https://mit-license.org${R})" \
      "Copyright © 2024 José Luis Pamplona Stoever"
  }

  # confirm <MESSAGE>
    # Prints MESSAGE and spects input prompt for continue or exit the script 
  confirm() {
    echo "⚠️  ${B}Warning${R} $@"
    read -n 1 -p $'Should continue? [y/N] ' INPUT
    if [ "$INPUT" != "y" ]; then exit 0; fi
    echo
  }
  
  # failure
    # Prints error and spects input prompt for continue or cancel
  failure() {
    echo "🛑  ${B}${C1}Failure${R}"
    read -n 1 -p $'Should continue? [y/N] ' INPUT
    if [ "$INPUT" != "y" ]; then exit 1; fi
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

  # terminate <MESSAGE>
    # Print error and terminate with sigerr 1
  terminate() { echo "${B}${C1}Error${R} $@"; echo; exit 1; }

  # update_version
    # Update version badge in README.md file
  update_version() {
    sed -i "s/\(!\[v\).*\(\]\)/\1$WORKBENCH_VERSION\2/" $WORKBENCH_README_FILE
    sed -i \
      "s/\(version-\).*\(-white.*\)/\1$WORKBENCH_VERSION\2/" \
      $WORKBENCH_README_FILE
  }

  # scape_for_sed <STRING>
  scape_for_sed() { echo "$1" | sed 's/[\/&]/\\&/g'; }

  # lines VARIABLE_NAME IDENTATION_LEVEL LINES...
    #
  lines() {
    if [ $# -ge 3 ]; then
      local var="$1"; shift
      local ident="$1"; shift
      local spaces=$(printf '%*s' $((ident * 2)) '')
      local output=""
      local escaped_output
      
      for arg in "$@"; do
        [ "$arg" != "" ] && output+="$spaces$arg"
        output+="\n"
      done

      eval "$var=\"${output::-2}\""
    fi
  }

  # lines VARIABLE_NAME IDENTATION_LEVEL LINES...
    #
  sed_lines() {
    if [ $# -ge 3 ]; then
      local var="$1"; shift
      local ident="$1"; shift
      local spaces=$(printf '%*s' $((ident * 2)) '')
      local output=""
      local escaped_output
      
      for arg in "$@"; do
        [ "$arg" != "" ] && output+="$spaces$arg"
        output+="\n"
      done

      printf -v escaped_output "%q" "${output::-2}"
      eval "$var=\"$escaped_output\""
    fi
  }

  # pattern <action>, <file>, <pattern_identifier>, <new_content>
    # Function to manage seed patterns in the process of creating files.
    # On the seed files these opening and closing tags exists:
    #   <!-- workbench-<pattern_identifier> open -->
    #   <!-- workbench-<pattern_identifier> close -->
    # Using this function the content between tags can be deleted, replaced 
    # or keeped depending on the given action:
    #   action=keep : Delete tags keeping the content between them.
    #   action=delete : Delete tags and the content between them.
    #   action=replace : Delete tags replacing the content between them.
  pattern() {
    [ $# -ge 3 ] && \
      local action="$1" && \
      local file="$2" && \
      local pattern_identifier="$3" && \
      local new_content="$4" && \
      local start_pattern="<!-- workbench-$pattern_identifier open -->" && \
      local end_pattern="<!-- workbench-$pattern_identifier close -->" && \
      local temp_file="$(mktemp)" && \
      start_pattern=$(scape_for_sed "$start_pattern") && \
      end_pattern=$(scape_for_sed "$end_pattern") && \
      if   [ $action == "keep" ]; then
        sed "/$start_pattern/d; /$end_pattern/d" "$file" > "$temp_file" && \
        mv "$temp_file" "$file"

      elif [ $action == "delete" ]; then
        sed "/$start_pattern/,/$end_pattern/d" "$file" > "$temp_file"  && \
        mv "$temp_file" "$file"

      elif [ $action == "replace" ]; then
        sed "/$start_pattern/,/$end_pattern/{
            /$start_pattern/d
            /$end_pattern/d
            c\\$new_content
        }" "$file" > "$temp_file" && \
        mv "$temp_file" "$file"
      
      else args_error "Invalid action."; fi
  }

  # --------------------------------------------------------------------------

  # delete_project_files
    # Delete all files and dirs, excluding the script directory and hiddend files (exept .gitignore, .formatter.exs and .env).
  delete_project_files() {
    find . \
      -maxdepth 1 \
      ! -name "." \
      ! -name ".*" \
      ! -name "$WORKBENCH_DIR" \
      -exec rm -rf {} + && \
    if [ -f "$ENV_FILE" ];            then rm "$ENV_FILE"; fi && \
    if [ -f "$GITIGNORE_FILE" ];      then rm "$GITIGNORE_FILE"; fi && \
    if [ -f "$TOOLS_VERSIONS_FILE" ]; then rm "$TOOLS_VERSIONS_FILE"; fi && \
    if [ -f "$FORMATTER_FILE" ];      then rm "$FORMATTER_FILE"; fi
  }
  
  # delete_project
    # Ask for confirmation. Deletes all project files, the content of
    # the script directory to root and delete the emptied script directory.
  delete_project() {
    confirm "This action will delete all files from the current project." && \
    cd .. && \
    delete_project_files && \
    cd $WORKBENCH_DIR && \
    find . -maxdepth 1 \
      \( -type f -o -type d \) \
      ! -name "." \
      ! -name ".*" \
      -exec mv -t ../ {} + && \
    cd .. && \
    rmdir $WORKBENCH_DIR && \
    rm "$SCRIPTS_DIR/$DEV_DOCKERFILE"
  }

  # prepare_new_project
    # If no project is created, it will move all files into a script directory,
    # if there is a project created already, will ask for confirmation to delete
    # all project files.
    # Creates Dockerfile.dev
  prepare_new_project() {
    # FUNCTIONS --------------------------------------------------------------

      # create_dockerfile_dev
        # Create a Dockerfile.dev file from seed.
      create_dockerfile_dev() {
        local seed_path="$WORKBENCH_DIR/$SEEDS_DIR/$DEV_DOCKERFILE_SEED" 
        local file_path="$WORKBENCH_DIR/$SCRIPTS_DIR/$DEV_DOCKERFILE"
        local scp_contexts_dir_path=$(scape_for_sed "$CONTEXTS_DIR")
        local scp_auth0_context_path=$(scape_for_sed "$AUTH0_CONTEXT_FILE")
        local scp_openai_context_path=$(scape_for_sed "$OPENAI_CONTEXT_FILE")
        local scp_custom_context_path=$(
          scape_for_sed "$CUSTOM_SCHEMAS_CONTEXT_FILE"
        )

        cp $seed_path $file_path

        if [ "$AUTH0" == true ]
        then pattern keep   $file_path "auth0"
        else pattern delete $file_path "auth0"
        fi

        if [ "$OPENAI" == true ]
        then pattern keep   $file_path "openai"
        else pattern delete $file_path "openai"
        fi

        if [ "$CUSTOM_SCHEMAS" == true ]
        then pattern keep   $file_path "custom-schemas"
        else pattern delete $file_path "custom-schemas"
        fi

        sed -i "s/%{elixir_version}/$ELIXIR_VERSION/"          $file_path
        sed -i "s/%{erlang_version}/$ERLANG_VERSION/"          $file_path
        sed -i "s/%{debian_version}/$DEBIAN_VERSION/"          $file_path
        sed -i "s/%{entrypoint}/$ENTRYPOINT_FILE/"             $file_path
        sed -i "s/%{contexts}/$scp_contexts_dir_path/"         $file_path
        sed -i "s/%{auth0_context}/$scp_auth0_context_path/"   $file_path
        sed -i "s/%{openai_context}/$scp_openai_context_path/" $file_path
        sed -i "s/%{custom_context}/$scp_custom_context_path/" $file_path

      }

    # SCRIPT -----------------------------------------------------------------

      if [ $EXISTING_PROJECT == true ]; then
        # Deletes all files and dirs, excluding the 
        # script and hiddend files (exept .gitignore, .formatter.exs and .env).
        confirm \
          "A project is already created. This action will overwrite all files" \
          "from the current project." && \
        cd .. && \
        delete_project_files
      else
        # If a script directory is present its deleted. The script directory is
        # created. Moves all root files (excluding hiddend files and dirs) into 
        # the script directory.
        if   [ -d $WORKBENCH_DIR ]
        then rm -rf $WORKBENCH_DIR
        else mkdir $WORKBENCH_DIR
        fi && \
        find . -maxdepth 1 \
          \( -type f -o -type d \) \
          ! -name "." \
          ! -name ".*" \
          ! -name "$WORKBENCH_DIR" \
          ! -name "$(basename "$0")" \
          -exec mv -t "$WORKBENCH_DIR" {} + && \
        cp $0 "$WORKBENCH_DIR/$0" && \
        rm $0
      fi && \
      create_dockerfile_dev
  }

  # create_docker_compose_file
    # Create a docker-compose.yml file from script one.
  create_docker_compose_file() {
    local seed_path="$WORKBENCH_DIR/$SCRIPTS_DIR/$COMPOSE_FILE"
    local file_path="$COMPOSE_FILE"

    local    source_code_path=$(scape_for_sed "$SOURCE_CODE_PATH")
    local        scp_env_path=$(scape_for_sed "$ENV_PATH")
    local scp_src_volume_path=$(scape_for_sed "$SOURCE_CODE_VOLUME")
    local    scp_servers_path=$(scape_for_sed "$PGADMIN_SERVERS_PATH")
    local       scp_pass_path=$(scape_for_sed "$PGADMIN_PASS_PATH")

    scp_env_path=".${scp_env_path//$(scape_for_sed "$source_code_path")/}"
    scp_src_volume_path=".\/${scp_src_volume_path//$(scape_for_sed "$source_code_path")/}"
    scp_servers_path=".${scp_servers_path//$(scape_for_sed "$source_code_path")/}"
    scp_pass_path=".${scp_pass_path//$(scape_for_sed "$source_code_path")/}"

    cp $seed_path $file_path
    sed -i "s/\$COMPOSE_DOCKERFILE/$COMPOSE_DOCKERFILE/"         $file_path
    sed -i "s/\$COMPOSE_IMAGE/$COMPOSE_IMAGE/"                   $file_path
    sed -i "s/\$APP_NAME/$APP_NAME/"                             $file_path
    sed -i "s/\$APP_VERSION/$APP_VERSION/"                       $file_path
    sed -i "s/\$APP_CONTAINER_NAME/$APP_CONTAINER_NAME/"         $file_path
    sed -i "s/\$APP_PORT/$APP_PORT/"                             $file_path
    sed -i "s/\$APP_INTERNAL_PORT/$APP_INTERNAL_PORT/"           $file_path
    sed -i "s/\$ENV_PATH/$scp_env_path/"                         $file_path
    sed -i "s/\$SOURCE_CODE_VOLUME/$scp_src_volume_path/"        $file_path
    sed -i "s/\$DB_CONTAINER_NAME/$DB_CONTAINER_NAME/"           $file_path
    sed -i "s/\$DB_INTERNAL_PORT/$DB_INTERNAL_PORT/"             $file_path
    sed -i "s/\$DB_PORT/$DB_PORT/"                               $file_path
    sed -i "s/\$DB_HOST/$DB_HOST/"                               $file_path
    sed -i "s/\$DB_USER/$DB_USER/"                               $file_path
    sed -i "s/\$DB_PASS/$DB_PASS/"                               $file_path
    sed -i "s/\$PGADMIN_CONTAINER_NAME/$PGADMIN_CONTAINER_NAME/" $file_path
    sed -i "s/\$PGADMIN_EMAIL/$PGADMIN_EMAIL/"                   $file_path
    sed -i "s/\$PGADMIN_PASSWORD/$PGADMIN_PASSWORD/"             $file_path
    sed -i "s/\$PGADMIN_INTERNAL_PORT/$PGADMIN_INTERNAL_PORT/"   $file_path
    sed -i "s/\$PGADMIN_PORT/$PGADMIN_PORT/"                     $file_path
    sed -i "s/\$PGADMIN_SERVERS_PATH/$scp_servers_path/"         $file_path
    sed -i "s/\$PGADMIN_PASS_PATH/$scp_pass_path/"               $file_path
    sed -i "s/\$POSTGRES_IMAGE_VERSION/$POSTGRES_IMAGE_VERSION/" $file_path
    sed -i "s/\$PGADMIN_IMAGE_VERSION/$PGADMIN_IMAGE_VERSION/"   $file_path

    if [ $ECTO == false ]; then sed -i '26,65d' $file_path; fi
  }

  # configure_files PHOENIX_NEW_OPTIONS
    # After project creation it configures some elixir files and add new ones.
  configure_files() {
    # CONFIGURATION ----------------------------------------------------------
      local PHOENIX_NEW_OPTIONS="$@"
      NO_HTML=$(
        local result=false
        for arg in $PHOENIX_NEW_OPTIONS; do
          if [ "$arg" = "--no-html" ]; then
            result=true
            break
          fi
        done
        echo $result
      )
      ECTO=$(
        local result=true
        for arg in $PHOENIX_NEW_OPTIONS; do
          if [ "$arg" = "--no-ecto" ]; then
            result=false
            break
          fi
        done
        echo $result
      )
      MAILER=$(
        local result=true
        for arg in $PHOENIX_NEW_OPTIONS; do
          if [ "$arg" = "--no-mailer" ]; then
            result=false
            break
          fi
        done
        echo $result
      )
      DASHBOARD=$(
        local result=true
        for arg in $PHOENIX_NEW_OPTIONS; do
          if [ "$arg" = "--no-dashboard" ]; then
            result=false
            break
          fi
        done
        echo $result
      )

    # FUNCTIONS --------------------------------------------------------------

      # create_pgadmin_credentials
      create_pgadmin_credentials() {

        if [ -d $PROJECT_PGADMIN_PATH ];
        then
          rm -rf $PROJECT_PGADMIN_PATH
        fi

        mkdir $PROJECT_PGADMIN_PATH

        # Plant pgpass file for PGAdmin.
        local seed_path="$WORKBENCH_DIR/$SEEDS_DIR/$PGADMIN_PASS_SEED"
        local file_path="$PROJECT_PGADMIN_PATH/$PASS_FILE"
        cp $seed_path $file_path
        sed -i "s/%{db_host}/$DB_HOST/" $file_path
        sed -i "s/%{db_port}/$DB_PORT/" $file_path
        sed -i "s/%{db_user}/$DB_USER/" $file_path
        sed -i "s/%{db_pass}/$DB_PASS/" $file_path

        # Plant servers.json file for PGAdmin.
        local seed_path="$WORKBENCH_DIR/$SEEDS_DIR/$PGADMIN_SERVERS_SEED"
        local file_path="$PROJECT_PGADMIN_PATH/$SERVERS_FILE"
        cp $seed_path $file_path
        sed -i "s/%{project_name}/$PROJECT_NAME/" $file_path
        sed -i "s/%{db_host}/$DB_HOST/" $file_path
        sed -i "s/%{db_port}/$DB_PORT/" $file_path
        sed -i "s/%{db_user}/$DB_USER/" $file_path
      }

      # adjust_mix
        # Modify the version to 0.0.0
      adjust_mix() {
        sed -i \
          "s/version:\s*\"[0-9]*.[0-9]*.[0-9]*\"/version: \"$INIT_VERSION\"/" \
          $MIX_FILE
      }

      # adjust_config
        # Configures the timestamps and id types in config.exs file.
      adjust_config() {

        # prepend_config
          #
        prepend_config() {
          sed_lines "content" 0 "$@"
          sed -i '/import Config/a\'"$content" $CONFIG_FILE
        }

        prepend_config \
          "" \
          "# Enabling ANSI color codes for TTY emulation" \
          "config :elixir, ansi_enabled: true"

        # Remove generators config
        # sed -i "s/\(ecto_repos: \[.*.Repo\]\),/\1/" $CONFIG_FILE
        # sed -i "/generators: \[timestamp_type: :utc_datetime\]/d" $CONFIG_FILE
        sed -i "s/generators: \[timestamp_type: :utc_datetime\]/generators: \[timestamp_type: :utc_datetime_usec\]/" $CONFIG_FILE

        if [ ! -z "$TIMESTAMPS" ] || [ ! -z "$ID_TYPE" ]; then
          # Set the database config
          DATABASE_COMMENT="# Configure your database"
          DB_CONFIG=""
          if [ ! -z "$ID_TYPE" ]; then
            DB_CONFIG+="  migration_primary_key: \[type: :$ID_TYPE\]"
            if [ ! -z "$TIMESTAMPS" ]; then DB_CONFIG+=",\n"; fi
          fi
          if [ ! -z "$TIMESTAMPS" ]; then
            DB_CONFIG+="  migration_timestamps: [type: :$TIMESTAMPS]"
          fi

          # Add the config to the file
          sed -i \
            "s/ecto_repos: \[\(.*.Repo\)\]/&\n\n$DATABASE_COMMENT\nconfig :$ELIXIR_PROJECT_NAME, \1,\n$DB_CONFIG/" \
            $CONFIG_FILE
        fi
      }

      # adjust_config_dev
        # Modify the hostname to the Docker DB container hostname.
        # Allow access to all machines in the Docker network.
      adjust_config_dev() {
        sed -i \
          "s/\(hostname: \)\"\(.*\)\"/\1System.get_env(\"DATABASE_HOST\") || \"\2\"/" \
          $DEV_FILE && \
        sed -i \
          "s/http: \[ip: {127, 0, 0, 1}/http: \[ip: {0, 0, 0, 0}/" \
          $DEV_FILE
      }

      # adjust_config_test
        # Modify the hostname to the Docker DB container hostname.
        # Allow access to all machines in the Docker network.
      adjust_config_test() {
        sed -i \
          "s/\(hostname: \)\"\(.*\)\"/\1System.get_env(\"DATABASE_HOST\") || \"\2\"/" \
          $TEST_FILE

        echo \
          "\n# Enable dev routes for exdocs, dashboard and mailbox endpoints" \
          "\nconfig :$ELIXIR_PROJECT_NAME, dev_routes: true" \
          >> $TEST_FILE
      }

      # adjust_config_runtime
        #
      adjust_config_runtime() {
        if [ ! -f $RUNTIME_FILE ]; then
          terminate "The $RUNTIME_FILE file does not exist."
        else
          local AUTH0_RUNTIME_SEED_FILE="runtime.seed.exs"

          sed -i \
            "18r $WORKBENCH_DIR/$SEEDS_DIR/$AUTH0_RUNTIME_SEED_FILE" \
            $RUNTIME_FILE
          sed -i "s/%{elixir_project_name}/$ELIXIR_PROJECT_NAME/" $RUNTIME_FILE

          if [ "$AUTH0" == true ]
          then pattern keep   $RUNTIME_FILE "auth0"
          else pattern delete $RUNTIME_FILE "auth0"
          fi

          if [ "$OPENAI" == true ]
          then pattern keep   $RUNTIME_FILE "openai"
          else
            pattern delete $RUNTIME_FILE "openai"
            sed -i "s/\(auth0_audience: auth0_audience\),/\1/" $RUNTIME_FILE
          fi

          true
        fi
      }

      # adjust_gitignore
        # Prepends .tool-sersions and .env files.
      adjust_gitignore() {
        # sed -i \
        #   "1i\\# ASDF .tools-versions file." \
        #   $GITIGNORE_FILE && \
        sed -i "1i\\$TOOLS_VERSIONS_FILE\\n" $GITIGNORE_FILE && \
        sed -i "1i\\$ENV_FILE\\n" $GITIGNORE_FILE && \
        sed -i \
          "1i\\# Secrets required to configure the application." \
          $GITIGNORE_FILE
      }

      # adjust_homepage
        #
      adjust_homepage() {
        # add_workbench_version
          #
        add_workbench_version() {
          local ident="$1"; shift

          sed_lines "content" $ident "$@"

          sed -i '/v<%= Application.spec(:phoenix, :vsn) %>/,/<\/h1>/ {
            /<\/h1>/ {
              a\'"${content}"'
            }
          }
          ' $HOMEPAGE_FILE
        }

        # add_icon_button
          #
        add_icon_button() {
          local  ident="$1"; shift

          sed_lines "content" $ident "$@"

          sed -i '/Changelog/,/<\/a>/ {
            /<\/a>/ {
              a\'"${content}"'
            }
          }
          ' $HOMEPAGE_FILE
        }

        if [ -f $HOMEPAGE_FILE ]
        then
          add_workbench_version 2 \
            "<h1 class=\"text-brand mt-0 flex items-center text-sm font-semibold leading-6\">" \
            "  Dockerized Elixir Workbench" \
            "  <small class=\"bg-brand/5 text-[0.8125rem] ml-3 rounded-full px-2 font-medium leading-6\">" \
            "    v$WORKBENCH_VERSION" \
            "  </small>" \
            "</h1>"
          if [ $EXDOC == true ]
          then
            # Reduce overall top padding
            sed -i \
              "s/\(\"px-4 py-10 sm\:px-6 sm\:py-28 lg\:px-8 xl\:px-28 xl\:py-32\"\)/\1 style=\"    padding-top\: 3\.85rem\;\"/" \
              $HOMEPAGE_FILE

            # Set icon buttons columns to 2
            sed -i \
              "s/\(mt-10 grid grid-cols-1 gap-x-6 gap-y-4 sm:grid-cols\)-.*\"/\1-2\"/" \
              $HOMEPAGE_FILE

            add_icon_button 5 \
              "<a" \
              "  href=\"dev/docs/\"" \
              "  class=\"group relative rounded-2xl px-6 py-4 text-sm font-semibold leading-6 text-zinc-900 sm:py-6\"" \
              ">" \
              "  <span class=\"absolute inset-0 rounded-2xl bg-zinc-50 transition group-hover:bg-zinc-100 sm:group-hover:scale-105\" style=\"background-color: #f07260\">" \
              "  </span>" \
              "  <span class=\"relative flex items-center gap-4 sm:flex-col\" style=\"color: white\">" \
              "    <svg viewBox=\"0 0 24 24\" fill=\"none\" aria-hidden=\"true\" class=\"h-6 w-6\">" \
              "      <path d=\"m12 4 10-2v18l-10 2V4Z\" fill=\"#FFFFFF\" fill-opacity=\".15\" />" \
              "      <path" \
              "        d=\"M12 4 2 2v18l10 2m0-18v18m0-18 10-2v18l-10 2\"" \
              "        stroke=\"#FFFFFF\"" \
              "        stroke-width=\"2\"" \
              "        stroke-linecap=\"round\"" \
              "        stroke-linejoin=\"round\"" \
              "      />" \
              "    </svg>" \
              "    $PROJECT_NAME ExDoc" \
              "  </span>" \
              "</a>"
          else
            # Reduce overall top padding
            sed -i \
              "s/\(\"px-4 py-10 sm\:px-6 sm\:py-28 lg\:px-8 xl\:px-28 xl\:py-32\"\)/\1 style=\"    padding-top\: 6\.5rem\;\"/" \
              $HOMEPAGE_FILE
          fi
        fi
      }

      # create_env
        # Create a new .env file from seed.
        # According to the workbench/config.conf file it choose the necesary
        # enviroment variables for the .env file.
      create_env() {
        local seed_path="$WORKBENCH_DIR/$SEEDS_DIR/$ENV_SEED"
        local file_path="$ENV_FILE"
        local secret_key_base=$(
          head -c $((64 * 2)) /dev/urandom | \
          base64 | \
          tr -dc 'a-zA-Z0-9' | \
          head -c 64
        )
        local db_url="ecto:\/\/$DB_USER:$DB_PASS@$DB_HOST\/$DB_NAME"

        cp $seed_path $file_path

        if [ "$AUTH0" == true ]
        then pattern keep   $file_path "auth0"
        else pattern delete $file_path "auth0"
        fi

        if [ "$OPENAI" == true ]
        then pattern keep   $file_path "openai"
        else pattern delete $file_path "openai"
        fi

        if [ "$STRIPE" == true ]
        then pattern keep   $file_path "stripe"
        else pattern delete $file_path "stripe"
        fi

        sed -i "s/%{app_internal_port}/$APP_INTERNAL_PORT/" $file_path
        sed -i "s/%{secret_key_base}/$secret_key_base/" $file_path
        sed -i "s/%{database_url}/$db_url/" $file_path
        sed -i "s/%{app_name}/$APP_NAME/" $file_path
      }

      # create_changelog
        # Create a new CHANGELOG file from seed.
        # Set the initial version entry date to actual date.
      create_changelog() {
        local seed_path="$WORKBENCH_DIR/$SEEDS_DIR/$CHANGELOG_SEED"
        local file_path="$CHANGELOG_FILE"
        local today=$( date +%Y-%m-%d )

        cp $seed_path $file_path
        sed -i "s/%{init_version}/$INIT_VERSION/" $file_path
        sed -i "s/%{creation_date}/$today/"       $file_path
      }

      # create_readme
        # Create a new README file from seed.
        # Adjust project name into README.
        # According to the workbench/config.conf file it redact the README file.
      create_readme(){
        local seed_path="$WORKBENCH_DIR/$SEEDS_DIR/$README_SEED"
        local file_path=$README_FILE
        local env_content=""
        while IFS= read -r line; do
          env_content+="    ${line}\n"
        done < $ENV_FILE

        if [ "$INTERFACE" == "graphql" ]; then local api_type="GraphQL"
        elif [ "$INTERFACE" == "rest" ];  then local api_type="REST"
        fi
        
        cp $seed_path $file_path
        sed -i "s/%{project_name}/$PROJECT_NAME/"          $file_path
        sed -i "s/%{api_type}/$api_type/"                  $file_path
        sed -i "s/%{repo_url}/$(scape_for_sed $REPO_URL)/" $file_path
        sed -i "s/%{repo_badge}/$REPO_OWNER\/$REPO_NAME/"  $file_path
        sed -i "s/%{port}/$APP_INTERNAL_PORT/"             $file_path

        pattern replace $file_path "env" \
          "    \`\`\`elixir\n$env_content\n    \`\`\`"
        
        if [ "$NO_HTML" == true ]
        then pattern delete $file_path "html"
        else pattern keep   $file_path "html"
        fi

        if [ "$ENHANCE" == true ]
        then pattern keep   $file_path "enhancements"
        else pattern delete $file_path "enhancements"
        fi

        if [ "$MAILER" == true ]
        then pattern keep   $file_path "mailer"
        else pattern delete $file_path "mailer"
        fi

        if [ "$DASHBOARD" == true ]
        then pattern keep   $file_path "dashboard"
        else pattern delete $file_path "dashboard"
        fi

        if [ "$EXDOC" == true ]
        then pattern keep   $file_path "exdoc"
        else pattern delete $file_path "exdoc"
        fi

        if [ "$COVERALLS" == true ]
        then
          sed -i "s/%{coverage_command}/mix cover/" $file_path
          pattern keep $file_path "coveralls"
        else
          sed -i "s/%{coverage_command}/mix test --cover/" $file_path
          pattern delete $file_path "coveralls"
        fi

        if [ "$HEALTH" == true ]
        then pattern keep   $file_path "healthcheck"
        else pattern delete $file_path "healthcheck"
        fi

        if [ "$AUTH0" == true ]
        then pattern keep   $file_path "auth0"
        else pattern delete $file_path "auth0"
        fi

        if [ "$OPENAI" == true ]
        then pattern keep   $file_path "openai"
        else pattern delete $file_path "openai"
        fi

        if [ "$STRIPE" == true ]
        then pattern keep   $file_path "stripe"
        else pattern delete $file_path "stripe"
        fi

        if   [ "$INTERFACE" == "rest" ]; then
          pattern keep   $file_path "rest"
          pattern delete $file_path "graphql"
        elif [ "$INTERFACE" == "graphql" ]; then
          pattern keep   $file_path "graphql"
          pattern delete $file_path "rest"
        fi
      }

      # create_dockerignore
        # Create a new production Dockerfile file from seed.
        # Adjust elixir, erlang and debian versions into Dockerfile.
        # Adjust project name directory for build path in Dockerfile.
      create_dockerignore(){
        local seed_path="$WORKBENCH_DIR/$SEEDS_DIR/$DOCKERIGNORE_SEED"
        local file_path="$DOCKERIGNORE"

        cp $seed_path $file_path
      }

      # create_dockerfile_prod
        # Create a new production Dockerfile file from seed.
        # Adjust elixir, erlang and debian versions into Dockerfile.
        # Adjust project name directory for build path in Dockerfile.
      create_dockerfile_prod(){
        local seed_path="$WORKBENCH_DIR/$SEEDS_DIR/$PROD_DOCKERFILE_SEED"
        local file_path="$PROD_DOCKERFILE"

        cp $seed_path $file_path
        sed -i "s/%{app_dir}/$ELIXIR_PROJECT_NAME/" $file_path
        sed -i "s/%{elixir_version}/$ELIXIR_VERSION/" $file_path
        sed -i "s/%{erlang_version}/$ERLANG_VERSION/" $file_path
        sed -i "s/%{debian_version}/$DEBIAN_VERSION/" $file_path
      }

      # create_dockerfile_dev
        # Create a new devuction Dockerfile file from seed.
        # Adjust elixir, erlang and debian versions into Dockerfile.
        # Adjust project name directory for build path in Dockerfile.
      create_dockerfile_dev(){
        # TODO
        echo "create_dockerfile_dev -WIP"
        # local seed_path="$WORKBENCH_DIR/$SEEDS_DIR/$DEV_DOCKERFILE_SEED"
        # local file_path="$DEV_DOCKERFILE"

        # cp $seed_path $file_path
        # sed -i "s/%{app_dir}/$ELIXIR_PROJECT_NAME/" $file_path
        # sed -i "s/%{elixir_version}/$ELIXIR_VERSION/" $file_path
        # sed -i "s/%{erlang_version}/$ERLANG_VERSION/" $file_path
        # sed -i "s/%{debian_version}/$DEBIAN_VERSION/" $file_path
      }

      # create_tool_versions
        # Create a ASDF .tools-versions file from seed.
      create_tool_versions() {
        local seed_path="$WORKBENCH_DIR/$SEEDS_DIR/$TOOLS_VERSIONS_SEED"
        local file_path="$TOOLS_VERSIONS_FILE"
        local erlang_mayor=$(echo $ERLANG_VERSION | cut -d '.' -f1)

        cp $seed_path $file_path
        sed -i "s/%{elixir_version}/$ELIXIR_VERSION/" $file_path
        sed -i "s/%{erlang_version}/$ERLANG_VERSION/" $file_path
        sed -i "s/%{erlang_mayor}/$erlang_mayor/" $file_path
      }

    # SCRIPT -----------------------------------------------------------------

    create_pgadmin_credentials && \
    adjust_mix && \
    adjust_config && \
    adjust_config_dev && \
    adjust_config_test && \
    adjust_config_runtime && \
    adjust_gitignore && \
    if [ "$NO_HTML" == false ]; then adjust_homepage; fi && \
    create_env && \
    create_changelog && \
    create_readme && \
    create_dockerignore && \
    create_dockerfile_prod && \
    create_docker_compose_file && \
    create_tool_versions
    # create_dockerfile_dev && \
  }

  # implement_features
    #
  implement_features() {

      # create_mix_task_path_if_missing
        # 
      create_mix_task_path_if_missing() {
        [ ! -d $MIX_DIR_PATH ] && mkdir $MIX_DIR_PATH
        [ ! -d $MIX_TASK_PATH ] && mkdir $MIX_TASK_PATH
        [ ! -d $MIX_TEST_DIR ]  && mkdir $MIX_TEST_DIR
        [ ! -d "$MIX_TEST_DIR/tasks" ] && mkdir "$MIX_TEST_DIR/tasks"
      }

      # create_openapi_schema_path_if_missing
        # 
      create_openapi_schema_path_if_missing() {
        [ ! -d $OPEN_API_SCHEMAS_DIR ] && mkdir $OPEN_API_SCHEMAS_DIR
      }

    # CONFIGURATION ----------------------------------------------------------
      local ELIXIR_ASSETS_PATH="assets"
      local MIX_DIR_PATH="lib/mix"
      local MIX_TASK_PATH="$MIX_DIR_PATH/task"

      # Shared between ExDoc & Coveralls
      # ExDoc
      local EXDOC_ASSETS_DIR="exdoc"
      local ELIXIR_EXDOC_ASSETS_PATH="$ELIXIR_ASSETS_PATH/$EXDOC_ASSETS_DIR"
      # Coveralls
      local ELIXIR_COVERALLS_DIR="cover"
      local COVERALLS_OUTPUT_DIR="html"
      if [ "$EXDOC" == true ]
      then
        local COVERALLS_PATH="$ELIXIR_EXDOC_ASSETS_PATH/$ELIXIR_COVERALLS_DIR";
      else
        local COVERALLS_PATH="$ELIXIR_ASSETS_PATH/$ELIXIR_COVERALLS_DIR";
      fi
      local COVERALLS_OUTPUT_PATH="$COVERALLS_PATH/$COVERALLS_OUTPUT_DIR"
      local EXDOC_TEST_FILE="testing.md"

      # Shared between interface REST & Auth0, OpenAI and Healthcheck
      local OPEN_API_DIR="$WEB_DIR/open_api"
      local OPEN_API_SCHEMAS_DIR="$OPEN_API_DIR/schemas"

      [ ! -d $APP_TEST_DIR ] && mkdir $APP_TEST_DIR
      [ ! -d $CTRL_TEST_DIR ] && mkdir $CTRL_TEST_DIR
      [ ! -d $PLUGS_TEST_DIR ] && mkdir $PLUGS_TEST_DIR
      [ ! -d $OPEN_API_DIR ] && mkdir $OPEN_API_DIR
      [ ! -d $OPEN_API_SCHEMAS_DIR ] && mkdir $OPEN_API_SCHEMAS_DIR
      create_mix_task_path_if_missing
      
    # FUNCTIONS --------------------------------------------------------------

      feature_init() { echo "${C3}* implementing ${R} $@"; }

      # mix_insert FUNCTION LINES...
        # Insert a new line on mix.exs deps list
      mix_insert() {
        local function="$1"; shift
        sed_lines "content" 3 "$@"
        sed -i '/defp\? '"$function"' do/,/end/ {
          /^    \]/i\'"${content}"'
        }' $MIX_FILE
      }

      # mix_append FUNCTION STRING
        # Append a string on the last line on mix.exs deps list
      mix_append() {
        [ $# -eq 2 ] && \
        sed -i '/defp\? '"$1"' do/,/end/ {
          /^\s*defp\? '"$1"' do/ b
          /^    \[/ b
          /^\s*$/ b
          /^\s*#.*$/ b
          /^.*\[$/ b
          /^.*{$/ b
          /^    \]/ b
          /^ \{7,\}.*/ b
          /^\s*end/ b
          s/\([^,]$\)/\1'"$2"'/
        }' $MIX_FILE
      }

      # mix_insert_after_function FUNCTION LINES...
      mix_insert_after_function() {
        [ $# -ge 2 ] && \
        local function="$1"; shift
        sed_lines "content" 1 "$@"
        sed -i '/defp\? '"$function"' do/,/end/ {
          /end/a\'"${content}"'
        }' $MIX_FILE
      }

      # router_add_pipeline
        #
      router_add_pipeline() {
        local last_pipeline=$(
          awk '
            /^ *pipeline .* do *$/ {
              in_block = 1
              match($0, /^ *pipeline (.*) do *$/, arr)
              last = arr[1]
            }
            /^end$/ {
              if (in_block) {
                in_block = 0
              }
            }
            END {
              print last
            }
          ' $ROUTER_FILE
        )
        sed_lines "content" 1 "$@"
        sed -i '/pipeline '"${last_pipeline}"' do/,/end/ {
          /end/ {
            a\\n'"${content}"'
          }
        }
        ' $ROUTER_FILE
      }

      # router_add_scope SCOPE PIPE IDENTATION_LEVEL
      router_add_scope() {
        local  scope="$1"; shift
        local   pipe="$1"; shift
        local  ident="$1"; shift
        sed_lines "content" $ident "$@"
        sed -i '/scope '"${scope}"' do/,/end/ {
          /pipe_through '"${pipe}"'/,/end/ {
            /end/ {
              a\\n'"${content}"'
            }
          }
        }
        ' $ROUTER_FILE
      }

      # router_add_scope_line SCOPE PIPE IDENTATION_LEVEL
      router_add_scope_line() {
        local scope="$1"; shift
        local pipe="$1"; shift
        local ident="$1"; shift
        sed_lines "content" $ident "$@"
        sed -i '/scope '"${scope}"' do/,/end/ {
          /pipe_through '"${pipe}"'/,/end/ {
            /end/ i\'"${content}"'
          }
        }' $ROUTER_FILE
      }

      # router_change_scope_pipeline SCOPE PIPELINE_SELECTION
        #
      router_change_scope_pipeline() {
        local  scope=$(scape_for_sed "$1"); shift
        local   pipe="$1"; shift

        sed -i '/scope "'"${scope}"'", '"${ELIXIR_MODULE}"'Web do/,/end/ {
          s/pipe_through .*/pipe_through '"${pipe}"'/
        }' $ROUTER_FILE
      }

      # IMPLEMENTATIONS ------------------------------------------------------

      # implement_enhancements
        #
      implement_enhancements() {
        # CONFIGURATION ------------------------------------------------------
          local FEATURE="Default enhancements"

        # FUNCTIONS ----------------------------------------------------------

          # implement_osmon
            #
          implement_osmon() {
            sed -i "s/\(extra_applications: \[.*\)]/\1, :os_mon\]/" $MIX_FILE
          }

          # implement_psql_extras
            #
          implement_psql_extras() {
            mix_insert deps \
              "{:ecto_psql_extras, \"$PSQL_EXTRAS_VERSION\", only: :dev},"
          }

          # implement_flameon
            #
          implement_flameon() {
            mix_insert deps \
              "{:flame_on, \"$FLAMEON_VERSION\"},"

            sed_lines "add_pages" 3 \
              "live_dashboard \"\/dashboard\"," \
              "  metrics: ${ELIXIR_MODULE}Web.Telemetry," \
              "  additional_pages: [" \
              "    flame_on: FlameOn.DashboardPage" \
              "  ]" \
              ""

            sed -i "s/^.*live_dashboard.*Telemetry$/$add_pages/" $ROUTER_FILE
          }

          # implement_credo
            #
          implement_credo() {
            mix_insert deps \
              "{:credo, \"$CREDO_VERSION\", only: [:dev, :test], runtime: false},"
          }

          # implement_githooks
            #
          implement_githooks() {
            mix_insert deps \
              "{:git_hooks, \"$GITHOOKS_VERSION\", only: :dev, runtime: false},"
          }

          # implement_exmachina
            #
          implement_exmachina() {
            mix_insert deps \
              "{:ex_machina, \"$EXMACHINA_VERSION\",  only: :test},"
          }

          # implement_mock
            #
          implement_mock() {
            mix_insert deps "{:mock, \"$MOCK_VERSION\",  only: :test},"
          }

          # implement_exdebug
            #
          implement_exdebug() {
            mix_insert deps "{:ex_debug, \"$EXDEBUG_VERSION\"},"
          }

          # implement_version_task
            #
          implement_version_task() {
            local VERSION_TASK_SEED_FILE="enhancements/version.seed.ex"
            local VERSION_TASK_PATH="$MIX_TASK_PATH/version.ex"
            local TASK_SEED_FILE="$MIX_TEST_DIR/tasks/version_test.seed.exs"
            local TASK_FILE="$MIX_TEST_DIR/tasks/version_test.exs"

            # Plant version.exs file
            create_mix_task_path_if_missing          
            cp \
              "$WORKBENCH_DIR/$SEEDS_DIR/$VERSION_TASK_SEED_FILE" \
              $VERSION_TASK_PATH
            sed -i "s/%{readme_file}/$README_FILE/" $VERSION_TASK_PATH
            sed -i "s/%{mix_file}/$MIX_FILE/" $VERSION_TASK_PATH

            # Plant version_test.exs file
            cp "$WORKBENCH_DIR/$SEEDS_DIR/$TASK_SEED_FILE" $TASK_FILE
          }

          # implement_db_task
            #
          implement_db_task() {
            local DB_TASK_SEED_FILE="enhancements/db.seed.ex"
            local DB_TASK_PATH="$MIX_TASK_PATH/db.ex"
            local TASK_SEED_FILE="$MIX_TEST_DIR/tasks/db_test.seed.exs"
            local TASK_FILE="$MIX_TEST_DIR/tasks/db_test.exs"
            
            # Plant db.exs file
            create_mix_task_path_if_missing
            cp "$WORKBENCH_DIR/$SEEDS_DIR/$DB_TASK_SEED_FILE" $DB_TASK_PATH

            # Plant db_test.exs file
            cp "$WORKBENCH_DIR/$SEEDS_DIR/$TASK_SEED_FILE" $TASK_FILE
          }

          # implement_db_schema_diagrams
            #
          implement_db_schema_diagrams() {
            local DB_SCHEMA_ASSETS_PATH="$WORKBENCH_DIR/assets/db_schema"
            local PROJECT_DB_SCHEMA_ASSETS_PATH="$ASSETS_DIR/db_schema"

            local DBSCHEMA_FILE="$PROJECT_DB_SCHEMA_ASSETS_PATH/database.dbs"
            local MARKDOWN_FILE+="database.md"
            local DIAGRAM_FILE="MainLayout.svg"
            local DIAGRAM_LIGHT_DIR+="light"
            local DIAGRAM_DARK_DIR+="dark"
            local DIAGRAM_LIGHT_FILE="$PROJECT_DB_SCHEMA_ASSETS_PATH/"
            local DIAGRAM_LIGHT_FILE+="$DIAGRAM_LIGHT_DIR/"
            local DIAGRAM_LIGHT_FILE+=$DIAGRAM_FILE
            local DIAGRAM_DARK_FILE="$PROJECT_DB_SCHEMA_ASSETS_PATH/"
            local DIAGRAM_DARK_FILE+="$DIAGRAM_LIGHT_DIR/"
            local DIAGRAM_DARK_FILE+=$DIAGRAM_FILE
            local MARKDOWN_LIGHT_FILE="$PROJECT_DB_SCHEMA_ASSETS_PATH/"
            local MARKDOWN_LIGHT_FILE+="$DIAGRAM_LIGHT_DIR/"
            local MARKDOWN_LIGHT_FILE+=$MARKDOWN_FILE
            local MARKDOWN_DARK_FILE="$PROJECT_DB_SCHEMA_ASSETS_PATH/"
            local MARKDOWN_DARK_FILE+="$DIAGRAM_DARK_DIR/"
            local MARKDOWN_DARK_FILE+=$MARKDOWN_FILE
            
            local DIAGRAM_DIR=""

            if [ "$AUTH0" == true ]; then
              if   [[ "$OPENAI" == true  && "$STRIPE" == true ]]; then
                DIAGRAM_DIR="auth0_openai_stripe"
              elif [[ "$OPENAI" == true  && "$STRIPE" == false ]]; then
                DIAGRAM_DIR="auth0_openai"
              elif [[ "$OPENAI" == false && "$STRIPE" == true ]]; then
                DIAGRAM_DIR="auth0_stripe"
              elif [[ "$OPENAI" == false && "$STRIPE" == false ]]; then
                DIAGRAM_DIR="auth0"
              fi
            else
              DIAGRAM_DIR="none"
            fi

            cp -r \
              "$DB_SCHEMA_ASSETS_PATH/$DIAGRAM_DIR/" \
              "$PROJECT_DB_SCHEMA_ASSETS_PATH/"

            sed -i "s/%{project_name}/$PROJECT_NAME/" $DBSCHEMA_FILE
            sed -i "s/%{project_name}/$PROJECT_NAME/" $DIAGRAM_LIGHT_FILE
            sed -i "s/%{project_name}/$PROJECT_NAME/" $MARKDOWN_LIGHT_FILE
            sed -i "s/%{project_name}/$PROJECT_NAME/" $DIAGRAM_DARK_FILE
            sed -i "s/%{project_name}/$PROJECT_NAME/" $MARKDOWN_DARK_FILE

            sed -i \
              "s/DbSchema.com © [0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}/DbSchema.com © $(date +'%Y-%m-%d')/" \
              $DIAGRAM_LIGHT_FILE
            sed -i \
              "s/DbSchema.com © [0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}/DbSchema.com © $(date +'%Y-%m-%d')/" \
              $DIAGRAM_DARK_FILE
          }

          # implement_htmlentities
            #
          implement_html_entities() {
            mix_insert deps "{:html_entities, \"$HTML_ENTITIES_VERSION\"}"
          }

          # implement_ecto_schema
            #
          implement_ecto_schema() {
            local SCHEMA_SEED_FILE="enhancements/schema.seed.ex"
            local SCHEMA_FILE="$PROJECT_DIR/schema.ex"

            mix_insert deps "{:ecto_enum, \"$ECTO_ENUM_VERSION\"},"

            # Plant Schema.ex Controller
            cp \
              "$WORKBENCH_DIR/$SEEDS_DIR/$SCHEMA_SEED_FILE" \
              $SCHEMA_FILE

            id_type=$(
              if [ "$ID_TYPE" == "uuid" ]
              then echo "Ecto.UUID"
              else echo ":$ID_TYPE"
              fi
            )
            
            sed -i "s/%{elixir_module}/$ELIXIR_MODULE/" $SCHEMA_FILE
            sed -i "s/%{id_type}/$id_type/"             $SCHEMA_FILE
            sed -i "s/%{timestamps_type}/$TIMESTAMPS/"  $SCHEMA_FILE

            [ $EXDOC == true ] && \
            pattern keep $SCHEMA_FILE "exdoc" || \
            pattern delete $SCHEMA_FILE "exdoc"

            [ $AUTH0 == true ] && \
            pattern keep $SCHEMA_FILE "auth0" || \
            pattern delete $SCHEMA_FILE "auth0"
          }

          # implement_helper
            #
          implement_helper() {
            local HELPER_SEED_FILE="enhancements/helper.seed.ex"
            local HELPER_FILE="$PROJECT_DIR/helper.ex"
            local HELPER_TEST_SEED_FILE="$APP_SEED_DIR/helper_test.seed.exs"
            local HELPER_TEST_FILE="$APP_TEST_DIR/helper_test.exs"

            # Plant lib/app/helper.ex
            cp "$WORKBENCH_DIR/$SEEDS_DIR/$HELPER_SEED_FILE" $HELPER_FILE
            sed -i "s/%{elixir_module}/$ELIXIR_MODULE/" $HELPER_FILE
            sed -i "s/%{mix_file}/$MIX_FILE/" $HELPER_FILE
            # Plant helper_test.exs file
            cp \
              "$WORKBENCH_DIR/$SEEDS_DIR/$HELPER_TEST_SEED_FILE" \
              $HELPER_TEST_FILE
            sed -i "s/%{elixir_module}/$ELIXIR_MODULE/" $HELPER_TEST_FILE

            [ "$ECTO" == true ] && \
            pattern keep $HELPER_TEST_FILE "ecto" || \
            pattern delete $HELPER_TEST_FILE "ecto"
          }

          # implement_changeset_error_view
            #
          implement_changeset_error_view() {
            local ERROR_VIEW_SEED_FILE="enhancements/rest/error_json.seed.ex"
            local ERROR_VIEW_FILE="$CONTROLLERS_DIR/error_json.ex"

            # Plant error_json.ex view file
            cp \
              "$WORKBENCH_DIR/$SEEDS_DIR/$ERROR_VIEW_SEED_FILE" \
              $ERROR_VIEW_FILE
            sed -i "s/%{elixir_module}/$ELIXIR_MODULE/" $ERROR_VIEW_FILE
            [ "$ECTO" == true ] && \
            pattern keep $ERROR_VIEW_FILE "ecto" || \
            pattern delete $ERROR_VIEW_FILE "ecto"
          }

          # implemenet_postman_collection
            #
          implemenet_postman_collection() {
            local REST_ASSETS_PATH="$WORKBENCH_DIR/assets/rest"
            local POSTMAN_SUFIX=".postman_collection.json"
            local PROJECT_POSTMAN_FILE="$ELIXIR_PROJECT_NAME$POSTMAN_SUFIX"
            local POSTMAN_FILE=""

            if [ "$AUTH0" == true ]; then
              POSTMAN_FILE+="auth0"
            fi

            if [ "$OPENAI" == true ]; then
              [[ -n "$POSTMAN_FILE" ]] && POSTMAN_FILE+="-"
              POSTMAN_FILE+="openai"
            fi

            if [ "$HEALTH" == true ]; then
              [[ -n "$POSTMAN_FILE" ]] && POSTMAN_FILE+="-"
              POSTMAN_FILE+="health"
            fi

            if [ "$POSTMAN_FILE" != "" ]; then              
              cp \
                "$REST_ASSETS_PATH/$POSTMAN_FILE$POSTMAN_SUFIX" \
                $PROJECT_POSTMAN_FILE
              
              sed -i "s/%{project_name}/$PROJECT_NAME/" $PROJECT_POSTMAN_FILE
            fi
          }

          # implement_unit_testing
            #
          implement_unit_testing() {
            local APPLICATION_SEED_FILE="$APP_SEED_DIR/application_test.seed.exs"
            local DASHBOARD_SEED_FILE="$CTRL_SEED_DIR/dashboard_controller_test.seed.exs"
            local MAILBOX_SEED_FILE="$CTRL_SEED_DIR/mailbox_controller_test.seed.exs"
            local PAGE_SEED_FILE="$CTRL_SEED_DIR/page_controller_test.seed.exs"
            local TELEMETRY_SEED_FILE="$WEB_SEED_DIR/telemetry_test.seed.exs"
            local ERROR_SEED_FILE="$CTRL_SEED_DIR/error_json_test.seed.exs"
            local FIXTURES_SEED_FILE="$SUPPORT_SEED_DIR/fixtures.seed.ex"
            local MOCK_SEED_FILE="$SUPPORT_SEED_DIR/mock_helper.seed.ex"

            local APPLICATION_FILE="$APP_TEST_DIR/application_test.exs"
            local DASHBOARD_FILE="$CTRL_TEST_DIR/dashboard_controller_test.exs"
            local MAILBOX_FILE="$CTRL_TEST_DIR/mailbox_controller_test.exs"
            local PAGE_FILE="$CTRL_TEST_DIR/page_controller_test.exs"
            local TELEMETRY_FILE="$WEB_TEST_DIR/telemetry_test.exs"
            local FIXTURES_FILE="$SUPPORT_DIR/fixtures.ex"
            local ERROR_FILE="$CTRL_TEST_DIR/error_json_test.exs"
            local MOCK_FILE="$SUPPORT_DIR/mock_helper.ex"
            local CONN_CASE_FILE="$SUPPORT_DIR/conn_case.ex"

            # Plant application_test.exs file
            cp \
              "$WORKBENCH_DIR/$SEEDS_DIR/$APPLICATION_SEED_FILE" \
              $APPLICATION_FILE
            sed -i "s/%{elixir_module}/$ELIXIR_MODULE/" $APPLICATION_FILE
            [ "$ECTO" == true ] && \
            pattern keep $HELPER_FILE "ecto" || \
            pattern delete $HELPER_FILE "ecto"
            # Plant dashboard_test.exs file
            if [ "$DASHBOARD" == true ]; then
              cp \
                "$WORKBENCH_DIR/$SEEDS_DIR/$DASHBOARD_SEED_FILE" \
                $DASHBOARD_FILE
              sed -i "s/%{elixir_module}/$ELIXIR_MODULE/" $DASHBOARD_FILE
            fi
            # Plant mailbox_test.exs file
            if [ "$MAILER" == true ]; then
              cp "$WORKBENCH_DIR/$SEEDS_DIR/$MAILBOX_SEED_FILE" $MAILBOX_FILE
              sed -i "s/%{elixir_module}/$ELIXIR_MODULE/" $MAILBOX_FILE
            fi
            # Plant page_test.exs file
            [ "$NO_HTML" == false ] && \
            cp "$WORKBENCH_DIR/$SEEDS_DIR/$PAGE_SEED_FILE" $PAGE_FILE && \
            sed -i "s/%{elixir_module}/$ELIXIR_MODULE/" $PAGE_FILE
            # Plant telemetry_test.exs file
            cp "$WORKBENCH_DIR/$SEEDS_DIR/$TELEMETRY_SEED_FILE" $TELEMETRY_FILE
            sed -i "s/%{elixir_module}/$ELIXIR_MODULE/" $TELEMETRY_FILE
            # Plant fixtures.ex file
            cp "$WORKBENCH_DIR/$SEEDS_DIR/$FIXTURES_SEED_FILE" $FIXTURES_FILE
            sed -i "s/%{elixir_module}/$ELIXIR_MODULE/" $FIXTURES_FILE
            sed -i "s/%{elixir_project_name}/$ELIXIR_PROJECT_NAME/" $FIXTURES_FILE
            if [ "$AUTH0" == true ]; then
              pattern keep $FIXTURES_FILE "auth0" && \
              pattern delete $FIXTURES_FILE "no-auth0"
            else
              pattern keep $FIXTURES_FILE "no-auth0" && \
              pattern delete $FIXTURES_FILE "auth0"
            fi
            [ "$OPENAI" == true ] && \
            pattern keep $FIXTURES_FILE "openai" || \
            pattern delete $FIXTURES_FILE "openai"
            [ "$ECTO" == true ] && \
            pattern keep $FIXTURES_FILE "ecto" || \
            pattern delete $FIXTURES_FILE "ecto"
            # Plant mock_helper.ex file
            cp "$WORKBENCH_DIR/$SEEDS_DIR/$MOCK_SEED_FILE" $MOCK_FILE
            sed -i "s/%{elixir_module}/$ELIXIR_MODULE/" $MOCK_FILE
            [ "$AUTH0" == true ] && \
            pattern keep $MOCK_FILE "auth0" || \
            pattern delete $MOCK_FILE "auth0"
            [ "$OPENAI" == true ] && \
            pattern keep $MOCK_FILE "openai" || \
            pattern delete $MOCK_FILE "openai"
            # Plant error_json_test.exs file
            cp "$WORKBENCH_DIR/$SEEDS_DIR/$ERROR_SEED_FILE" $ERROR_FILE
            sed -i "s/%{elixir_module}/$ELIXIR_MODULE/" $ERROR_FILE
            # Adjust conn_case.ex
            # sed -i '30d' $CONN_CASE_FILE
            sed -i "31i\      import $ELIXIR_MODULE.MockHelper" $CONN_CASE_FILE
          }
          
        # SCRIPT -------------------------------------------------------------

        feature_init $FEATURE

        mix_append deps "," && \
        mix_insert deps \
          "" \
          "# Enhancements implementation deps set" && \
        \
        implement_osmon && \
        implement_psql_extras && \
        # implement_flameon && \
        implement_credo && \
        implement_mock && \
        implement_exdebug && \
        if [ "$ECTO" == true ]; then
          implement_helper && \
          implement_ecto_schema && \
          implement_html_entities && \
          implement_db_task && \
          implement_db_schema_diagrams
        fi && \
        if [ "$INTERFACE" == "rest" ]; then
          implement_changeset_error_view && \
          implemenet_postman_collection
        fi && \
        implement_version_task && \
        implement_unit_testing
        # implement_exmachina && \
        # implement_githooks && \
      }

      # implement_rest
        #
      implement_rest() {
        # CONFIGURATION --------------------------------------------------------
          local FEATURE="OpenAPI"

          local OPEN_API_ENDPOINT="openapi"
          local SWAGGER_ENDPOINT="swagger"
          local SCHEMAS_SEED_FILE="rest/schemas.seed.ex"
          local SPEC_SEED_FILE="rest/spec.seed.ex"
          local REQUESTS_SEED_FILE="rest/requests.seed.ex"
          local RESPONSES_SEED_FILE="rest/responses.seed.ex"
          local SCHEMAS_FILE="$OPEN_API_DIR/schemas.ex"
          local SPEC_FILE="$OPEN_API_DIR/spec.ex"
          local REQUESTS_FILE="$OPEN_API_DIR/requests.ex"
          local RESPONSES_FILE="$OPEN_API_DIR/responses.ex"

        # FUNCTIONS ------------------------------------------------------------
          # unit_testing
            #
          unit_testing() {
            local OPEN_API_SEED_FILE="$CTRL_SEED_DIR/open_api_controller_test.seed.exs"
            local SWAGGER_SEED_FILE="$CTRL_SEED_DIR/swagger_controller_test.seed.exs"

            local OPEN_API_FILE="$CTRL_TEST_DIR/open_api_controller_test.exs"
            local SWAGGER_FILE="$CTRL_TEST_DIR/swagger_controller_test.exs"

            # Plant open_api_controller_test.exs file
            cp "$WORKBENCH_DIR/$SEEDS_DIR/$OPEN_API_SEED_FILE" $OPEN_API_FILE
            sed -i "s/%{elixir_module}/$ELIXIR_MODULE/" $OPEN_API_FILE
            # Plant swagger_controller_test.exs file
            cp "$WORKBENCH_DIR/$SEEDS_DIR/$SWAGGER_SEED_FILE" $SWAGGER_FILE
            sed -i "s/%{elixir_module}/$ELIXIR_MODULE/" $SWAGGER_FILE
          }

        # SCRIPT ---------------------------------------------------------------
        feature_init $FEATURE

        [ ! -d $OPEN_API_DIR ] && mkdir $OPEN_API_DIR

        # Adjust app_web.ex file
        sed -i "48i\\      alias OpenApiSpex.Schema" $WEB_MODULE_FILE
        sed -i \
          "48i\\      alias ${ELIXIR_MODULE}Web.OpenApi.{Requests, Responses, Schemas}" \
          $WEB_MODULE_FILE

        # Plant spec.ex file
        cp "$WORKBENCH_DIR/$SEEDS_DIR/$SPEC_SEED_FILE" $SPEC_FILE
        sed -i "s/%{elixir_module}/$ELIXIR_MODULE/" $SPEC_FILE
        sed -i "s/%{project_name}/$PROJECT_NAME/"   $SPEC_FILE
        
        [ "$AUTH0" == true ] && \
        pattern keep $SPEC_FILE "auth0" || \
        pattern delete $SPEC_FILE "auth0"

        [ "$OPENAI" == true ] && \
        pattern keep $SPEC_FILE "openai" || \
        pattern delete $SPEC_FILE "openai"

        [ "$HEALTH" == true ] && \
        pattern keep $SPEC_FILE "health" || \
        pattern delete $SPEC_FILE "health"

        [[ "$AUTH0" == false && \
        "$OPENAI" == false && \
        "$HEALTH" == false ]] && \
        pattern keep $SPEC_FILE "default" || \
        pattern delete $SPEC_FILE "default"

        # Plant requests.ex file
        cp "$WORKBENCH_DIR/$SEEDS_DIR/$REQUESTS_SEED_FILE" $REQUESTS_FILE
        sed -i "s/%{elixir_module}/$ELIXIR_MODULE/" $REQUESTS_FILE

        [ "$OPENAI" == true ] && \
        pattern keep $REQUESTS_FILE "openai" || \
        pattern delete $REQUESTS_FILE "openai"

        # Plant responses.ex file
        cp "$WORKBENCH_DIR/$SEEDS_DIR/$RESPONSES_SEED_FILE" $RESPONSES_FILE
        sed -i "s/%{elixir_module}/$ELIXIR_MODULE/" $RESPONSES_FILE

        [ "$OPENAI" == true ] && \
        pattern keep $RESPONSES_FILE "openai" || \
        pattern delete $RESPONSES_FILE "openai"

        # Plant schemas.ex file
        cp "$WORKBENCH_DIR/$SEEDS_DIR/$SCHEMAS_SEED_FILE" $SCHEMAS_FILE
        sed -i "s/%{elixir_module}/$ELIXIR_MODULE/" $SCHEMAS_FILE

        # Adjust mix.exs
        if [ ! -f $MIX_FILE ]; then
          terminate "The $MIX_FILE file does not exist."
        else
          mix_append deps ","
          mix_insert deps \
            "# OpenAPI documentation deps" \
            "{:open_api_spex, \"$OPEN_API_VERSION\"}"
        fi

        # Adjust router.ex
        if [ ! -f $ROUTER_FILE ]; then
          terminate "The $ROUTER_FILE file does not exist."
        else
          alias="  alias OpenApiSpex.Plug.{PutApiSpec, RenderSpec, SwaggerUI}"
          sed -i '4i\'"$alias"'\n' $ROUTER_FILE

          sed -i '/# Other scopes may use custom stacks\./,/# end/ {
              /^.*# Other .*/d
              s/^\(.*\)# scope \(.*\)/\1scope \2/
              s/^\(.*\)#   pipe_through \(.*\)/\1  pipe_through \2/
              s/^\(.*\)# end/\1end/
            }' \
            $ROUTER_FILE

          sed -i \
            "s/\(\(.*\)scope \"\/api\".*\)/\2# API REST endpoints scope\n\1/" \
            $ROUTER_FILE

          sed -i \
            "s/scope \"\/api\"\(.*\)/scope \"\/api\/v1\"\1/" \
            $ROUTER_FILE

          router_add_pipeline \
            "pipeline :open_api_spec do" \
            "  plug PutApiSpec, module: ${ELIXIR_MODULE}Web.OpenApi.Spec" \
            "end"

          if [[ $DASHBOARD == false && $MAILER == false ]]; then
            router_add_scope "\"\/api\/v1\", ${ELIXIR_MODULE}Web" ":api" 1 \
              "# Enable Swagger documentation in development" \
              "if Application.compile_env(:$ELIXIR_PROJECT_NAME, :dev_routes) do" \
              "  scope \"/dev\" do" \
              "    pipe_through [:fetch_session, :protect_from_forgery]" \
              "" \
              "    # SwaggerUI interface for REST-API documentation" \
              "    get \"/$SWAGGER_ENDPOINT\", SwaggerUI, path: \"/dev/$OPEN_API_ENDPOINT\"" \
              "  end" \
              "" \
              "  # OpenAPI schema (json file)" \
              "  scope \"/dev\" do" \
              "    pipe_through [:api, :open_api_spec]" \
              "" \
              "    get \"/$OPEN_API_ENDPOINT\", RenderSpec, []" \
              "  end" \
              "end"
          else
            router_add_scope "\"\/dev\"" "\(:browser\|\[:fetch.*\]\)" 2 \
              "# OpenAPI schema (json file)" \
              "scope \"/dev\" do" \
              "  pipe_through [:api, :open_api_spec]" \
              "" \
              "  get \"/$OPEN_API_ENDPOINT\", RenderSpec, []" \
              "end"

            sed_lines "swagger" 3 \
              "" \
              "# SwaggerUI interface for REST-API documentation" \
              "get \"/$SWAGGER_ENDPOINT\", SwaggerUI, path: \"/dev/$OPEN_API_ENDPOINT\""

            if [ $MAILER == true ]; then
              sed -i '/forward "\/mailbox", .*$/a\'"$swagger" $ROUTER_FILE
            elif [ $DASHBOARD == true ]; then
              sed -i '/live_dashboard .*$/a\'"$swagger" $ROUTER_FILE
            fi
          fi
        fi

        # Plant unit testing files
        unit_testing
      }

      # implement_graphql
        #
      implement_graphql() {
        # CONFIGURATION --------------------------------------------------------
          local FEATURE="API GraphQL"

        # SCRIPT ---------------------------------------------------------------
          feature_init $FEATURE

          # TODO
          echo "---> Coming soon --> $FEATURE"

          # 1. create Web.Graphql files
            #      graphql
            #        resolvers
            #          ecto_schema.ex
            #        schemas
            #          ecto_schema.ex
            #        schema.ex
            # 2. adjust router
            # 3. add dependencies
            #      {:absinthe, "~> 1.7"},
            #      {:absinthe_plug, "~> 1.5"},
            #      {:absinthe_error_payload, "~> 1.1"},
      }

      # implement_exdoc
        #
      implement_exdoc() {
        # CONFIGURATION --------------------------------------------------------

          local FEATURE="ExDoc"
          # Estas variables está alojadas aqui para representar que solo son usadas
          # para implementar ex_doc y mantenerlo isolado, si otra implementación
          # usa alguna de estas variables se sacará al script principal.
          local script_name=$(basename "$0")

          local    EXDOC_ENDPOINT="docs"
          local      RESOURCE_DIR="doc"
          local  ARQUITECTURE_DIR="$WORKBENCH_DIR/$ASSETS_DIR/arq"
          local ASSETS_EXDOC_PATH="$WORKBENCH_DIR/$ELIXIR_EXDOC_ASSETS_PATH"
          local   ASSETS_IMG_PATH="$ASSETS_EXDOC_PATH/images"
          local    ASSETS_JS_PATH="$ASSETS_EXDOC_PATH/js"
          local     APP_LOGO_FILE="logo.png"
          local          ARQ_FILE="arq.svg"
          local   TOKEN_SEED_FILE="exdoc/token.seed.md"
          local TESTING_SEED_FILE="exdoc/testing.seed.md"
          local EXDOC_CONTROLLER_SEED_FILE="exdoc/exdoc_controller.seed.ex"

          local EXDOC_CONTROLLER_FILE="$CONTROLLERS_DIR/exdoc_controller.ex"
          local EXDOC_CONTORLLER_MODULE="ExDocController"

          local    EXDOC_ASSETS_IMG_PATH="$ELIXIR_EXDOC_ASSETS_PATH/images"
          local     EXDOC_ASSETS_JS_PATH="$ELIXIR_EXDOC_ASSETS_PATH/js"
          local EXDOC_ASSETS_CONFIG_PATH="$ELIXIR_EXDOC_ASSETS_PATH/config"
          local      EXDOC_APP_LOGO_FILE="$EXDOC_ASSETS_IMG_PATH/app-logo.png"
          local EXDOC_WORKBENCH_ARQ_FILE="$EXDOC_ASSETS_IMG_PATH/arq.svg"
          local     EXDOC_WORKBENCH_FILE="$ELIXIR_EXDOC_ASSETS_PATH/workbench.md"
          local         EXDOC_TOKEN_FILE="$ELIXIR_EXDOC_ASSETS_PATH/token.md"
          local            EXDOC_DB_FILE="$ELIXIR_EXDOC_ASSETS_PATH/database.md"
          local     EXDOC_GUIDELINE_FILE="$ELIXIR_EXDOC_ASSETS_PATH/coding.md"
          local       EXDOC_TESTING_FILE="$ELIXIR_EXDOC_ASSETS_PATH/$EXDOC_TEST_FILE"

          local MOD=$ELIXIR_MODULE
          local     REGEX_CONTEXT="~r/^${MOD}\\\.(?!(.*\\\..*|Mailer|Repo|Helper|Release|.*Ecto.*)$).*$/"
          local     REGEX_SCHEMAS="~r/^${MOD}\\\..*\\\.(?!.*(Enum)$).*$/"
          local       REGEX_TYPES="~r/^${MOD}\\\..*(Enum|EctoURI)$/"
          local         REGEX_WEB="~r/^${MOD}Web(?!(.Plug..*|.*(Controller|HTML|JSON))$)/"
          local       REGEX_PLUGS="~r/^${MOD}Web.Plug..*$/"
          local REGEX_CONTROLLERS="~r/^${MOD}Web.*(Controller)$/"
          local       REGEX_VIEWS="~r/^${MOD}Web.*(HTML|JSON)$/"

        # FUNCTIONS ------------------------------------------------------------
          # unit_testing
            #
          unit_testing() {
            local EXDOC_SEED_FILE="$CTRL_SEED_DIR/exdoc_controller_test.seed.exs"
            local EXDOC_FILE="$CTRL_TEST_DIR/exdoc_controller_test.exs"

            # Plant exdoc_controller_test.exs file
            cp "$WORKBENCH_DIR/$SEEDS_DIR/$EXDOC_SEED_FILE" $EXDOC_FILE
            sed -i "s/%{elixir_module}/$ELIXIR_MODULE/" $EXDOC_FILE
            sed -i "s/%{project_name}/$PROJECT_NAME/" $EXDOC_FILE

            # Create dummy exdoc compiled assets for the first time running  
            # coverage test reports, so the report can be generated with 100%  
            # success even if the mix db command hasn't been run previously.
            local COMPILED_DIR="_build/test/lib/$ELIXIR_PROJECT_NAME/priv/static/doc"
            local DUMMY_INDEX_FILE="index.html"
            local DUMMY_INDEX_CONTENT="<title>$PROJECT_NAME v$APP_VERSION"
                  DUMMY_INDEX_CONTENT+=" — Documentation</title>"
            local DUMMY_404_FILE="404.html"
            local DUMMY_404_CONTENT="<title>404 — $PROJECT_NAME"
                  DUMMY_404_CONTENT+=" v$APP_VERSION</title>"
            local DUMMY_COVER_FILE="excoveralls.html"
            local DUMMY_COVER_CONTENT="<title>Coverage</title>"

            mkdir -p "$COMPILED_DIR"
            echo "$DUMMY_INDEX_CONTENT" > "$COMPILED_DIR/$DUMMY_INDEX_FILE"
            echo "$DUMMY_404_CONTENT" > "$COMPILED_DIR/$DUMMY_404_FILE"
            echo "$DUMMY_COVER_CONTENT" > "$COMPILED_DIR/$DUMMY_COVER_FILE"
          }

        # SCRIPT ---------------------------------------------------------------

        feature_init $FEATURE

        # Plant ExDoc Controller
        cp \
          "$WORKBENCH_DIR/$SEEDS_DIR/$EXDOC_CONTROLLER_SEED_FILE" \
          $EXDOC_CONTROLLER_FILE
        
        sed -i "s/%{elixir_module}/$ELIXIR_MODULE/"      $EXDOC_CONTROLLER_FILE
        sed -i "s/%{resource_dir}/$RESOURCE_DIR/"        $EXDOC_CONTROLLER_FILE
        sed -i "s/%{project_name}/$ELIXIR_PROJECT_NAME/" $EXDOC_CONTROLLER_FILE

        [ $COVERALLS == true ] && \
        pattern keep $EXDOC_CONTROLLER_FILE "coveralls" || \
        pattern delete $EXDOC_CONTROLLER_FILE "coveralls"

        # Create ExDoc assets directory
        [ ! -d $ELIXIR_ASSETS_PATH ] && mkdir $ELIXIR_ASSETS_PATH
        [ ! -d $ELIXIR_EXDOC_ASSETS_PATH ] && mkdir $ELIXIR_EXDOC_ASSETS_PATH

        # Create image asset files
        [ ! -d $EXDOC_ASSETS_IMG_PATH ] && mkdir $EXDOC_ASSETS_IMG_PATH
        cp "$ASSETS_IMG_PATH/$APP_LOGO_FILE" $EXDOC_APP_LOGO_FILE

        # DbSchema asset files
        if [ "$AUTH0" == true ]; then
          if   [[ "$OPENAI" == true  && "$STRIPE" == true ]]; then
            local ARQ="auth0_openai_stripe"
          elif [[ "$OPENAI" == true  && "$STRIPE" == false ]]; then
            local ARQ="auth0_openai"
          elif [[ "$OPENAI" == false && "$STRIPE" == true ]]; then
            local ARQ="auth0_stripe"
          elif [[ "$OPENAI" == false && "$STRIPE" == false ]]; then
            local ARQ="auth0"
          fi
        else
          if [ "$ECTO" == true ]
          then local ARQ="db"
          else local ARQ="none"
          fi
        fi

        cp "$ARQUITECTURE_DIR/$ARQ.svg" $EXDOC_WORKBENCH_ARQ_FILE
        
        # Create js asset files
        [ ! -d $EXDOC_ASSETS_JS_PATH ] && mkdir $EXDOC_ASSETS_JS_PATH
        cp -r $ASSETS_JS_PATH $ELIXIR_EXDOC_ASSETS_PATH

        # Set the docs_config.js file
        [ ! -d $EXDOC_ASSETS_CONFIG_PATH ] && mkdir $EXDOC_ASSETS_CONFIG_PATH
        mv \
          "$EXDOC_ASSETS_JS_PATH/docs_config.js" \
          "$EXDOC_ASSETS_CONFIG_PATH/docs_config.js"

        # Set workbench page
        cp "$WORKBENCH_DIR/$WORKBENCH_README_FILE" $EXDOC_WORKBENCH_FILE
        # Adjust workbench.md new command routes
        sed -i \
          "s|\`./$script_name\`|\`./$WORKBENCH_DIR/$script_name\`|g" \
          $EXDOC_WORKBENCH_FILE
        sed -i \
          "s|\`./$SCRIPT_CONFIG_FILE\`|\`./$WORKBENCH_DIR/$SCRIPT_CONFIG_FILE\`|g" \
          $EXDOC_WORKBENCH_FILE
        sed -i \
          "s/sudo chmod +x app/cd $WORKBENCH_DIR\n    sudo chmod +x app/" \
          $EXDOC_WORKBENCH_FILE
        # sed -i "s|CONFIG.md|$WORKBENCH_DIR/config.html|g" $EXDOC_WORKBENCH_FILE
        sed -i "/^.*CONFIG.*$/d" $EXDOC_WORKBENCH_FILE

        # Remove workbench page arquitecture table rows
        [ "$AUTH0" != true ] && \
        sed -i "/|.*Auth0.*|/d" $EXDOC_WORKBENCH_FILE
        [ "$OPENAI" != true ] && \
        sed -i "/|.*Open AI.*|/d" $EXDOC_WORKBENCH_FILE
        [ "$STRIPE" != true ] && \
        sed -i "/|.*Stripe.*|/d" $EXDOC_WORKBENCH_FILE

        # If --no-ecto option was given to in the creation, remove this services
        if [ "$ECTO" != true ]; then
          sed -i "/|.*Postgres DB.*|/d" $EXDOC_WORKBENCH_FILE && \
          sed -i "/|.*pgAdmin.*|/d" $EXDOC_WORKBENCH_FILE
        fi

        # Download codeguide
        [ $CODING_GUIDELINES == true ] && \
        curl -o $EXDOC_GUIDELINE_FILE $CODING_GUIDELINES_URL

        # Plant testing page
        [ $COVERALLS == true ] && \
        cp "$WORKBENCH_DIR/$SEEDS_DIR/$TESTING_SEED_FILE" $EXDOC_TESTING_FILE

        # Plant token page
        [ "$AUTH0" == true ] && \
        cp "$WORKBENCH_DIR/$SEEDS_DIR/$TOKEN_SEED_FILE" $EXDOC_TOKEN_FILE

        # Configure documentation structure in mix.exs file
        if [ ! -f $MIX_FILE ]; then
          terminate "The $MIX_FILE file does not exist."
        else
          mix_append project ","
          mix_insert project \
            "" \
            "# ExDoc documentation parameters" \
            "name: \"$PROJECT_NAME\"," \
            "source_url: \"$REPO_URL\"," \
            "docs: [" \
            "  source_ref: \"main\"," \
            "  authors: [\"$REPO_OWNER\"]," \
            "  homepage_url: \"https://www.$APP_NAME.com\"," \
            "  logo: \"$EXDOC_APP_LOGO_FILE\"," \
            "  output: \"priv/static/$RESOURCE_DIR\"," \
            "  main: \"readme\"," \
            "  assets: %{" \
            "    \"$EXDOC_ASSETS_CONFIG_PATH\" => \"/\","

          [ $COVERALLS == true ] && mix_insert project \
            "    \"$COVERALLS_OUTPUT_PATH\" => \"/\","
          
          mix_insert project \
            "    \"$EXDOC_ASSETS_IMG_PATH\" => \"/assets\"," \
            "    \"$EXDOC_ASSETS_JS_PATH\" => \"/assets\"" \
            "  }," \
            "  extras: [" \
            "    {\"$README_FILE\",                 [title: \"Overview\"]}," \
            "    {\"$CHANGELOG_FILE\",              [title: \"Changelog\"]},"

          [ $AUTH0 == true ] && mix_insert project \
            "    {\"$EXDOC_TOKEN_FILE\",     [title: \"Get access tokens\"]},"

          [ $ECTO == true ] && mix_insert project \
            "    {\"$EXDOC_DB_FILE\",  [title: \"Database\"]},"

          [ $COVERALLS == true ] && mix_insert project \
            "    {\"$EXDOC_TESTING_FILE\",   [title: \"Testing reports\"]},"

          [ $CODING_GUIDELINES == true ] && mix_insert project \
            "    {\"$EXDOC_GUIDELINE_FILE\",    [title: \"Coding guidelines\"]},"

          mix_insert project \
            "    {\"$EXDOC_WORKBENCH_FILE\", [title: \"Workbench\"]}" \
            "  ]," \
            "  groups_for_extras: [" \
            "    \"Project\": [" \
            "      \"$README_FILE\"," \
            "      \"$CHANGELOG_FILE\"" \
            "    ]," \
            "    \"Support\": ["

          [ $AUTH0 == true ] && mix_insert project \
            "      \"$EXDOC_TOKEN_FILE\","

          [ $COVERALLS == true ] && mix_insert project \
            "      \"$EXDOC_TESTING_FILE\","

          [ $ECTO == true ] && mix_insert project \
            "      \"$EXDOC_DB_FILE\","

          mix_insert project \
            "      \"$EXDOC_GUIDELINE_FILE\"," \
            "      \"$EXDOC_WORKBENCH_FILE\"" \
            "    ]" \
            "  ]," \
            "  groups_for_modules: [" \
            "    \"Contexts\": $REGEX_CONTEXT," \
            "    \"Schemas\":  $REGEX_SCHEMAS," \
            "    \"Types\":    $REGEX_TYPES,"

          [ "$INTERFACE" == "graphql" ] && [ $AUTH0 == true ] && \
          mix_insert project \
            "    \"Authentication\": [" \
            "      ${ELIXIR_MODULE}Web.Graphql.Context" \
            "    ],"

          mix_insert project \
            "    \"Web\":         $REGEX_WEB," \
            "    \"Plugs\":       $REGEX_PLUGS", \
            "    \"Controllers\": $REGEX_CONTROLLERS", \
            "    \"Views\":       $REGEX_VIEWS" \
            "  ]," \
            "  before_closing_head_tag: &before_closing_head_tag/1," \
            "  before_closing_body_tag: &before_closing_body_tag/1" \
            "]"

          lines "body" 1 \
            "<script src=\"./assets/themedImage.js\"></script>"

          lines "auth0_body" 2 \
            "<script src=\"$AUTH0_PROD_JS\"></script>" \
            "<script src=\"./assets/auth_config.js\"></script>" \
            "<script src=\"./assets/token.js\"></script>"

          html_body=$body
          [ $AUTH0 == true ] && html_body+="\n$auth0_body"

          mix_insert_after_function project \
            "" \
            "defp before_closing_head_tag(:epub), do: \"\"" \
            "defp before_closing_head_tag(:html), do: \"\"" \
            "" \
            "defp before_closing_body_tag(:epub), do: \"\"" \
            "defp before_closing_body_tag(:html) do" \
            "  \"\"\"" \
            "$html_body" \
            "  \"\"\"" \
            "end"

          mix_append deps ","
          mix_insert deps \
            "# ExDoc documentation deps" \
            "{:ex_doc, \"$EXDOC_VERSION\", only: :dev, runtime: false}"
        fi

        # Configure documentation endpoints
        if [ ! -f $ROUTER_FILE ]; then
          terminate "The $ROUTER_FILE file does not exist."
        else
          router_add_pipeline \
            "pipeline :exdoc do" \
            "  plug Plug.Static," \
            "    at: \"/dev/$EXDOC_ENDPOINT\"," \
            "    from: {:$ELIXIR_PROJECT_NAME, \"priv/static/$RESOURCE_DIR\"}," \
            "    cache_control_for_etags: \"public, max-age=86400\"," \
            "    gzip: true" \
            "end"

          router_add_scope "\"\/dev\"" "\(:browser\|\[:fetch.*\]\)" 2 \
            "# ExDoc documentation site" \
            "scope \"/dev\", ${ELIXIR_MODULE}Web do" \
            "  pipe_through :exdoc" \
            "" \
            "  get \"/$EXDOC_ENDPOINT/\",      ${EXDOC_CONTORLLER_MODULE}, :index" \
            "  get \"/$EXDOC_ENDPOINT/cover\", ${EXDOC_CONTORLLER_MODULE}, :cover" \
            "  get \"/$EXDOC_ENDPOINT/*path\", ${EXDOC_CONTORLLER_MODULE}, :handle" \
            "end"
        fi

        # Plant unit testing files
        unit_testing
      }

      # implement_coveralls
        #
      implement_coveralls() {
        # CONFIGURATION --------------------------------------------------------
          local FEATURE="Coveralls"

          local COVERALLS_DIR="coverage"
          local TEMPLATE_DIR="template"
          local COVER_TASK_SEED_FILE="coveralls/cover.seed.ex"
          local COVERALLS_SEED_FILE="coveralls/coveralls.seed.json"
          local ELIXIR_COVERALLS_FILE="coveralls.json"
          local COVERALLS_TEMPLATE_PATH="$COVERALLS_PATH/$TEMPLATE_DIR"
          local COVER_TASK_PATH="$MIX_TASK_PATH/cover.ex"

        # FUNCTIONS ------------------------------------------------------------
          # unit_testing
            #
          unit_testing() {
            local COVER_SEED_FILE="$MIX_SEED_DIR/tasks/cover_test.seed.exs"
            local COVER_FILE="$MIX_TEST_DIR/tasks/cover_test.exs"

            # Plant cover_test.exs file
            cp "$WORKBENCH_DIR/$SEEDS_DIR/$COVER_SEED_FILE" $COVER_FILE
            sed -i "s/%{elixir_module}/$ELIXIR_MODULE/" $COVER_FILE
          }

        # SCRIPT ---------------------------------------------------------------
        feature_init $FEATURE

        # Create directories
        [ ! -d $COVERALLS_PATH ]          && mkdir $COVERALLS_PATH
        [ ! -d $COVERALLS_OUTPUT_PATH ]   && mkdir $COVERALLS_OUTPUT_PATH
        [ ! -d $COVERALLS_TEMPLATE_PATH ] && mkdir $COVERALLS_TEMPLATE_PATH

        # Copy template files
        cp -r \
          "$WORKBENCH_DIR/$ASSETS_DIR/$COVERALLS_DIR/$TEMPLATE_DIR" \
          $COVERALLS_PATH

        # Plant: coveralls.seed.json
        cp \
          "$WORKBENCH_DIR/$SEEDS_DIR/$COVERALLS_SEED_FILE" \
          $ELIXIR_COVERALLS_FILE

        sed -i \
          "s/%{output_dir}/$(scape_for_sed $COVERALLS_OUTPUT_PATH)/" \
          $ELIXIR_COVERALLS_FILE

        sed -i \
          "s/%{template_path}/$(scape_for_sed $COVERALLS_TEMPLATE_PATH)/" \
          $ELIXIR_COVERALLS_FILE

        sed -i \
          "s/%{minimum_coverage}/$MINIMUM_COVERAGE/" \
          $ELIXIR_COVERALLS_FILE

        sed -i \
          "s/%{elixir_project_name}/$ELIXIR_PROJECT_NAME/" \
          $ELIXIR_COVERALLS_FILE

        [ "$INTERFACE" == "rest" ] && \
        pattern keep $ELIXIR_COVERALLS_FILE "rest" || \
        pattern delete $ELIXIR_COVERALLS_FILE "rest"

        [ "$NO_HTML" == false ] && \
        pattern keep $ELIXIR_COVERALLS_FILE "html" || \
        pattern delete $ELIXIR_COVERALLS_FILE "html"

        # Plant: cover.seed.ex
        if [ "$EXDOC" == true ]
        then
          create_mix_task_path_if_missing
        
          cp \
            "$WORKBENCH_DIR/$SEEDS_DIR/$COVER_TASK_SEED_FILE" \
            $COVER_TASK_PATH
          
          sed -i \
            "s/%{target_filename}/$EXDOC_TEST_FILE/" \
            $COVER_TASK_PATH

          sed -i \
            "s/%{coverage_config}/$ELIXIR_COVERALLS_FILE/" \
            $COVER_TASK_PATH
            
          sed -i \
            "s/%{exdoc_assets}/$(scape_for_sed $ELIXIR_EXDOC_ASSETS_PATH)/" \
            $COVER_TASK_PATH
        fi

        # mix.exs file configuration
        if [ ! -f $MIX_FILE ]
        then
          terminate "The $MIX_FILE file does not exist."
        else
          mix_append project ","
          mix_insert project \
            "" \
            "# Coverage configuration" \
            "test_coverage: [tool: ExCoveralls]"

          sed_lines "prefered_env" 3 \
            "preferred_envs: [" \
            "  precommit: :test," \
            "  cover: :test," \
            "  coveralls: :test," \
            "  \"coveralls.detail\": :test," \
            "  \"coveralls.post\": :test," \
            "  \"coveralls.html\": :test," \
            "  \"coveralls.cobertura\": :test" \
            "]"
          sed -i "s/^.*preferred_envs: \[precommit: :test\]/$prefered_env/" $MIX_FILE

          mix_append deps ","
          mix_insert deps \
            "# Coverage report deps" \
            "{:excoveralls, \"$COVERALLS_VERSION\", only: :test}"
        fi

        # Plant unit testing files
        unit_testing
      }

      # implement_healthcheck
        #
      implement_healthcheck() {
        # CONFIGURATION --------------------------------------------------------
          local FEATURE="Healthcheck"

          local HEALTH_ENDPOINT="health"
          local HEALTH_SCHEMA_SEED_FILE="health/rest/healthcheck.seed.ex"
          local CONTROLLER_SEED_FILE="health/rest/healthcheck_controller.seed.ex"
          local HEALTH_SCHEMA_FILE="$OPEN_API_SCHEMAS_DIR/user.ex"
          local CONTROLLER_FILE="$CONTROLLERS_DIR/healthcheck_controller.ex"

        # FUNCTIONS ------------------------------------------------------------
          # unit_testing
            #
          unit_testing() {

            local HEALTH_SEED_FILE="$CTRL_SEED_DIR/healthcheck_controller_test.seed.exs"
            local HEALTH_FILE="$CTRL_TEST_DIR/healthcheck_controller_test.exs"

            # Plant healthcheck_controller_test.exs file
            cp "$WORKBENCH_DIR/$SEEDS_DIR/$HEALTH_SEED_FILE" $HEALTH_FILE
            sed -i "s/%{elixir_module}/$ELIXIR_MODULE/" $HEALTH_FILE
            sed -i "s/%{elixir_project_name}/$ELIXIR_PROJECT_NAME/" $HEALTH_FILE
          }

        # SCRIPT ---------------------------------------------------------------
        feature_init $FEATURE

        if [ "$INTERFACE" == "rest" ]; then
          create_openapi_schema_path_if_missing

          # Plant healthcheck.ex Open API schema file
          cp \
            "$WORKBENCH_DIR/$SEEDS_DIR/$HEALTH_SCHEMA_SEED_FILE" \
            $HEALTH_SCHEMA_FILE
          sed -i "s/%{elixir_module}/$ELIXIR_MODULE/" $HEALTH_SCHEMA_FILE

          # Plant healthcheck_controller.ex file
          cp \
            "$WORKBENCH_DIR/$SEEDS_DIR/$CONTROLLER_SEED_FILE" \
            $CONTROLLER_FILE
          sed -i "s/%{elixir_module}/$ELIXIR_MODULE/" $CONTROLLER_FILE
          sed -i \
            "s/%{elixir_project_name}/$ELIXIR_PROJECT_NAME/" \
            $CONTROLLER_FILE
        fi       

        # Adjust router.ex
        if [ ! -f $ROUTER_FILE ]; then
          terminate "The $ROUTER_FILE file does not exist."
        else
          router_add_scope "\"\/api\/v1\", ${ELIXIR_MODULE}Web" ":api" 1 \
            "# Healthcheck endpoint" \
            "scope \"/$HEALTH_ENDPOINT\", ${ELIXIR_MODULE}Web do" \
            "  pipe_through :api" \
            "" \
            "  get \"/\", HealthcheckController, :health" \
            "end"
        fi

        # Plant unit testing files
        unit_testing
      }

      # implement_auth0
        #
      implement_auth0() {
        # CONFIGURATION ------------------------------------------------------
          local FEATURE="Auth0"

          local ECTO_URI_SEED_FILE="auth0/ecto_uri.seed.ex"
          local AUTH0_PLUG_SEED_FILE="auth0/token.seed.ex"
          local USER_SCHEMA_SEED_FILE="auth0/rest/user.seed.ex"
          local USER_VIEW_SEED_FILE="auth0/rest/user_json.seed.ex"
          local USER_CONTROLLER_SEED_FILE="auth0/rest/user_controller.seed.ex"
          local ECTO_URI_FILE="$PROJECT_DIR/ecto_uri.ex"
          local AUTH0_PLUG_FILE="$PLUGS_DIR/token.ex"
          local USER_SCHEMA_FILE="$OPEN_API_SCHEMAS_DIR/user.ex"
          local USER_VIEW_FILE="$CONTROLLERS_DIR/user_json.ex"
          local USER_CONTROLLER_FILE="$CONTROLLERS_DIR/user_controller.ex"

        # SCRIPT -------------------------------------------------------------
        feature_init $FEATURE

        # Plant ecto_uri.ex file
        cp "$WORKBENCH_DIR/$SEEDS_DIR/$ECTO_URI_SEED_FILE" $ECTO_URI_FILE
        sed -i "s/%{elixir_module}/$ELIXIR_MODULE/" $ECTO_URI_FILE

        # Plant token.ex file
        [ ! -d $PLUGS_DIR ] && mkdir $PLUGS_DIR
        cp "$WORKBENCH_DIR/$SEEDS_DIR/$AUTH0_PLUG_SEED_FILE" $AUTH0_PLUG_FILE
        sed -i "s/%{elixir_module}/$ELIXIR_MODULE/" $AUTH0_PLUG_FILE
        sed -i \
          "s/%{elixir_project_name}/$ELIXIR_PROJECT_NAME/" \
          $AUTH0_PLUG_FILE

        if   [ "$INTERFACE" == "rest" ]; then
          pattern keep   $AUTH0_PLUG_FILE "rest"
          pattern delete $AUTH0_PLUG_FILE "graphql"
        elif [ "$INTERFACE" == "graphql" ]; then
          pattern keep   $AUTH0_PLUG_FILE "graphql"
          pattern delete $AUTH0_PLUG_FILE "rest"
        fi

        if [ "$INTERFACE" == "rest" ]; then
          create_openapi_schema_path_if_missing

          # Plant user.ex Open API schema file
          cp "$WORKBENCH_DIR/$SEEDS_DIR/$USER_SCHEMA_SEED_FILE" $USER_SCHEMA_FILE
          sed -i "s/%{elixir_module}/$ELIXIR_MODULE/" $USER_SCHEMA_FILE
          sed -i "s/%{app_name}/$APP_NAME/" $USER_SCHEMA_FILE

          # Plant user_json.ex view file
          cp "$WORKBENCH_DIR/$SEEDS_DIR/$USER_VIEW_SEED_FILE" $USER_VIEW_FILE
          sed -i "s/%{elixir_module}/$ELIXIR_MODULE/" $USER_VIEW_FILE

          # Plant user_controller.ex controller file
          cp \
            "$WORKBENCH_DIR/$SEEDS_DIR/$USER_CONTROLLER_SEED_FILE" \
            $USER_CONTROLLER_FILE
          sed -i "s/%{elixir_module}/$ELIXIR_MODULE/" $USER_CONTROLLER_FILE
        fi

        # Adjust router.ex
        if [ ! -f $ROUTER_FILE ]; then
          terminate "The $ROUTER_FILE file does not exist."
        else          
          # Add router (Diferent for API and GrpahQL)
          sed -i \
            "4i\  alias Auth0Jwks.Plug.{GetUser, ValidateToken}" \
            $ROUTER_FILE

          sed -i "4i\  alias $ELIXIR_MODULE.Accounts" $ROUTER_FILE
          router_add_pipeline \
            "pipeline :auth do" \
            "  plug ValidateToken, no_halt: true" \
            "  plug GetUser, no_halt: true, user_from_claim: &Accounts.user_from_claim/2" \
            "  plug ${ELIXIR_MODULE}Web.Plugs.Token" \
            "end"

          router_change_scope_pipeline "/api/v1" "[:api, :auth]"

          if [ "$INTERFACE" == "rest" ]; then
            router_add_scope_line \
              "\"\/api\/v1\", ${ELIXIR_MODULE}Web" "\[:api, :auth\]" 2 \
              "" \
              "get \"\/user\", UserController, :get"
          fi
        fi

        # Add dependency to mix.exs file
        mix_append deps ","
        mix_insert deps \
          "# Auth0 API integration deps" \
          "{:auth0_jwks, \"$AUTH0_JWKS_VERSION\"}"

        # Adjust application.ex file
        # SMELL: Apuntar a la linea 18 es muy rígido y depende de la versión de Phoenix
        sed -i \
          "18s/$/,\n      # Start the process to request the JSON Web Key Set (with RS256 alg).\n      {Auth0Jwks.Strategy, first_fetch_sync: true}/" \
          $APPLICATION_FILE

        # Adjust config.ex
        prepend_config \
          "" \
          "# Configuration for Auth0 JWKs" \
          "config :auth0_jwks, json_library: Jason"
      }

      # implement_stripe
        #
      implement_stripe() {
        # CONFIGURATION --------------------------------------------------------
          local FEATURE="Stripe"

        # SCRIPT ---------------------------------------------------------------
        feature_init $FEATURE

        # TODO
        echo "  ---> Coming soon --> $FEATURE"
      }

      # implement_auth0
        #
      implement_openai() {
        # CONFIGURATION ------------------------------------------------------
          local FEATURE="OpenAI"

          local MESSAGE_SCHEMA_SEED_FILE="open_ai/rest/message.seed.ex"
          local CONVERSATION_SCHEMA_SEED_FILE="open_ai/rest/conversation.seed.ex"
          local CONVERSATION_VIEW_SEED_FILE="open_ai/rest/conversation_json.seed.ex"
          local CONVERSATION_CONTROLLER_SEED_FILE="open_ai/rest/conversation_controller.seed.ex"
          local MESSAGE_SCHEMA_FILE="$OPEN_API_SCHEMAS_DIR/message.ex"
          local CONVERSATION_SCHEMA_FILE="$OPEN_API_SCHEMAS_DIR/conversation.ex"
          local CONVERSATION_VIEW_FILE="$CONTROLLERS_DIR/conversation_json.ex"
          local CONVERSATION_CONTROLLER_FILE="$CONTROLLERS_DIR/conversation_controller.ex"

        # SCRIPT -------------------------------------------------------------
        feature_init $FEATURE

        if [ "$INTERFACE" == "rest" ]; then
          create_openapi_schema_path_if_missing

          # Plant message.ex Open API schema file
          cp \
            "$WORKBENCH_DIR/$SEEDS_DIR/$MESSAGE_SCHEMA_SEED_FILE" \
            $MESSAGE_SCHEMA_FILE
          sed -i "s/%{elixir_module}/$ELIXIR_MODULE/" $MESSAGE_SCHEMA_FILE

          # Plant conversation.ex Open API schema file
          cp \
            "$WORKBENCH_DIR/$SEEDS_DIR/$CONVERSATION_SCHEMA_SEED_FILE" \
            $CONVERSATION_SCHEMA_FILE
          sed -i "s/%{elixir_module}/$ELIXIR_MODULE/" $CONVERSATION_SCHEMA_FILE

          # Plant conversation_json.ex view file
          cp \
            "$WORKBENCH_DIR/$SEEDS_DIR/$CONVERSATION_VIEW_SEED_FILE" \
            $CONVERSATION_VIEW_FILE
          sed -i "s/%{elixir_module}/$ELIXIR_MODULE/" $CONVERSATION_VIEW_FILE

          # Plant conversation_controller.ex controller file
          cp \
            "$WORKBENCH_DIR/$SEEDS_DIR/$CONVERSATION_CONTROLLER_SEED_FILE" \
            $CONVERSATION_CONTROLLER_FILE
          sed -i \
            "s/%{elixir_module}/$ELIXIR_MODULE/" $CONVERSATION_CONTROLLER_FILE

          sed -i \
            "s/%{elixir_project_name}/$ELIXIR_PROJECT_NAME/" \
            $CONVERSATION_CONTROLLER_FILE
          
          # Add endpoints to router.ex
          router_add_scope_line \
            "\"\/api\/v1\", ${ELIXIR_MODULE}Web" "\[:api, :auth\]" 2 \
            "" \
            "get    \"\/conversation\",     ConversationController, :list_conversations" \
            "get    \"\/conversation\/:id\", ConversationController, :get_conversation" \
            "post   \"\/conversation\",     ConversationController, :create_conversation" \
            "post   \"\/conversation\/:id\", ConversationController, :continue_conversation" \
            "delete \"\/conversation\/:id\", ConversationController, :delete_conversation"

          router_change_scope_pipeline "/api/v1" "[:api, :auth]"
        fi
      }

    # SCRIPT -----------------------------------------------------------------

    if [ "$ENHANCE" == true ]; then implement_enhancements; fi && \
    if [[ "$INTERFACE" == "rest" || "$HEALTH" == true ]]; then
      implement_rest;
    fi && \
    if [ "$INTERFACE" == "graphql" ]; then implement_graphql;     fi && \
    if [ "$EXDOC" == true ];          then implement_exdoc;       fi && \
    if [ "$COVERALLS" == true ];      then implement_coveralls;   fi && \
    if [ "$HEALTH" == true ];         then implement_healthcheck; fi && \
    if [ "$AUTH0" == true ];          then implement_auth0;       fi && \
    if [ "$STRIPE" == true ];         then implement_stripe;      fi && \
    if [ "$OPENAI" == true ];         then implement_openai;      fi && \
    echo
  }

  # post_implementation
    #
  post_implementation() {
    # CONFIGURATION ----------------------------------------------------------
      local MIGRATIONS_DIR="priv/repo/migrations"
      local USER_SEED_FILE="auth0/user_changesets.seed.ex"
      local CONVERSATION_SEED_FILE="open_ai/conversation.seed.ex"
      local MESSAGE_SEED_FILE="open_ai/message.seed.ex"

      local OPENAI_MIG="open_ai/migrations"
      local CONVERSATION_MIG_SEED_FILE="$OPENAI_MIG/create_conversations.seed.exs"
      local MESSAGE_MIG_SEED_FILE="$OPENAI_MIG/create_messages.seed.exs"

    # FUNCTIONS --------------------------------------------------------------

      refinement_init() { echo "${C3}* refining ${R} $@"; }

      # Project refinement ---------------------------------------------------

      # refine_auth0
        #
      refine_auth0() {
        # CONFIGURATION ------------------------------------------------------
          local FEATURE="Auth0"
            
          local ACCOUNTS_FILE="$PROJECT_DIR/accounts.ex"
          local ACCOUNTS_SEED_FILE="auth0/accounts.seed.ex"

        # FUNCTIONS ------------------------------------------------------------
          # unit_testing
            #
          unit_testing() {
            local ACCOUNTS_SEED_FILE="$APP_SEED_DIR/accounts_test.seed.exs"
            local ECTO_URI_SEED_FILE="$APP_SEED_DIR/ecto_uri_test.seed.exs"
            local USER_SEED_FILE="$CTRL_SEED_DIR/user_controller_test.seed.exs"
            local TOKEN_SEED_FILE="$PLUGS_SEED_DIR/token_test.seed.exs"
            local FIXTURE_SEED_FILE="$FIXTURES_SEED_DIR/accounts_fixtures.seed.ex"

            local ACCOUNTS_FILE="$APP_TEST_DIR/accounts_test.exs"
            local ECTO_URI_FILE="$APP_TEST_DIR/ecto_uri_test.exs"
            local USER_FILE="$CTRL_TEST_DIR/user_controller_test.exs"
            local TOKEN_FILE="$PLUGS_TEST_DIR/token_test.exs"
            local FIXTURE_TEST_FILE="$FIXTURES_DIR/accounts_fixtures.ex"

            # Plant accounts_test.exs file
            cp "$WORKBENCH_DIR/$SEEDS_DIR/$ACCOUNTS_SEED_FILE" $ACCOUNTS_FILE
            sed -i "s/%{elixir_module}/$ELIXIR_MODULE/" $ACCOUNTS_FILE
            # Plant ecto_uri_test.exs file
            cp "$WORKBENCH_DIR/$SEEDS_DIR/$ECTO_URI_SEED_FILE" $ECTO_URI_FILE
            sed -i "s/%{elixir_module}/$ELIXIR_MODULE/" $ECTO_URI_FILE
            # Plant user_controller_test.exs file
            cp "$WORKBENCH_DIR/$SEEDS_DIR/$USER_SEED_FILE" $USER_FILE
            sed -i "s/%{elixir_module}/$ELIXIR_MODULE/" $USER_FILE
            # Plant token_test.exs file
            cp "$WORKBENCH_DIR/$SEEDS_DIR/$TOKEN_SEED_FILE" $TOKEN_FILE
            sed -i "s/%{elixir_module}/$ELIXIR_MODULE/" $TOKEN_FILE
            # Plant accounts_fixtures.exs file
            cp "$WORKBENCH_DIR/$SEEDS_DIR/$FIXTURE_SEED_FILE" $FIXTURE_TEST_FILE
            sed -i "s/%{elixir_module}/$ELIXIR_MODULE/" $FIXTURE_TEST_FILE
          }

        # SCRIPT -------------------------------------------------------------
        refinement_init $FEATURE

        # Adjust accounts.ex to add Accounts.user_from_claim/2 function
        sed -i "s/%{elixir_module}/$ELIXIR_MODULE/" $ACCOUNTS_FILE
        sed -i "7i\\\n  alias Auth0Jwks.Config" $ACCOUNTS_FILE
        sed -i '13,105d' $ACCOUNTS_FILE
        sed -i \
          "12r $WORKBENCH_DIR/$SEEDS_DIR/$ACCOUNTS_SEED_FILE" \
          $ACCOUNTS_FILE

        # user.ex file adjustments in Schema refining ⮧

        # Plant unit testing files
        unit_testing
      }

      # refine_openai
        #
      refine_openai() {
        # CONFIGURATION ------------------------------------------------------
          local FEATURE="OpenAI"
            
          local ASSISTANT_SEED_FILE="open_ai/assistant.seed.ex"
          local ASSISTANT_FILE="$PROJECT_DIR/assistant.ex"

        # FUNCTIONS ------------------------------------------------------------
          # unit_testing
            #
          unit_testing() {
            local ASSISTANT_SEED_FILE="$APP_SEED_DIR/assistant_test.seed.exs"
            local CONVERSATION_SEED_FILE="$CTRL_SEED_DIR/conversation_controller_test.seed.exs"
            local FIXTURE_SEED_FILE="$FIXTURES_SEED_DIR/assistant_fixtures.seed.ex"

            local ASSISTANT_FILE="$APP_TEST_DIR/assistant_test.exs"
            local CONVERSATION_FILE="$CTRL_TEST_DIR/conversation_controller_test.exs"
            local FIXTURE_TEST_FILE="$FIXTURES_DIR/assistant_fixtures.ex"

            # Plant assistant_test.exs file
            cp "$WORKBENCH_DIR/$SEEDS_DIR/$ASSISTANT_SEED_FILE" $ASSISTANT_FILE
            sed -i "s/%{elixir_module}/$ELIXIR_MODULE/" $ASSISTANT_FILE
            # Plant conversation_controller_test.exs file
            cp "$WORKBENCH_DIR/$SEEDS_DIR/$CONVERSATION_SEED_FILE" $CONVERSATION_FILE
            sed -i "s/%{elixir_module}/$ELIXIR_MODULE/" $CONVERSATION_FILE
            # Plant accounts_fixtures.exs file
            cp "$WORKBENCH_DIR/$SEEDS_DIR/$FIXTURE_SEED_FILE" $FIXTURE_TEST_FILE
            sed -i "s/%{elixir_module}/$ELIXIR_MODULE/" $FIXTURE_TEST_FILE
          }

        # SCRIPT -------------------------------------------------------------
        refinement_init $FEATURE

        # Plant assistant.ex file
        cp "$WORKBENCH_DIR/$SEEDS_DIR/$ASSISTANT_SEED_FILE" $ASSISTANT_FILE
        sed -i "s/%{elixir_module}/$ELIXIR_MODULE/" $ASSISTANT_FILE
        sed -i "s/%{project_name}/$PROJECT_NAME/"   $ASSISTANT_FILE
        [ "$AUTH0" == true ] && \
        pattern keep $ASSISTANT_FILE "auth0" || \
        pattern delete $ASSISTANT_FILE "auth0"

        # message.ex file adjustments in Schema refining ⮧
        # conversation.ex file adjustments in Schema refining ⮧

        # Plant unit testing files
        unit_testing
      }

      # Schema files refinement ----------------------------------------------

      # refine_schema_user FILE
        #
      refine_schema_user() {
        local FILE="$1"

        # User status Ecto.Enum type asignment
        local STATUS_VALUES=$(
          sed -n 's/    field :status, Ecto.Enum, values: \(.*\)/\1/p' $FILE
        )
        sed -i "7i\  defenum StatusEnum, :user_status, $STATUS_VALUES\n" $FILE
        sed -i "s/field :status, .*/field :status, StatusEnum/" $FILE

        # User picture EctoURI type asignment
        sed -i "s/field :picture, .*/field :picture, EctoURI/" $FILE

        # Reeplacement of changesets
        sed -i "20,28d" $FILE
        sed -i "19r $WORKBENCH_DIR/$SEEDS_DIR/$USER_SEED_FILE" $FILE
      }

      # refine_schema_conversation FILE
        #
      refine_schema_conversation() {
        local FILE="$1"

        # Plant conversation.ex into given file
        cp "$WORKBENCH_DIR/$SEEDS_DIR/$CONVERSATION_SEED_FILE" $FILE
        sed -i "s/%{elixir_module}/$ELIXIR_MODULE/" $FILE
        sed -i "s/%{elixir_project_name}/$ELIXIR_PROJECT_NAME/" $FILE
      }

      # refine_schema_message FILE
        #
      refine_schema_message() {
        local FILE="$1"

        # Plant message.ex into given file
        cp "$WORKBENCH_DIR/$SEEDS_DIR/$MESSAGE_SEED_FILE" $FILE
        sed -i "s/%{elixir_module}/$ELIXIR_MODULE/" $FILE
      }

      # Migration files refinement -------------------------------------------

      # refine_migration_user FILE
        #
      refine_migration_user() {
        local FILE="$1"

        sed -i "5i\  alias $ELIXIR_MODULE.Accounts.User.StatusEnum" $FILE
        sed -i "9i\    StatusEnum.create_type()\n" $FILE

        sed -i \
          's/:name, :string/:name,           :string, null: false/' \
          $FILE
        sed -i \
          's/:status, :string/:status,         StatusEnum.type(), null: false/' \
          $FILE
        sed -i \
          's/:email, :string/:email,          :string, null: false/' \
          $FILE
        sed -i \
          's/:phone_number, :string/:phone_number,   :string/' \
          $FILE
        sed -i \
          's/:token_sub, :string/:token_sub,      :string, null: false/' \
          $FILE
        sed -i \
          's/:picture, :string/:picture,        :string/' \
          $FILE


        sed -i '/^\s*add :email, :string$/s/$/, null: false/' $FILE
        sed -i '/^\s*add :name, :string$/s/$/, null: false/' $FILE
      }

      # refine_migration_conversation FILE
        #
      refine_migration_conversation() {
        local FILE="$1"

        # Plant create_conversation.ex into given file
        cp "$WORKBENCH_DIR/$SEEDS_DIR/$CONVERSATION_MIG_SEED_FILE" $FILE
        sed -i "s/%{elixir_module}/$ELIXIR_MODULE/" $FILE
      }

      # refine_migration_message FILE
        #
      refine_migration_message() {
        local FILE="$1"

        # Plant create_message.ex into given file
        cp "$WORKBENCH_DIR/$SEEDS_DIR/$MESSAGE_MIG_SEED_FILE" $FILE
        sed -i "s/%{elixir_module}/$ELIXIR_MODULE/" $FILE
      }

    # SCRIPT -----------------------------------------------------------------

    if [ "$AUTH0" == true ]; then refine_auth0; fi
    if [ "$OPENAI" == true ]; then refine_openai; fi

    # Schema refining
    if find "$PROJECT_DIR" -mindepth 1 -type d | read; then
      for DIR in $PROJECT_DIR/*/; do
        for FILE in $DIR*; do
          refinement_init "schema: $FILE"

          local BASE="${FILE##*/}"; BASE="${BASE%.ex}"
          local SCHEMA=$(
            echo "$BASE" | 
            sed -r 's/([a-z0-9])([A-Z])/\1 \2/g' | 
            sed 's/_/ /g' | 
            awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2))}1'
          )
          local CONTEXT=$(
            echo "$DIR" | 
            sed -r 's/([a-z0-9])([A-Z])/\1 \2/g' | 
            sed 's/_/ /g' | 
            awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2))}1'
          )
          
          sed -i "s/use Ecto.Schema/use $ELIXIR_MODULE.Schema/" $FILE
          sed -i "3d" $FILE
          sed -i \
            "2i\  @moduledoc \"\"\"\n  $SCHEMA from $CONTEXT context.\n  \"\"\"" \
            $FILE

          # Auth0 schema files adjustment
          if [ "$AUTH0" == true ]; then
            if [[ "$FILE" == *user.ex ]]; then refine_schema_user $FILE; fi
          fi
          # OpenAI schema files adjustment
          if [ "$OPENAI" == true ]; then
            if   [[ "$FILE" == *message.ex ]]; then refine_schema_message $FILE
            elif [[ "$FILE" == *conversation.ex ]]; then
              refine_schema_conversation $FILE
            fi
          fi
        done
      done
    fi

    # Migration refining
    if [ -d $MIGRATIONS_DIR ]; then
      for FILE in $MIGRATIONS_DIR/*; do
        if [[ -f "$FILE" && "$(basename "$FILE")" != ".formatter.exs" ]]
        then
          refinement_init "migration: $FILE"
          local TABLE_NAME=$(
            sed -n 's/    create table(:\([^)]*\)) do/\1/p' $FILE
          )
          sed -i "s/:$TABLE_NAME/@table/g" $FILE
          sed -i "3i\  @table :$TABLE_NAME" $FILE
          sed -i "2i\  @moduledoc false\n" $FILE
          sed -i "s/timestamps()/timestamps(default: fragment(\"NOW()\"))/g" $FILE

          # Auth0 migration files adjustment
          if [ "$AUTH0" == true ]; then
            if [[ "$FILE" == *create_users.exs ]]; then
              refine_migration_user $FILE
            fi
          fi
          # OpenAI migration files adjustment
          if [ "$OPENAI" == true ]; then
            if   [[ "$FILE" == *create_messages.exs ]]; then
              refine_migration_message $FILE
            elif [[ "$FILE" == *create_conversations.exs ]]; then
              refine_migration_conversation $FILE
            fi
          fi
        fi
      done
    else true; fi
  }

  # remove_workbench
    #
  remove_workbench() {
    # TODO
    echo "  ---> Coming soon --> Remove script"
  }

# SCRIPT =======================================================================

update_version

if [ $# -gt 0 ]; then
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

      # ERROR:
      # retrieving credentials from store: error getting credentials -
      #   err: exit status 1,
      #   out: `exit status 2: gpg: decryption failed: No secret key`
      #
      # SOLUTION:
      # rm -rf ~/.password-store/docker-credential-helpers 
      # gpg --generate-key
      # pass init <your_generated_gpg-id_public_key>
    fi

  elif [ "$1" == "new" ]; then
    ENTRYPOINT_COMMAND=$1; shift

    # cd ..
    prepare_new_project && \
    cd "$WORKBENCH_DIR/$SCRIPTS_DIR" && \
    docker build --file $DEV_DOCKERFILE --tag $DEV_IMAGE . && \
    docker run \
      --tty \
      --interactive \
      --name "${APP_NAME}___${ENTRYPOINT_COMMAND}" \
      --rm \
      --volume $SOURCE_CODE_VOLUME \
      $DEV_IMAGE $CONTAINER_ENTRYPOINT new \
      $ELIXIR_PROJECT_NAME $@ && \
    cd ../.. && \
    configure_files $@ && \
    implement_features && \
    cd $WORKBENCH_DIR && \
    ENTRYPOINT_COMMAND="implementation_tasks" && \
    export COMPOSE_DOCKERFILE=$DEV_DOCKERFILE && \
    export COMPOSE_IMAGE=$DEV_IMAGE && \
    docker compose --file "$SCRIPTS_DIR/$COMPOSE_FILE" run \
      --rm \
      --name "${APP_NAME}___${ENTRYPOINT_COMMAND}" \
      --publish $APP_PORT:$APP_INTERNAL_PORT \
      app $CONTAINER_ENTRYPOINT $ENTRYPOINT_COMMAND \
        $AUTH0 $AUTH0_CONTEXT_FILE \
        $OPENAI $OPENAI_CONTEXT_FILE \
        $CUSTOM_SCHEMAS $CUSTOM_SCHEMAS_CONTEXT_FILE && \
    cd .. && \
    post_implementation && \
    if [ $EXDOC == true ]; then
      cd $WORKBENCH_DIR && \
      ENTRYPOINT_COMMAND="documentation" && \
      docker compose --file "$SCRIPTS_DIR/$COMPOSE_FILE" run \
        --rm \
        --name "${APP_NAME}___${ENTRYPOINT_COMMAND}" \
        --publish $APP_PORT:$APP_INTERNAL_PORT \
        app $CONTAINER_ENTRYPOINT $ENTRYPOINT_COMMAND \
          $EXDOC \
          $ECTO \
          $COVERALLS && \
      cd ..
    fi

    if [ $EXISTING_PROJECT != true ]; then
      echo \
        "For further workbench script use, remember to navigate to the" \
        "script directory:\n\n" \
        "   $ cd $WORKBENCH_DIR\n"
    fi
    
    # ERROR: Tarball error will occur on Win11 using a XFAT drive for the repo
    # on 'mix deps.get' run.
  elif [ "$1" == "setup" ]; then
    ENTRYPOINT_COMMAND=$1; shift

    if [ $EXISTING_PROJECT == true ]; then
      [ $# -gt 1 ] && [ "$1" == "--env" ] || [ "$1" == "-e" ] && \
        ENV_ARG="$2" || \
        ENV_ARG=dev
      
      export COMPOSE_DOCKERFILE=$DEV_DOCKERFILE
      export COMPOSE_IMAGE=$DEV_IMAGE
      docker compose --file "$SCRIPTS_DIR/$COMPOSE_FILE" run \
        --rm \
        --name "${APP_NAME}___${ENTRYPOINT_COMMAND}" \
        --publish $APP_PORT:$APP_INTERNAL_PORT \
        app $CONTAINER_ENTRYPOINT $ENTRYPOINT_COMMAND $ENV_ARG

    else terminate "There is no project to setup."; fi
      
  elif [ "$1" == "up" ]; then
    COMPOSE_COMMAND=$1; shift
    if [ $EXISTING_PROJECT == true ]; then
      [ $# -gt 1 ] && [ "$1" == "--env" ] || [ "$1" == "-e" ] && \
        ENV_ARG="$2" || \
        ENV_ARG=dev

      if [ "$ENV_ARG" == "prod" ]; then
        export COMPOSE_DOCKERFILE=$PROD_DOCKERFILE
        export COMPOSE_IMAGE=$PROD_IMAGE
        cd .. && \
        create_docker_compose_file && \
        docker compose $COMPOSE_COMMAND --build

      else
        export COMPOSE_DOCKERFILE=$DEV_DOCKERFILE
        export COMPOSE_IMAGE=$DEV_IMAGE
        docker compose \
          --file "$SCRIPTS_DIR/$COMPOSE_FILE" $COMPOSE_COMMAND
      fi

    else terminate "There is no project to deploy."; fi

  elif [ "$1" == "run" ]; then
    ENTRYPOINT_COMMAND=$1; shift
    if [ $EXISTING_PROJECT == true ]; then
      if [ $# -gt 0 ]; then
        export COMPOSE_DOCKERFILE=$DEV_DOCKERFILE
        export COMPOSE_IMAGE=$DEV_IMAGE
        docker compose --file "$SCRIPTS_DIR/$COMPOSE_FILE" run \
          --rm \
          --name "${APP_NAME}___${ENTRYPOINT_COMMAND}" \
          --publish $APP_PORT:$APP_INTERNAL_PORT \
          app $CONTAINER_ENTRYPOINT $ENTRYPOINT_COMMAND $@

      else args_error "Missing command for container initialization."; fi
    else terminate "There is no project to deploy."; fi

  elif [ "$1" == "delete" ]; then
    COMPOSE_COMMAND="down"
    if [ $EXISTING_PROJECT == true ]; then
      delete_project && \
      docker compose \
        $COMPOSE_COMMAND \
        --volumes \
        --rmi local \
        --remove-orphans

    else terminate "There is no project to delete."; fi
      
  elif [ "$1" == "demo" ]; then
    WORKBENCH_SCRIPT="./$0"; shift;

    [ $EXISTING_PROJECT == true ] && WORKBENCH_DIR="."
    [ $# -gt 1 ] && [ "$1" == "--env" ] || [ "$1" == "-e" ] && \
      ENV_ARG="$2" || \
      ENV_ARG=dev
    
    eval \
      "$WORKBENCH_SCRIPT new && " \
      "cd $WORKBENCH_DIR && " \
      "$WORKBENCH_SCRIPT setup --env $ENV_ARG && " \
      "$WORKBENCH_SCRIPT up --env $ENV_ARG &&" \
      "$WORKBENCH_SCRIPT delete"

  elif [ "$1" == "prune" ]; then
    CONTAINERS_TO_STOP="$(docker container ls -q)"

    if [ ! -z "$CONTAINERS_TO_STOP" ]; then
      echo "Stopping all containers...\n"
      docker stop $CONTAINERS_TO_STOP && \
      echo "\nAll containers are Stopped.\n"
    fi && \
    docker system prune -a --volumes

  elif [ "$1" == "remove-workbench" ]; then
    remove_workbench
  elif [ "$1" == "help" ]; then
    help
  else args_error invalid; fi
else help; fi
