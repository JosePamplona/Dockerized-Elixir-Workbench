#!/bin/bash
# The golden corpus of the compose files, generated from the bash bake
# as it stood before `mix workbench.compose` replaced it. Every fixture
# under test/fixtures/compose/ is one cell of the matrix below, written
# by wb.sh's own bake_compose, bake_prod_compose and bake_scaled_compose
# — extracted from the script, the host-side helpers stubbed so the
# output is the same on every machine: free ports are the ports asked
# for, the user is 1000:1000, the project is "Lorem Ipsum" at 0.1.0.
#
#   ./test/support/compose_golden.sh [WB_SH] [SEEDS_DIR] [OUT_DIR]
#
# WB_SH defaults to the workbench's wb.sh and the seeds to scripts/ —
# which only holds while the script still bakes in bash. Afterwards,
# regenerate off the last commit that did:
#
#   git show <commit>:wb.sh > /tmp/wb.sh
#   git show <commit>:scripts/docker-compose.seed.yml > /tmp/seeds/docker-compose.seed.yml
#   git show <commit>:scripts/docker-compose.scaled.seed.yml > /tmp/seeds/docker-compose.scaled.seed.yml
#   ./test/support/compose_golden.sh /tmp/wb.sh /tmp/seeds
#
# Two fixtures were then corrected by hand, because the bash was wrong
# and the port is not to inherit it: prod-nodb.yml came out truncated at
# the app's env_file (the no-database branch had deleted the depends_on
# line bake_prod_compose's volume cut ended on, so sed cut to the end of
# the file — a live bug of `up --deploy prod` on a project without a
# database), and the four scaled-*-nobalancer-* files ended with a blank
# line that `sed '/^configs:/,$d'` left behind. The templates' output is
# the fixture in both cases.
# shellcheck disable=SC2034  # the variables below feed the functions eval'd from wb.sh
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
WB=${1:-"$HERE/../../../wb.sh"}
SEEDS=$(cd "${2:-"$HERE/../../../scripts"}" && pwd)
OUT=${3:-"$HERE/../fixtures/compose"}
mkdir -p "$OUT"; OUT=$(cd "$OUT" && pwd)

# The three bakes and the reader of the dev port, as the script has them.
for fn in bake_compose bake_prod_compose bake_scaled_compose workspace_app_port; do
  eval "$(awk "/^  $fn\\(\\)/,/^  }/" "$WB")"
done

# Host-side helpers, stubbed for a deterministic corpus.
first_free_port() { echo "$1"; }
id() { case "$1" in -u) echo 1000 ;; -g) echo 1000 ;; *) command id "$@" ;; esac; }
clustering_installed() { [ "$CLUSTERING" == true ]; }
workspace_needs_database() { [ "$DATABASE" == true ]; }

# The script's constants, and the project the fixtures describe.
SCRIPTS_DIR="$SEEDS"
COMPOSE_SEED="docker-compose.seed.yml"
SCALED_COMPOSE_SEED="docker-compose.scaled.seed.yml"
COMPOSE_FILE="docker-compose.yml"
PROD_COMPOSE_FILE="docker-compose.prod.yml"
SCALED_COMPOSE_FILE="docker-compose.scaled.yml"
LOCAL_DOCKERFILE="Dockerfile.local"
PROD_DOCKERFILE="Dockerfile"
MIX_FILE="mix.exs"
APP_INTERNAL_PORT="4000"
PGADMIN_INTERNAL_PORT="5050"
ELIXIR_PROJECT_NAME="lorem_ipsum"
APP_NAME="lorem-ipsum"
LOCAL_IMAGE="$APP_NAME:local"
POSTGRES_IMAGE_VERSION="latest"
PGADMIN_IMAGE_VERSION="latest"
NGINX_IMAGE_VERSION="alpine"
APP_PORT=4000
PGADMIN_PORT=5050

WORKSPACE_PATH=$(mktemp -d)
trap 'rm -rf "$WORKSPACE_PATH"' EXIT
printf '  def project do\n    [\n      app: :lorem_ipsum,\n      version: "0.1.0",\n' > "$WORKSPACE_PATH/$MIX_FILE"

for DATABASE in true false; do
  db=$([ "$DATABASE" == true ] && echo db || echo nodb)
  bake_compose "$LOCAL_IMAGE" "$LOCAL_DOCKERFILE" "$COMPOSE_FILE"
  cp "$WORKSPACE_PATH/$COMPOSE_FILE" "$OUT/dev-$db.yml"
  bake_prod_compose
  cp "$WORKSPACE_PATH/$PROD_COMPOSE_FILE" "$OUT/prod-$db.yml"
  for BALANCER in true false; do
    for CLUSTERING in true false; do
      for REPLICAS in 4 2; do
        # Two replicas only on the default shape: the count is one axis, not eight.
        [ "$REPLICAS" == 2 ] && { [ "$BALANCER" == true ] && [ "$CLUSTERING" == true ] && [ "$DATABASE" == true ]; } || [ "$REPLICAS" == 4 ] || continue
        BALANCER_PORT=""
        bake_scaled_compose
        cp "$WORKSPACE_PATH/$SCALED_COMPOSE_FILE" \
          "$OUT/scaled-$db-$([ "$BALANCER" == true ] && echo balancer || echo nobalancer)-$([ "$CLUSTERING" == true ] && echo cluster || echo nocluster)-$REPLICAS.yml"
      done
    done
  done
done
ls "$OUT"
