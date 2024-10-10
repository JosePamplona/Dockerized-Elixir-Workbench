#!/bin/bash
# Dockerized workbench script
# v0.1.0

# CONFIGURATION ----------------------------------------------------------------

  source ./config.conf

  # Workbench configuration --------------------------------------------------
    
    export WORKBENCH_DIR="_workbench"
    export LOWER_CASE=$( echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' )
    export EXISTING_PROJECT=$(
      [ $(basename $PWD) == $WORKBENCH_DIR ] && echo true || echo false
    )
    export SOURCE_CODE_PATH=$(
      [ "$EXISTING_PROJECT" == true ] && echo $(dirname $PWD) || echo $PWD
    )
    export             APP_NAME=$( echo "$LOWER_CASE" | tr ' ' '-' )
    export  ELIXIR_PROJECT_NAME=$( echo "$LOWER_CASE" | tr ' ' '_' )
    export COMPOSE_PROJECT_NAME=$APP_NAME
    export   SOURCE_CODE_VOLUME="$SOURCE_CODE_PATH:/app/src"

    export          SCRIPTS_DIR="scripts"
    export      ENTRYPOINT_FILE="entrypoint.sh"
    export         SCHEMAS_FILE="schemas.sh"
    export       DEV_DOCKERFILE="Dockerfile.dev"
    export      PROD_DOCKERFILE="Dockerfile"
    export         COMPOSE_FILE="docker-compose.yml"
    export CONTAINER_ENTRYPOINT="bash entrypoint.sh"
    export   COMPOSE_DOCKERFILE=$PROD_DOCKERFILE

    export            SEEDS_DIR="seeds"
    export             ENV_SEED="seed.env"
    export          README_SEED="README.seed.md"
    export       CHANGELOG_SEED="CHANGELOG.seed.md"
    export  DEV_DOCKERFILE_SEED="Dockerfile.seed.dev"
    export PROD_DOCKERFILE_SEED="Dockerfile.seed.prod"
    export PGADMIN_SERVERS_SEED="servers.seed.json"
    export    PGADMIN_PASS_SEED="pgpass.seed"
    export  TOOLS_VERSIONS_SEED="seed.tool-versions"

  # Elixir project configuration ---------------------------------------------
    export   APP_INTERNAL_PORT="4000"
    export            ENV_FILE=".env"
    export            MIX_FILE="mix.exs"
    export         CONFIG_FILE="config/config.exs"
    export            DEV_FILE="config/dev.exs"
    export         README_FILE="README.md"
    export      CHANGELOG_FILE="CHANGELOG.md"
    export     PROD_DOCKERFILE="Dockerfile"
    export      GITIGNORE_FILE=".gitignore"
    export TOOLS_VERSIONS_FILE=".tool-versions"
    export      FORMATTER_FILE=".formatter.exs"
    export            ENV_PATH="$SOURCE_CODE_PATH/$ENV_FILE"

  # Database configuration ---------------------------------------------------
    export DB_INTERNAL_PORT="5432"
    export          DB_USER="postgres"
    export          DB_PASS="postgres"
    export          DB_HOST="database_host"
    export          DB_NAME="${ELIXIR_PROJECT_NAME}_prod"

  # PGAdmin configuration ----------------------------------------------------
    export PGADMIN_INTERNAL_PORT="5050"
    export         PGADMIN_EMAIL="pgadmin4@pgadmin.org"
    export      PGADMIN_PASSWORD="pass"
    export           PGADMIN_DIR="pgadmin"
    export          SERVERS_FILE="servers.json"
    export             PASS_FILE="pgpass"
    export          PGADMIN_PATH="$SOURCE_CODE_PATH/$WORKBENCH_DIR/$PGADMIN_DIR"
    export  PGADMIN_SERVERS_PATH="$PGADMIN_PATH/$SERVERS_FILE"
    export     PGADMIN_PASS_PATH="$PGADMIN_PATH/$PASS_FILE"

  # Console text format codes ------------------------------------------------
    #      Dark-red
    export C1="\x1B[38;5;1m"
    #      Bold        Reset
    export B="\x1B[1m" R="\x1B[0m"

# FUNCTIONS --------------------------------------------------------------------

  # If echo handles -e option, overrides the command
  if [ "$(echo -e)" == "" ]; then echo() { command echo -e "$@"; } fi

  # readme
    # Prints readme file
  readme() {
    print_section() { echo "${B}$1${R}"; }    
    local script_name=$(basename "$0")

    print_section "NAME"
    echo "  $script_name - $(sed -n '2s/# //p' $0)"
    echo
    
    print_section "SYNOPSIS"
    echo "  $script_name [COMMAND] <argument>"
    echo
    
    print_section "DESCRIPTION"
    echo "  This script demonstrates an advanced help implementation."
    echo "  It supports multiple options and provides detailed help."
    echo

    print_section "VERSION"
    echo "  $(sed -n '3s/# //p' $0)"
    echo

    print_section "COMMANDS"
    echo "  ${B}new${R}                  Drops the database (if any), creates a new one and run a seeding script. (default: --prod)"
    echo "  ${B}setup${R}                Drops the database (if any), creates a new one and run a seeding script."
    echo "    --env <ENV>          Deploy the app with ENV enviroment configuration (Defalut: dev)."
    echo "  ${B}up${R}                   Deploy the app in localhost."
    echo "    --env <ENV>          Deploy the app with ENV enviroment configuration (Defalut: dev)."
    echo "  ${B}run <commands...>${R}    Deploy app executing custom entrypoint commands."
    echo "    commands...          Command(s) to be executed as app entrypoint. "
    echo "  ${B}login <user, token>${R}  Login to GitHub account."
    echo "    user                 Github username. "
    echo "    token                Authentication token (classic). "
    echo "  ${B}prune${R}                Stops all containers and prune Docker."
    echo
  }

  # confirm <MESSAGE>
    # Prints MESSAGE and spects input prompt for continue or exit the script 
  confirm() {
    echo "⚠️  ${B}Warning${R}: $@"
    read -n 1 -p $'Should continue? [y/N] ' INPUT
    if [ "$INPUT" != "y" ]; then exit 0; fi
    echo ""
  }
  
  # failure
    # Prints error and spects input prompt for continue or cancel
  failure() {
    echo "🛑  ${B}${C1}Failure${R}"
    read -n 1 -p $'Should continue? [y/N] ' INPUT
    if [ "$INPUT" != "y" ]; then exit 1; fi
    echo ""
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

  # scape_for_sed <STRING>
  scape_for_sed() { echo "$1" | sed 's/[\/&]/\\&/g'; }

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

        cp $seed_path $file_path
        sed -i "s/%{elixir_version}/$ELIXIR_VERSION/" $file_path
        sed -i "s/%{erlang_version}/$ERLANG_VERSION/" $file_path
        sed -i "s/%{debian_version}/$DEBIAN_VERSION/" $file_path
        sed -i "s/%{schemas}/$SCHEMAS_FILE/"          $file_path
        sed -i "s/%{entrypoint}/$ENTRYPOINT_FILE/"    $file_path
      }

    # SCRIPT -----------------------------------------------------------------

      if [ "$EXISTING_PROJECT" == true ]; then
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

  # configure_files
    # After project creation it configures some elixir files and add new ones.
  configure_files() {
    # FUNCTIONS --------------------------------------------------------------

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

      # create_pgpass
        # Create a pgpass file from seed for PGAdmin.
      create_pgpass() {
        local seed_path="$WORKBENCH_DIR/$SEEDS_DIR/$PGADMIN_PASS_SEED"
        local file_path="$WORKBENCH_DIR/$PGADMIN_DIR/$PASS_FILE"

        cp $seed_path $file_path
        sed -i "s/%{db_host}/$DB_HOST/" $file_path
        sed -i "s/%{db_port}/$DB_PORT/" $file_path
        sed -i "s/%{db_user}/$DB_USER/" $file_path
        sed -i "s/%{db_pass}/$DB_PASS/" $file_path
      }

      # create_servers_json
        # Create a servers.json file from seed for PGAdmin.
      create_servers_json() {
        local seed_path="$WORKBENCH_DIR/$SEEDS_DIR/$PGADMIN_SERVERS_SEED"
        local file_path="$WORKBENCH_DIR/$PGADMIN_DIR/$SERVERS_FILE"

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
          "s/version:\s*\"[0-9]*.[0-9]*.[0-9]*\"/version: \"0.0.0\"/" \
          $MIX_FILE
      }

      # adjust_config
        # Configures the timestamps and id types in config.exs file.
      adjust_config() {
        if [ ! -z "$TIMESTAMPS" ] || [ ! -z "$ID_TYPE" ]; then
          # Remove generators config
          sed -i "s/\(ecto_repos: \[.*.Repo\]\),/\1/" $CONFIG_FILE
          sed -i "/generators: \[timestamp_type: :utc_datetime\]/d" $CONFIG_FILE

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
          "s/hostname: \"localhost\"/hostname: \"$DB_HOST\"/" \
          $DEV_FILE && \
        sed -i \
          "s/http: \[ip: {127, 0, 0, 1}/http: \[ip: {0, 0, 0, 0}/" \
          $DEV_FILE
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
        if [ "$STRIPE" == true ]
        then pattern keep   $file_path "stripe"
        else pattern delete $file_path "stripe"
        fi
        sed -i "s/%{app_internal_port}/$APP_INTERNAL_PORT/" $file_path
        sed -i "s/%{secret_key_base}/$secret_key_base/" $file_path
        sed -i "s/%{database_url}/$db_url/" $file_path
        sed -i "s/%{app_name}/$APP_NAME/" $file_path
      }

      # adjust_gitignore
        # Prepends .tool-sersions and .env filess.
      adjust_gitignore() {
        sed -i "1i\\$TOOLS_VERSIONS_FILE\\n" $GITIGNORE_FILE && \
        sed -i \
          "1i\\# ASDF .tools-versions file." \
          $GITIGNORE_FILE && \
        sed -i "1i\\$ENV_FILE\\n" $GITIGNORE_FILE && \
        sed -i \
          "1i\\# Secrets required to configure the application." \
          $GITIGNORE_FILE
      }

      # create_changelog
        # Create a new CHANGELOG file from seed.
        # Set the v0.0.0 entry date to actual date.
      create_changelog() {
        local seed_path="$WORKBENCH_DIR/$SEEDS_DIR/$CHANGELOG_SEED"
        local file_path="$CHANGELOG_FILE"
        local today=$( date +%Y-%m-%d )

        cp $seed_path $file_path
        sed -i "s/%{creation_date}/$today/" $file_path
      }

      # create_readme
        # Create a new README file from seed.
        # Adjust project name into README.
        # According to the workbench/config.conf file it redact the README file.
      create_readme(){
        local seed_path="$WORKBENCH_DIR/$SEEDS_DIR/$README_SEED"
        local file_path="$README_FILE"
        local env_content=""
        while IFS= read -r line; do
            env_content+="    ${line}\n"
        done < "$ENV_FILE"

        cp $seed_path $file_path
        sed -i "s/%{project_name}/$PROJECT_NAME/" $file_path
        
        pattern \
          replace \
          $file_path \
          "env" \
          "    \`\`\`elixir\n$ENV_CONTENT\n    \`\`\`"
        
        if [ "$HEALTHCHECK" == true ]
        then pattern keep   $file_path "healthcheck"
        else pattern delete $file_path "healthcheck"
        fi

        if [ "$AUTH0" == true ]
        then pattern keep   $file_path "auth0"
        else pattern delete $file_path "auth0"
        fi

        if [ "$STRIPE" == true ]
        then pattern keep   $file_path "stripe"
        else pattern delete $file_path "stripe"
        fi

        if   [ "$API_INTERFACE" == "rest" ]; then
          pattern keep   $file_path "rest"
          pattern delete $file_path "graphql"

        elif [ "$API_INTERFACE" == "graphql" ]; then
          pattern keep   $file_path "graphql"
          pattern delete $file_path "rest"

        fi
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
      if [ -d "$WORKBENCH_DIR/$PGADMIN_DIR" ];
      then rm -rf "$WORKBENCH_DIR/$PGADMIN_DIR"
      fi && \
      mkdir "$WORKBENCH_DIR/$PGADMIN_DIR" && \
      create_pgpass && \
      create_servers_json && \
      adjust_mix && \
      adjust_config && \
      adjust_config_dev && \
      adjust_gitignore && \
      create_env && \
      create_changelog && \
      create_readme && \
      create_dockerfile_prod && \
      create_docker_compose_file && \
      create_tool_versions
  }

  # create_docker_compose_file
    # Create a docker-compose.yml file from script one.
  create_docker_compose_file() {
    local seed_path="$WORKBENCH_DIR/$SCRIPTS_DIR/$COMPOSE_FILE"
    local file_path="$COMPOSE_FILE"

    local        scp_env_path=$(scape_for_sed "$ENV_PATH")
    local        scp_src_path=$(scape_for_sed "$SOURCE_CODE_VOLUME")
    local    scp_servers_path=$(scape_for_sed "$PGADMIN_SERVERS_PATH")
    local       scp_pass_path=$(scape_for_sed "$PGADMIN_PASS_PATH")

    cp $seed_path $file_path
    sed -i "s/\$COMPOSE_DOCKERFILE/$COMPOSE_DOCKERFILE/"         $file_path
    sed -i "s/\$APP_NAME/$APP_NAME/"                             $file_path
    sed -i "s/\$APP_CONTAINER_NAME/$APP_CONTAINER_NAME/"         $file_path
    sed -i "s/\$APP_PORT/$APP_PORT/"                             $file_path
    sed -i "s/\$APP_INTERNAL_PORT/$APP_INTERNAL_PORT/"           $file_path
    sed -i "s/\$ENV_PATH/$scp_env_path/"                         $file_path
    sed -i "s/\$SOURCE_CODE_VOLUME/$scp_src_path/"               $file_path
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
  }

  implement_features() {
    # FUNCTIONS --------------------------------------------------------------

      # implement_healthcheck
        #
      implement_healthcheck(){
        echo "---------------------> implement_healthcheck"
      }

      # implement_auth0
        #
      implement_auth0(){
        echo "---------------------> implement_auth0"
      }

      # implement_stripe
        #
      implement_stripe(){
        echo "---------------------> implement_stripe"
      }

      # implement_graphql
        #
      implement_graphql(){
        echo "---------------------> implement_graphql"
      }

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

    # SCRIPT -----------------------------------------------------------------
      if [ "$HEALTHCHECK" == true ]; then implement_healthcheck; fi && \
      if [ "$AUTH0" == true ]; then implement_auth0; fi && \
      if [ "$STRIPE" == true ]; then implement_stripe; fi && \
      if [ "$API_INTERFACE" == "graphql" ]; then implement_graphql; fi
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
    rmdir $WORKBENCH_DIR
    rm -rf $PGADMIN_DIR
    rm "$SCRIPTS_DIR/$DEV_DOCKERFILE"
  }

# SCRIPT -----------------------------------------------------------------------

  if [ $# -gt 0 ]; then
    if   [ $1 == "login" ]; then
      shift && \
      if [ $# -eq 0 ]; then
        args_error \
          "Github user name is missing." \
          "Try add a user name as command argument."
      elif [ $# -eq 1 ]; then
        args_error \
          "Github personal access token (classic) is missing." \
          "Try add a token as command argument."
      else
        GITHUB_USER=$1 && \
        GITHUB_TOKEN=$2 && \
        REGISTRY_SERVER="ghcr.io" && \
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

    elif [ $1 == "new" ]; then
      # Tarball error will occur on Win11 using a XFAT drive for the repo on
      # mix deps.get

      ENTRYPOINT_COMMAND=$1 && \
      shift && \
      IMAGE="$APP_NAME:develop" && \
      prepare_new_project && \
      cd "$WORKBENCH_DIR/$SCRIPTS_DIR" && \
      docker build \
        --file "$DEV_DOCKERFILE" \
        --tag $IMAGE \
        . && \
      docker run \
        --rm \
        --tty \
        --interactive \
        --name "${APP_NAME}___${ENTRYPOINT_COMMAND}" \
        --volume $SOURCE_CODE_VOLUME \
        $IMAGE $CONTAINER_ENTRYPOINT \
        $ENTRYPOINT_COMMAND $ELIXIR_PROJECT_NAME $@ && \
      cd ../.. && \
      configure_files && \
      if [ "$RUN_SCHEMAS_SCRIPT" == true ]; then
        cd "$WORKBENCH_DIR/$SCRIPTS_DIR" && \
        docker run \
          --rm \
          --tty \
          --interactive \
          --name "${APP_NAME}___${ENTRYPOINT_COMMAND}" \
          --volume $SOURCE_CODE_VOLUME \
          $IMAGE $CONTAINER_ENTRYPOINT schemas && \
        cd ../..
      fi && \
      implement_features
             
    elif [ $1 == "setup" ]; then
      ENTRYPOINT_COMMAND=$1 && \
      shift && \
      [ $# -gt 1 ] && [ "$1" == "--env" ] && ENV_ARG="$2" || ENV_ARG=dev && \
      export COMPOSE_DOCKERFILE=$DEV_DOCKERFILE && \
      docker compose --file "$SCRIPTS_DIR/$COMPOSE_FILE" run \
        --build \
        --rm \
        --name "${APP_NAME}___${ENTRYPOINT_COMMAND}" \
        --publish $APP_PORT:$APP_INTERNAL_PORT \
        app $CONTAINER_ENTRYPOINT $ENTRYPOINT_COMMAND $ENV_ARG
        
    elif [ $1 == "up" ]; then
      shift && \
      [ $# -gt 1 ] && [ "$1" == "--env" ] && ENV_ARG="$2" || ENV_ARG=dev && \
      if [ "$ENV_ARG" == "prod" ]; then
        cd .. && \
        export COMPOSE_DOCKERFILE=$PROD_DOCKERFILE && \
        create_docker_compose_file && \
        docker compose up --build

      else
        export COMPOSE_DOCKERFILE=$DEV_DOCKERFILE && \
        docker compose \
          --file "$SCRIPTS_DIR/$COMPOSE_FILE" up \
          --build
        
      fi

    elif [ $1 == "run" ]; then
      ENTRYPOINT_COMMAND=$1 && \
      shift && \
      if [ $# -gt 0 ]; then   
        export COMPOSE_DOCKERFILE=$DEV_DOCKERFILE && \
        docker compose --file "$SCRIPTS_DIR/$COMPOSE_FILE" run \
          --build \
          --rm \
          --name "${APP_NAME}___${ENTRYPOINT_COMMAND}" \
          --publish $APP_PORT:$APP_INTERNAL_PORT \
          app $CONTAINER_ENTRYPOINT $ENTRYPOINT_COMMAND $@

      else args_error "Missing command for container initialization."; fi

    elif [ $1 == "delete" ]; then
      if [ "$EXISTING_PROJECT" == true ]; then
        delete_project

      else
        echo \
          "🛑  ${B}${C1}Failure${R}${C1}:${R}" \
          "There is no project to delete."
      fi
        
    elif [ $1 == "prune" ]; then
      export CONTAINERS_TO_STOP="" && \
      if [ ! -z "$CONTAINERS_TO_STOP" ]; then
        echo "Stopping all containers...\n" && \
        docker stop $CONTAINERS_TO_STOP && \
        echo "\nAll containers are Stopped.\n"
      fi && \
      docker system prune -a --volumes

    elif [ $1 == "demo" ]; then
      export WORKBENCH_SCRIPT="./$0"
      eval \
        "$WORKBENCH_SCRIPT new && " \
        "cd $WORKBENCH_DIR && " \
        "$WORKBENCH_SCRIPT setup && " \
        "$WORKBENCH_SCRIPT up &&" \
        "$WORKBENCH_SCRIPT delete"

    else args_error invalid; fi
  else readme; fi
