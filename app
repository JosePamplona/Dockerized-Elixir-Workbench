#!/bin/bash
# Dockerized workbench script
# v0.2.0

# CONFIGURATION ================================================================

  source ./config.conf

  # Workbench configuration --------------------------------------------------

    WORKBENCH_DIR="_workbench"
    WORKBENCH_VERSION=$( sed '3!d' $0 | sed -n 's/^.*v\(.*\).*/\1/p' )
    WORKBENCH_README_FILE="README.md"
    EXISTING_PROJECT=$(
      [ $(basename $PWD) == $WORKBENCH_DIR ] && \
      echo true || \
      echo false
    )
    SOURCE_CODE_PATH=$(
      [ $EXISTING_PROJECT == true ] && \
      echo $(dirname $PWD) || \
      echo $PWD
    )
    GIT_DIR=$(
      [ $EXISTING_PROJECT == true ] && \
      echo "../.git" || \
      echo ".git"
    )  
    if [ -d $GIT_DIR ]
    then REPO_URL=$(git config --get remote.origin.url | sed 's/\.git$//')
    else REPO_URL="https://github.com/user/repo"
    fi
    REPO_OWNER=$( echo $REPO_URL | sed -E 's|https://[^/]+/([^/]+)/.*|\1|' )
    REPO_NAME=$(  echo $REPO_URL | sed 's|.*/||' )

    # Update script README.md file
    sed -i "s/\(!\[v\).*\(\]\)/\1$WORKBENCH_VERSION\2/" $WORKBENCH_README_FILE
    sed -i \
      "s/\(version-\).*\(-white.*\)/\1$WORKBENCH_VERSION\2/" \
      $WORKBENCH_README_FILE

    # Directories
    SCRIPTS_DIR="scripts"
    SEEDS_DIR="seeds"
    PGADMIN_DIR="pgadmin"

    # Script files
    ENTRYPOINT_FILE="entrypoint.sh"
    SCHEMAS_FILE="schemas.sh"
    DEV_DOCKERFILE="Dockerfile.dev"
    PROD_DOCKERFILE="Dockerfile"
    COMPOSE_FILE="docker-compose.yml"
    CONTAINER_ENTRYPOINT="bash $ENTRYPOINT_FILE"

    # Seed files
    ENV_SEED="seed.env"
    README_SEED="README.seed.md"
    CHANGELOG_SEED="CHANGELOG.seed.md"
    DEV_DOCKERFILE_SEED="Dockerfile.seed.dev"
    PROD_DOCKERFILE_SEED="Dockerfile.seed.prod"
    PGADMIN_SERVERS_SEED="servers.seed.json"
    PGADMIN_PASS_SEED="pgpass.seed"
    TOOLS_VERSIONS_SEED="seed.tool-versions"

    # Elixir project files
    LOWER_CASE=$( echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' )
    ELIXIR_PROJECT_NAME=$( echo $LOWER_CASE | tr ' ' '_' )
    ELIXIR_MODULE=$(
      echo $LOWER_CASE | sed -E 's/(^| )(\w)/\U\2/g' | sed 's/ //g'
    )
    INIT_VERSION="0.0.0"
    ENV_FILE=".env"
    MIX_FILE="mix.exs"
    ASSETS_DIR="assets"
    WEB_DIR="lib/${ELIXIR_PROJECT_NAME}_web"
    CONTROLLERS_DIR="$WEB_DIR/controllers"
    ROUTER_FILE="$WEB_DIR/router.ex"
    CONFIG_FILE="config/config.exs"
    DEV_FILE="config/dev.exs"
    TEST_FILE="config/test.exs"
    RUNTIME_FILE="config/runtime.exs"
    README_FILE="README.md"
    CHANGELOG_FILE="CHANGELOG.md"
    PROD_DOCKERFILE="Dockerfile"
    GITIGNORE_FILE=".gitignore"
    FORMATTER_FILE=".formatter.exs"
    TOOLS_VERSIONS_FILE=".tool-versions"

    # Production database
    DB_NAME="${ELIXIR_PROJECT_NAME}_prod"

    # PGAdmin configuration files
    SERVERS_FILE="servers.json"
    PASS_FILE="pgpass"
    PGADMIN_PATH="$SOURCE_CODE_PATH/$WORKBENCH_DIR/$PGADMIN_DIR"

  # docker-compose.yml script export variables -------------------------------

    # Docker compose project configuration
    export APP_NAME=$( echo "$LOWER_CASE" | tr ' ' '-' )
    export APP_VERSION=$(
      [ $EXISTING_PROJECT == true ] && [ -f $MIX_FILE ] && \
        sed -n 's/^.*version: "\(.*\)".*/\1/p' "../$MIX_FILE" | head -n 1 || \
        echo $INIT_VERSION
    )

    # Docker images
    DEV_IMAGE="$APP_NAME-workbench:$WORKBENCH_VERSION"
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

  # Implementations fo elixir project  ---------------------------------------

    # ExDoc documentation implementation
    EXDOC_VERSION="~> 0.34"
    # API REST documentation implementation
    OPEN_API_VERSION="~> 3.21"
    # Coveralls report implementation
    COVERALLS_VERSION="~> 0.18"
    MINIMUM_COVERAGE="85"

    # Auth0 implementation
    AUTH0_PROD_JS="https://cdn.auth0.com/js/auth0-spa-js/2.0/auth0-spa-js.production.js"

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

    print_command "demo [-e, --env ENV]"
    section_content \
      "Runs consecutively new, setup, up & delete commands." \
      "- ENV: Enviroment to deploy (Defalut: dev)."

    print_command "delete"
    section_content \
      "Deletes project files and Docker compose project."

    print_command "prune"
    section_content \
      "Stops all containers and prune Docker."

    print_command "help"
    section_content \
      "Shows the workbech script help section."

    section "VERSION"
    section_content \
      "$WORKBENCH_VERSION"
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

  # scape_for_sed <STRING>
  scape_for_sed() { echo "$1" | sed 's/[\/&]/\\&/g'; }

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
    rm -rf $PGADMIN_DIR && \
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

        cp $seed_path $file_path
        sed -i "s/%{elixir_version}/$ELIXIR_VERSION/" $file_path
        sed -i "s/%{erlang_version}/$ERLANG_VERSION/" $file_path
        sed -i "s/%{debian_version}/$DEBIAN_VERSION/" $file_path
        sed -i "s/%{schemas}/$SCHEMAS_FILE/"          $file_path
        sed -i "s/%{entrypoint}/$ENTRYPOINT_FILE/"    $file_path
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

  # configure_files PHOENIX_NEW_OPTIONS
    # After project creation it configures some elixir files and add new ones.
  configure_files() {
    local PHOENIX_NEW_OPTIONS="$@"
    local NO_HTML=$(
      local result=false
      for arg in $PHOENIX_NEW_OPTIONS; do
        if [ "$arg" = "--no-html" ]; then
          result=true
          break
        fi
      done
      
      echo $result
    )

    # FUNCTIONS --------------------------------------------------------------
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
          "s/version:\s*\"[0-9]*.[0-9]*.[0-9]*\"/version: \"$INIT_VERSION\"/" \
          $MIX_FILE
      }

      # adjust_config
        # Configures the timestamps and id types in config.exs file.
      adjust_config() {

        # prepend_config
          #
        prepend_config() {
          local output=""
          for arg in "$@"; do
            output+="$arg\n"
          done && \
          output=${output::-2}

          sed -i '/import Config/a \'"$output" $CONFIG_FILE
        }

        prepend_config \
          "" \
          "# Enabling ANSI color codes for TTY emulation" \
          "config :elixir, ansi_enabled: true"

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

        if [ "$API_INTERFACE" == "graphql" ]
        then local api_type="GraphQL"
        elif [ "$API_INTERFACE" == "rest" ]
        then local api_type="REST"
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

        if [ "$COVERALLS" == true ]
        then pattern keep   $file_path "coveralls"
        else pattern delete $file_path "coveralls"
        fi

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
      adjust_config_test && \
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
    sed -i "s/\$COMPOSE_IMAGE/$COMPOSE_IMAGE/"                   $file_path
    sed -i "s/\$APP_NAME/$APP_NAME/"                             $file_path
    sed -i "s/\$APP_VERSION/$APP_VERSION/"                       $file_path
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
    # CONFIGURATION --------------------------------------------------------
      local ELIXIR_ASSETS_PATH="assets"

      # Shared between ExDoc & Coveralls
      # EcDoc
      local EXDOC_ASSETS_DIR="exdoc"
      local ELIXIR_EXDOC_ASSETS_PATH="$ELIXIR_ASSETS_PATH/$EXDOC_ASSETS_DIR"
      # Coveralls
      local ELIXIR_COVERALLS_DIR="cover"
      local COVERALLS_OUTPUT_DIR="html"
      if [ "$EXDOC" == true ]
      then local COVERALLS_PATH="$ELIXIR_EXDOC_ASSETS_PATH/$ELIXIR_COVERALLS_DIR";
      else local COVERALLS_PATH="$ELIXIR_ASSETS_PATH/$ELIXIR_COVERALLS_DIR";
      fi
      local COVERALLS_OUTPUT_PATH="$COVERALLS_PATH/$COVERALLS_OUTPUT_DIR"
      local EXDOC_TEST_FILE="testing.md"
      
    # FUNCTIONS --------------------------------------------------------------

      feature_init() { echo "${C3}* implementing${R} $@"; }
      feature_done() { dude="ok"; }
        # echo "${C3}✔${R} $@  ${C3}Implemented${R}"; }

      # mix_insert FUNCTION LINES...
        # Insert a new line on mix.exs deps list
      mix_insert() {
        local function="$1"; shift
        local output=""

        [ $# -ge 1 ] && \
        for arg in "$@"; do
          output+="      $arg\n"
        done && \
        sed -i '/defp\? '"$function"' do/,/end/ {
          /^    \]/i\'"${output::-2}"'
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

        # sed -i '/defp\? '"$1"' do/,/end/ {
        #   /[/:/]/ {
        #     s/\([^,]$\)/\1'"$2"'/
        #   }
        # }' $MIX_FILE

        # sed '/defp\? '"$1"' do/,/end/ {
        #   /end/ {
        #     x
        #     /^$/ {
        #       x
        #       s/\([^,]$\)/\1'"$2"'/
        #     }
        #     x
        #   }
        #   G
        #   h
        #   s/.*\n//
        # }' $MIX_FILE
      }

      # mix_insert_after_function FUNCTION LINES...
      mix_insert_after_function() {
        [ $# -ge 2 ] && \
        local function="$1"; shift
        local output=""

        for arg in "$@"; do
          output+="  $arg\n"
        done && \
        sed -i '/defp\? '"$function"' do/,/end/ {
          /end/a\'"${output::-2}"'
        }' $MIX_FILE
      }

      # router_add_pipeline
        #
      router_add_pipeline() {
        # [ $# -ge 1 ] && \
        local output=""
        for arg in "$@"; do
          output+="  $arg\n"
        done && \
        output=${output::-2}
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

        sed -i '/pipeline '"${last_pipeline}"' do/,/end/ {
          /end/ {
            a\\n'"${output}"'
          }
        }
        ' $ROUTER_FILE
      }

      # router_add_scope SCOPE PIPE IDENTATION_LEVEL
      router_add_scope() {
        # [ $# -ge 4 ] && \
        local  scope="$1"; shift
        local   pipe="$1"; shift
        local  ident="$1"; shift
        local spaces=$(printf '%*s' $((ident * 2)) '')
        local output=""
        for arg in "$@"; do
          output+="$spaces$arg\n"
        done && \
        output=${output::-2}

        sed -i '/scope '"${scope}"' do/,/end/ {
          /pipe_through '"${pipe}"'/,/end/ {
            /end/ {
              a\\n'"${output}"'
            }
          }
        }
        ' $ROUTER_FILE
      }

      # implement_default_enhancements
        #
      implement_default_enhancements() {
        # CONFIGURATION --------------------------------------------------------
          local FEATURE="Default enhancements"

        # SCRIPT ---------------------------------------------------------------
          feature_init $FEATURE

          echo "---> Coming soon --> $FEATURE"
          # CONTINUE
          # default Enhancements
            # flame_on
            # Dashboard: psql_extras, os_mon
            # credo:

          feature_done $FEATURE
      }

      # implement_rest
        #
      implement_rest() {
        # CONFIGURATION --------------------------------------------------------
          local FEATURE="OpenAPI"

          local OPEN_API_ENDPOINT="openapi"
          local SWAGGER_ENDPOINT="swagger"
          local SCHEMAS_FILE="schemas.ex"
          local SPEC_FILE="spec.ex"
          local SCHEMAS_SEED_FILE="schemas.seed.ex"
          local SPEC_SEED_FILE="spec.seed.ex"
          local ELIXIR_OPEN_API_DIR="$WEB_DIR/open_api"
          local ELIXIR_API_SCHEMAS_FILE="$ELIXIR_OPEN_API_DIR/schemas.ex"
          local ELIXIR_API_SPEC_FILE="$ELIXIR_OPEN_API_DIR/spec.ex"

        # SCRIPT ---------------------------------------------------------------
          feature_init $FEATURE

          [ ! -d $ELIXIR_OPEN_API_DIR ] && mkdir $ELIXIR_OPEN_API_DIR

          # Plant schemas.ex file
          cp \
            "$WORKBENCH_DIR/$SEEDS_DIR/$SCHEMAS_SEED_FILE" \
            $ELIXIR_API_SCHEMAS_FILE

          sed -i "s/%{elixir_module}/$ELIXIR_MODULE/" $ELIXIR_API_SCHEMAS_FILE
          sed -i \
            "s/%{project_name}/$ELIXIR_PROJECT_NAME/" \
            $ELIXIR_API_SCHEMAS_FILE

          [ $HEALTHCHECK == true ] && \
          pattern keep $ELIXIR_API_SCHEMAS_FILE "healthcheck" || \
          pattern delete $ELIXIR_API_SCHEMAS_FILE "healthcheck"

          # Plant spec.ex file
          cp \
            "$WORKBENCH_DIR/$SEEDS_DIR/$SPEC_SEED_FILE" \
            $ELIXIR_API_SPEC_FILE
          
          sed -i "s/%{elixir_module}/$ELIXIR_MODULE/" $ELIXIR_API_SPEC_FILE
          sed -i "s/%{project_name}/$PROJECT_NAME/"   $ELIXIR_API_SPEC_FILE

          if [ ! -f $MIX_FILE ]; then
            terminate "The $MIX_FILE file does not exist."
          else
            mix_append deps ","
            mix_insert deps \
              "# OpenAPI documentation deps" \
              "{:open_api_spex, \"$OPEN_API_VERSION\"}"
          fi

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

            router_add_scope "\"\/dev\"" "\(:browser\|\[:fetch.*\]\)" 2 \
              "# OpenAPI schema (json file)" \
              "scope \"/dev\" do" \
              "  pipe_through [:api, :open_api_spec]" \
              "" \
              "  get \"/$OPEN_API_ENDPOINT\", RenderSpec, []" \
              "end"

            swagger=""
            swagger+="\n      # SwaggerUI interface for REST-API documentation"
            swagger+="\n      get \"/$SWAGGER_ENDPOINT\", SwaggerUI"
            swagger+=", path: \"/dev/$OPEN_API_ENDPOINT\""

            sed -i '/forward "\/mailbox", .*$/a\'"$swagger" $ROUTER_FILE
          fi

          feature_done $FEATURE
      }

      # implement_graphql
        #
      implement_graphql() {
        # CONFIGURATION --------------------------------------------------------
          local FEATURE="API GraphQL"

        # SCRIPT ---------------------------------------------------------------
          feature_init $FEATURE

          echo "---> Coming soon --> $FEATURE"

          feature_done $FEATURE
      }

      # implement_exdoc
        #
      implement_exdoc() {
        # FUNCTIONS ------------------------------------------------------------
          # inject_frontend_vars_in_runtime
            #
          inject_frontend_vars_in_runtime() {
            local output=""
            for arg in "$@"; do
              output+="$arg\n"
            done
            
            sed -i '/if System.get_env/i\'"$output" $RUNTIME_FILE
          }

        # CONFIGURATION --------------------------------------------------------

          local FEATURE="ExDoc"
          # Estas variables está alojadas aqui para representar que solo son usadas
          # para implementar ex_doc y mantenerlo isolado, si otra implementación
          # usa alguna de estas variables se sacará al script principal.
          local    EXDOC_ENDPOINT="docs"
          local      RESOURCE_DIR="doc"
          local ASSETS_EXDOC_PATH="$WORKBENCH_DIR/$ELIXIR_EXDOC_ASSETS_PATH"
          local   ASSETS_IMG_PATH="$ASSETS_EXDOC_PATH/images"
          local    ASSETS_JS_PATH="$ASSETS_EXDOC_PATH/js"
          local     APP_LOGO_FILE="logo.png"
          local          ARQ_FILE="arq.svg"
          local   TOKEN_SEED_FILE="token.seed.md"
          local TESTING_SEED_FILE="testing.seed.md"
          local EXDOC_CONTROLLER_SEED_FILE="exdoc_controller.seed.ex"

          local EXDOC_CONTROLLER_FILE="$CONTROLLERS_DIR/exdoc_controller.ex"
          local EXDOC_CONTORLLER_MODULE="ExDocController"

          # local   GUIDELINE_USER="rrrene"
          # local   GUIDELINE_REPO="elixir-style-guide"
          # local GUIDELINE_BRANCH="master"
          # local   GUIDELINE_FILE="README.md"
          local   GUIDELINE_USER="JosePamplona"
          local   GUIDELINE_REPO="Elixir-Coding-Conventions"
          local GUIDELINE_BRANCH="master"
          local   GUIDELINE_FILE="README.en_US.md"

          local GUIDELINE_URL="https://raw.githubusercontent.com/"
          local GUIDELINE_URL+="$GUIDELINE_USER/"
          local GUIDELINE_URL+="$GUIDELINE_REPO/"
          local GUIDELINE_URL+="$GUIDELINE_BRANCH/"
          local GUIDELINE_URL+="$GUIDELINE_FILE"

          local    EXDOC_ASSETS_IMG_PATH="$ELIXIR_EXDOC_ASSETS_PATH/images"
          local     EXDOC_ASSETS_JS_PATH="$ELIXIR_EXDOC_ASSETS_PATH/js"
          local EXDOC_ASSETS_CONFIG_PATH="$ELIXIR_EXDOC_ASSETS_PATH/config"
          local      EXDOC_APP_LOGO_FILE="$EXDOC_ASSETS_IMG_PATH/app-logo.png"
          local EXDOC_WORKBENCH_ARQ_FILE="$EXDOC_ASSETS_IMG_PATH/arq.svg"
          local     EXDOC_WORKBENCH_FILE="$ELIXIR_EXDOC_ASSETS_PATH/workbench.md"
          local         EXDOC_TOKEN_FILE="$ELIXIR_EXDOC_ASSETS_PATH/token.md"
          local       EXDOC_TESTING_FILE="$ELIXIR_EXDOC_ASSETS_PATH/$EXDOC_TEST_FILE"
          local     EXDOC_GUIDELINE_FILE="$ELIXIR_EXDOC_ASSETS_PATH/coding.md"

        # SCRIPT ---------------------------------------------------------------
          feature_init $FEATURE

          # Plant ExDoc Controller
          cp \
            "$WORKBENCH_DIR/$SEEDS_DIR/$EXDOC_CONTROLLER_SEED_FILE" \
            $EXDOC_CONTROLLER_FILE
          
          sed -i "s/%{elixir_module}/$ELIXIR_MODULE/"      $EXDOC_CONTROLLER_FILE
          sed -i "s/%{resource_dir}/$RESOURCE_DIR/"        $EXDOC_CONTROLLER_FILE
          sed -i "s/%{project_name}/$ELIXIR_PROJECT_NAME/" $EXDOC_CONTROLLER_FILE
          sed -i "s/%{exdoc_endpoint}/$EXDOC_ENDPOINT/"    $EXDOC_CONTROLLER_FILE

          [ $COVERALLS == true ] && \
          pattern keep $EXDOC_CONTROLLER_FILE "coveralls" || \
          pattern delete $EXDOC_CONTROLLER_FILE "coveralls"

          # Create ExDoc assets directory
          [ ! -d $ELIXIR_ASSETS_PATH ] && mkdir $ELIXIR_ASSETS_PATH
          [ ! -d $ELIXIR_EXDOC_ASSETS_PATH ] && mkdir $ELIXIR_EXDOC_ASSETS_PATH

          # Create image asset files
          [ ! -d $EXDOC_ASSETS_IMG_PATH ] && mkdir $EXDOC_ASSETS_IMG_PATH
          cp "$ASSETS_IMG_PATH/$APP_LOGO_FILE" $EXDOC_APP_LOGO_FILE

          [ "$AUTH0" == true ] && [ "$STRIPE" == true ] && local arq="arq.svg"
          [ "$AUTH0" != true ] && [ "$STRIPE" == true ] && local arq="arq-1.svg"
          [ "$AUTH0" == true ] && [ "$STRIPE" != true ] && local arq="arq-2.svg"
          [ "$AUTH0" != true ] && [ "$STRIPE" != true ] && local arq="arq-3.svg"
          cp "$WORKBENCH_DIR/$ASSETS_DIR/$arq" $EXDOC_WORKBENCH_ARQ_FILE
          
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

          [ "$STRIPE" != true ] && \
          sed -i "/|.*Stripe.*|/d" $EXDOC_WORKBENCH_FILE
          [ "$AUTH0" != true ] && \
          sed -i "/|.*Auth0.*|/d" $EXDOC_WORKBENCH_FILE

          # Download codeguide
          [ $CODING_GUIDELINES == true ] && \
          curl -o $EXDOC_GUIDELINE_FILE $GUIDELINE_URL

          # Plant testing page
          [ $COVERALLS == true ] && \
          cp "$WORKBENCH_DIR/$SEEDS_DIR/$TESTING_SEED_FILE" $EXDOC_TESTING_FILE

          # Plant token page
          [ "$AUTH0" == true ] && \
          cp "$WORKBENCH_DIR/$SEEDS_DIR/$TOKEN_SEED_FILE" $EXDOC_TOKEN_FILE

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
            [ $COVERALLS == true ] && \
            mix_insert project \
              "    \"$COVERALLS_OUTPUT_PATH\" => \"/\","
            mix_insert project \
              "    \"$EXDOC_ASSETS_IMG_PATH\" => \"/assets\"," \
              "    \"$EXDOC_ASSETS_JS_PATH\" => \"/assets\"" \
              "  }," \
              "  extras: [" \
              "    {\"$README_FILE\", [title: \"Overview\"]},"
              # "    {\"assets/doc/database.md\", [title: \"Database\"]}," \
            [ $AUTH0 == true ] && \
            mix_insert project \
              "    {\"$EXDOC_TOKEN_FILE\", [title: \"Get access tokens\"]},"
            [ $COVERALLS == true ] && \
            mix_insert project \
              "    {\"$EXDOC_TESTING_FILE\", [title: \"Tests reports\"]},"
            [ $CODING_GUIDELINES == true ] && \
            mix_insert project \
              "    {\"$EXDOC_GUIDELINE_FILE\", [title: \"Coding guidelines\"]},"
            mix_insert project \
              "    {\"$EXDOC_WORKBENCH_FILE\", [title: \"Workbench\"]}," \
              "    {\"$CHANGELOG_FILE\", [title: \"Changelog\"]}" \
              "  ]," \
              "  groups_for_extras: [" \
              "    \"Project\": [" \
              "      \"$README_FILE\"," \
              "      \"$CHANGELOG_FILE\"" \
              "    ]," \
              "    \"Support\": [" \
              "      \"$EXDOC_WORKBENCH_FILE\"," \
              "      \"$EXDOC_GUIDELINE_FILE\","
            [ $AUTH0 == true ] && \
            mix_insert project \
              "      \"$EXDOC_TOKEN_FILE\","
            [ $AUTH0 == true ] && [ $COVERALLS == true ] && \
            mix_insert project \
              "      \"$EXDOC_TESTING_FILE\"," \
              "    ]" \
              "  ]," \
              "  groups_for_modules: [" \
              "    \"Contexts\":    ~r/^${ELIXIR_MODULE}\\\.(?!(.*\\\..*|Mailer|Repo)$).*$/," \
              "    \"Schemas\":     ~r/^${ELIXIR_MODULE}\\\..*\\\.(?!.*(Enum)$).*$/," \
              "    \"Collections\": ~r/^${ELIXIR_MODULE}\\\..*(Enum)$/,"
            [ "$API_INTERFACE" == "graphql" ] && [ $AUTH0 == true ] && \
            mix_insert project \
              "    \"Authentication\": [" \
              "      ${ELIXIR_MODULE}Web.Graphql.Context" \
              "    ],"
            mix_insert project \
              "    \"Web\":         ~r/^${ELIXIR_MODULE}Web(?!.*(Controller|HTML|JSON)$)/," \
              "    \"Controllers\": ~r/^${ELIXIR_MODULE}Web.*(Controller|HTML|JSON)$/" \
              "  ]," \
              "  before_closing_head_tag: &before_closing_head_tag/1," \
              "  before_closing_body_tag: &before_closing_body_tag/1" \
              "]"

            html_body="  <script src=\"./assets/themedImage.js\"></script>"
            if [ "$AUTH0" == true ]; then
              html_body+="\n    <script src=\"$AUTH0_PROD_JS\"></script>"
              html_body+="\n    <script src=\"./assets/auth_config.js\"></script>"
              html_body+="\n    <script src=\"./assets/token.js\"></script>"
            fi

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

          if [ ! -f $RUNTIME_FILE ]; then
            terminate "The $RUNTIME_FILE file does not exist."
          else
            if [ "$AUTH0" == true ]; then
              client_id=$(
                head -c $((32 * 2)) /dev/urandom | \
                base64 | \
                tr -dc 'a-zA-Z0-9' | \
                head -c 32
              )

              inject_frontend_vars_in_runtime \
                "# Auth0 & ExDoc implementation:" \
                "# Create auth_config.js file for token request in ExDoc token page." \
                "if config_env() != :prod do" \
                "  File.mkdir_p!(\"./priv/static/doc/assets/\")" \
                "  File.write(" \
                "    \"./priv/static/doc/assets/auth_config.js\"," \
                "    \"\"\"" \
                "    var authConfig = {" \
                "      domain: \"#{" \
                "        System.get_env(\"AUTH0_DOMAIN\") ||" \
                "          raise \"\"\"" \
                "          environment variable AUTH0_DOMAIN is missing." \
                "          For example: dev-tenant.us.auth0.com" \
                "          \"\"\"" \
                "      }\"," \
                "      client_id: \"#{" \
                "        System.get_env(\"AUTH0_CLIENT_ID\") ||" \
                "          raise \"\"\"" \
                "          environment variable AUTH0_CLIENT_ID is missing." \
                "          For example: $client_id" \
                "          \"\"\"" \
                "      }\"," \
                "      audience: \"#{" \
                "        System.get_env(\"AUTH0_AUDIENCE\") ||" \
                "          raise \"\"\"" \
                "          environment variable AUTH0_AUDIENCE is missing." \
                "          For example: https://www.$APP_NAME.com" \
                "          \"\"\"" \
                "      }\"" \
                "    }" \
                "    \"\"\"" \
                "  )" \
                "end"
            fi
          fi

          feature_done $FEATURE
      }

      # implement_coveralls
        #
      implement_coveralls() {
        # CONFIGURATION --------------------------------------------------------
          local FEATURE="Coveralls"

          local COVERALLS_DIR="coverage"
          local TEMPLATE_DIR="template"
          local COVER_TASK_SEED_FILE="cover.seed.ex"
          local COVERALLS_SEED_FILE="coveralls.seed.json"
          local ELIXIR_COVERALLS_FILE="coveralls.json"
          local COVERALLS_TEMPLATE_PATH="$COVERALLS_PATH/$TEMPLATE_DIR"
          local MIX_DIR_PATH="lib/mix"
          local MIX_TASK_PATH="$MIX_DIR_PATH/task"
          local COVER_TASK_PATH="$MIX_TASK_PATH/cover.ex"

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

          # Plant: cover.seed.ex
          if [ "$EXDOC" == true ]
          then
            [ ! -d $MIX_DIR_PATH ]  && mkdir $MIX_DIR_PATH
            [ ! -d $MIX_TASK_PATH ] && mkdir $MIX_TASK_PATH
          
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
              "# Coverage parameters" \
              "test_coverage: [tool: ExCoveralls]," \
              "preferred_cli_env: [" \
              "  cover: :test," \
              "  coveralls: :test," \
              "  \"coveralls.detail\": :test," \
              "  \"coveralls.post\": :test," \
              "  \"coveralls.html\": :test," \
              "  \"coveralls.cobertura\": :test," \
              "]"

            mix_append deps ","
            mix_insert deps \
              "# Coverage report deps" \
              "{:excoveralls, \"$COVERALLS_VERSION\", only: :test}"
          fi

          feature_done $FEATURE
      }

      # implement_healthcheck
        #
      implement_healthcheck(){
        # CONFIGURATION --------------------------------------------------------
          local FEATURE="Healthcheck"

          local HEALTHCHECK_ENDPOINT="health"
          local CONTROLLER_FILE="healthcheck_controller.ex"
          local CONTROLLER_SEED_FILE="healthcheck_controller.seed.ex"

          local ELIXIR_CONTROLLER_FILE="$CONTROLLERS_DIR/$CONTROLLER_FILE"

        # SCRIPT ---------------------------------------------------------------
          feature_init $FEATURE

          # Plant healthcheck_controller.ex file
          cp \
            "$WORKBENCH_DIR/$SEEDS_DIR/$CONTROLLER_SEED_FILE" \
            $ELIXIR_CONTROLLER_FILE

          sed -i "s/%{elixir_module}/$ELIXIR_MODULE/" $ELIXIR_CONTROLLER_FILE
          sed -i \
            "s/%{elixir_project_name}/$ELIXIR_PROJECT_NAME/" \
            $ELIXIR_CONTROLLER_FILE


          if [ ! -f $ROUTER_FILE ]; then
            terminate "The $ROUTER_FILE file does not exist."
          else
            router_add_scope "\"\/api\/v1\", ${ELIXIR_MODULE}Web" ":api" 1 \
              "# Healthcheck endpoint" \
              "scope \"/$HEALTHCHECK_ENDPOINT\", ${ELIXIR_MODULE}Web do" \
              "  pipe_through :api" \
              "" \
              "  get \"/\", HealthcheckController, :health" \
              "end"
          fi

          feature_done $FEATURE
      }

      # implement_auth0
        #
      implement_auth0(){
        # CONFIGURATION --------------------------------------------------------
          local FEATURE="Auth0"

        # SCRIPT ---------------------------------------------------------------
          feature_init $FEATURE

          echo "  ---> Coming soon --> $FEATURE"
          # add ENV /assets/doc/js/auth_config.js

          # Add router
          # "pipeline :auth do" \
          # "plug ValidateToken, no_halt: true" \
          # "plug GetUser, no_halt: true, user_from_claim: &Auth.login_from_claim/2" \
          # "plug PitchersWeb.Graphql.Context"
          # end

          feature_done $FEATURE
      }

      # implement_stripe
        #
      implement_stripe(){
        # CONFIGURATION --------------------------------------------------------
          local FEATURE="Stripe"

        # SCRIPT ---------------------------------------------------------------
          feature_init $FEATURE

          echo "  ---> Coming soon --> $FEATURE"

          feature_done $FEATURE
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

      implement_default_enhancements && \
      if [ "$API_INTERFACE" == "rest" ] || [ "$HEALTHCHECK" == true ]; then
        implement_rest;
      fi && \
      if [ "$API_INTERFACE" == "graphql" ]; then implement_graphql;     fi && \
      if [ "$EXDOC" == true ];              then implement_exdoc;       fi && \
      if [ "$COVERALLS" == true ];          then implement_coveralls;   fi && \
      if [ "$HEALTHCHECK" == true ];        then implement_healthcheck; fi && \
      if [ "$AUTH0" == true ];              then implement_auth0;       fi && \
      if [ "$STRIPE" == true ];             then implement_stripe;      fi && \
      echo
  }

