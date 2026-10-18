#!/usr/bin/env bash
# Lab 6, Part D: turn the two database passwords of .env into the files
# that stack.yml declares as Swarm secrets. The folder secrets/ is ignored
# by Git; Swarm copies each file into its encrypted store at deploy time.
set -euo pipefail
cd "$(dirname "$0")/.."
ENV_FILE="${ENV_FILE:-.env}"
[[ -f "$ENV_FILE" ]] || { echo "No $ENV_FILE: cp .env.example .env first"; exit 1; }
set -a; source "$ENV_FILE"; set +a
umask 077
mkdir -p secrets
printf '%s' "$DB_PASSWORD" > secrets/db_password.txt
printf '%s' "$DB_ROOT_PASSWORD" > secrets/db_root_password.txt
echo "Wrote secrets/db_password.txt and secrets/db_root_password.txt (mode 600, not in Git)."
