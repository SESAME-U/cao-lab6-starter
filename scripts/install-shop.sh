#!/usr/bin/env bash
# Lab 6: install WordPress with WP-CLI inside a running shop container,
# then activate WooCommerce. Safe to re-run: an installed site is left alone.
#   scripts/install-shop.sh compose   the shop of the Compose project
#   scripts/install-shop.sh stack     one task of the Swarm service cao_shop
set -euo pipefail
cd "$(dirname "$0")/.."
ENV_FILE="${ENV_FILE:-.env}"
set -a; source "$ENV_FILE"; set +a
mode="${1:-compose}"
project="${COMPOSE_PROJECT_NAME:-lab6}"
stack="${STACK:-cao}"

find_shop() {
  if [[ $mode == stack ]]; then
    docker ps -q -f "label=com.docker.swarm.service.name=${stack}_shop" -f status=running | head -1
  else
    docker ps -q -f "label=com.docker.compose.project=${project}" -f "label=com.docker.compose.service=shop" | head -1
  fi
}

echo "==> Looking for a running shop container ($mode)"
cid=""
for _ in $(seq 1 30); do cid=$(find_shop); [[ -n $cid ]] && break; sleep 2; done
[[ -n $cid ]] || { echo "No running shop container: start it first (make up, or make stack-up)"; exit 1; }

wp() { docker exec -u www-data "$cid" wp "$@"; }

if [[ -n "${CODESPACE_NAME-}" ]]; then
  url="https://${CODESPACE_NAME}-${SHOP_PORT}.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}"
else
  url="http://localhost:${SHOP_PORT}"
fi

echo "==> Waiting for the database connection"
for _ in $(seq 1 60); do
  wp db check >/dev/null 2>&1 && break
  sleep 2
done

if wp core is-installed >/dev/null 2>&1; then
  echo "==> WordPress already installed: nothing to do"
else
  echo "==> Installing WordPress at $url"
  wp core install --url="$url" --title="SESAME Shop" \
    --admin_user=admin --admin_password="$SHOP_ADMIN_PASSWORD" \
    --admin_email=admin@example.com --skip-email
fi

echo "==> Activating WooCommerce"
wp plugin activate woocommerce

echo
echo "Shop ready: $url  (admin / the SHOP_ADMIN_PASSWORD in your .env)"
