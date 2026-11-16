#!/bin/sh
# ===========================================================================
# Entrypoint wrapper - SKELETON, finish before building.
# ===========================================================================
# This app uses the upstream image "<image>", which is built to run as root.
# TOS forbids root containers, so this wrapper must make the service work as
# uid 1000. Typical steps (see ~/Documents/projects/nginx/src/entrypoint.sh for
# a complete, verified example):
#
#   1. create every path the service needs to write (pid file, temp/cache dirs)
#      under /tmp or under the mounted application data directory;
#   2. generate or seed the runtime configuration the first time (never
#      overwrite a file that already exists - the user owns it);
#   3. validate the configuration and fall back to a built-in default instead
#      of exiting, so a user mistake cannot cause a restart loop;
#   4. exec the real process in the foreground.
#
# MAINTAINERS: this file is embedded into docker-compose.yml by
# scripts/build.sh, which indents it and escapes every dollar sign (docker
# compose interpolates $VAR/${VAR} in compose files). Edit THIS file only.
# ===========================================================================
set -u

log() { printf '[%s] %s\n' "app" "$*"; }

RUN_DIR=/tmp/app
CONF_DIR=/config
DATA_DIR=/data
mkdir -p "$RUN_DIR" "$CONF_DIR" "$DATA_DIR" 2>/dev/null || true

log "starting (uid=$(id -u))"

# TODO: seed $CONF_DIR / $DATA_DIR on first start, then start the service.

exec "$@"