# SCRIPT =======================================================================

  if [ $# -gt 0 ]; then
    if   [ $1 == "login" ]; then
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

    elif [ $1 == "new" ]; then
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
          $EXDOC \
          $COVERALLS \
          $RUN_SCHEMAS_SCRIPT && \
      if [ $EXISTING_PROJECT != true ]; then
        echo \
          "For further workbench script use, remember to navigate to the" \
          "script directory:\n\n" \
          "   $ cd $WORKBENCH_DIR\n"
      fi
             
      # ERROR: Tarball error will occur on Win11 using a XFAT drive for the repo
      # on 'mix deps.get' run.
    elif [ $1 == "setup" ]; then
      ENTRYPOINT_COMMAND=$1; shift

      if [ $EXISTING_PROJECT == true ]; then
        [ $# -gt 1 ] && [ "$1" == "--env" ] || [ "$1" == "-e" ] && \
          ENV_ARG="$2" || \
          ENV_ARG=dev
        
        export COMPOSE_DOCKERFILE=$DEV_DOCKERFILE
        export COMPOSE_IMAGE=$DEV_IMAGE
        docker compose --file "$SCRIPTS_DIR/$COMPOSE_FILE" run \
          --build \
          --rm \
          --name "${APP_NAME}___${ENTRYPOINT_COMMAND}" \
          --publish $APP_PORT:$APP_INTERNAL_PORT \
          app $CONTAINER_ENTRYPOINT $ENTRYPOINT_COMMAND $ENV_ARG

      else terminate "There is no project to setup."; fi
        
    elif [ $1 == "up" ]; then
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
            --file "$SCRIPTS_DIR/$COMPOSE_FILE" \
            $COMPOSE_COMMAND \
            --build
        fi

      else terminate "There is no project to deploy."; fi

    elif [ $1 == "run" ]; then
      ENTRYPOINT_COMMAND=$1; shift
      if [ $EXISTING_PROJECT == true ]; then
        if [ $# -gt 0 ]; then
          export COMPOSE_DOCKERFILE=$DEV_DOCKERFILE
          export COMPOSE_IMAGE=$DEV_IMAGE
          docker compose --file "$SCRIPTS_DIR/$COMPOSE_FILE" run \
            --build \
            --rm \
            --name "${APP_NAME}___${ENTRYPOINT_COMMAND}" \
            --publish $APP_PORT:$APP_INTERNAL_PORT \
            app $CONTAINER_ENTRYPOINT $ENTRYPOINT_COMMAND $@

        else args_error "Missing command for container initialization."; fi
      else terminate "There is no project to deploy."; fi

    elif [ $1 == "delete" ]; then
      COMPOSE_COMMAND="down"
      if [ $EXISTING_PROJECT == true ]; then
        delete_project && \
        docker compose \
          $COMPOSE_COMMAND \
          --volumes \
          --rmi local \
          --remove-orphans

      else terminate "There is no project to delete."; fi
        
    elif [ $1 == "prune" ]; then
      CONTAINERS_TO_STOP="$(docker container ls -q)"

      if [ ! -z "$CONTAINERS_TO_STOP" ]; then
        echo "Stopping all containers...\n"
        docker stop $CONTAINERS_TO_STOP && \
        echo "\nAll containers are Stopped.\n"
      fi && \
      docker system prune -a --volumes

    elif [ $1 == "demo" ]; then
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

    elif [ $1 == "help" ]; then
      help
    else args_error invalid; fi
  else help; fi
