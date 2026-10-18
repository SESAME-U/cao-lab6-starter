#!/usr/bin/env bash
# Autograder, Lab 6. Usage: tests/run.sh compose|compose-run|stack|swarm|all
# Runs on the GitHub runner (Docker available) or in your Codespace.
# Your own Compose project (lab6) and stack (cao) are left alone: the tests
# use the names lab6test and caotest, but they need ports 8080 and 8090,
# so stop your own app first (make down, make stack-down).
# Editing this file does not change your grade: the instructor's copy is used.
set -uo pipefail
cd "$(dirname "$0")/.."

export COMPOSE_PROJECT_NAME=lab6test
TSTACK=caotest
fails=0
pass() { printf '  \033[32mPASS\033[0m %s\n' "$1"; }
fail() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; fails=$((fails + 1)); }
check() { local msg="$1"; shift; if "$@" >/dev/null 2>&1; then pass "$msg"; else fail "$msg"; fi; }

# The tests use .env.example; your own .env is put back afterwards.
fresh_env() {
  if [[ -f .env && ! -f .env.student ]]; then mv .env .env.student; fi
  cp .env.example .env
  if [[ -d secrets && ! -d .secrets.student ]]; then mv secrets .secrets.student; fi
  trap restore_env EXIT
}
restore_env() {
  rm -f .env; [[ -f .env.student ]] && mv .env.student .env
  rm -rf secrets; [[ -d .secrets.student ]] && mv .secrets.student secrets
  return 0
}

ports_free() {
  local busy=""
  for p in 8080 8090; do
    if curl -s -o /dev/null --max-time 2 "http://localhost:$p/"; then busy="$busy $p"; fi
  done
  if [[ -n $busy ]]; then
    echo "Ports in use:$busy. Stop your own app first: make down, make stack-down."
    return 1
  fi
}

# compose.yaml as Compose understands it, in JSON.
compose_json() { docker compose config --format json 2>/dev/null; }
py() { python3 -c "$1"; }

stage_compose() {
  echo "== compose: the file"
  fresh_env
  check "compose.yaml is valid (docker compose config)" docker compose config -q
  local j; j=$(compose_json) || { fail "compose.yaml can be read"; return; }
  export J="$j"
  check "two services, db and shop" py "import json,os; s=json.loads(os.environ['J'])['services']; assert {'db','shop'} <= set(s)"
  check "db uses mariadb:12.3.3-noble, shop builds from the Dockerfile" \
    py "import json,os; s=json.loads(os.environ['J'])['services']; assert s['db']['image']=='mariadb:12.3.3-noble' and 'build' in s['shop']"
  check "db has a healthcheck, shop waits for it (depends_on condition service_healthy)" \
    py "import json,os; s=json.loads(os.environ['J'])['services']; assert s['db'].get('healthcheck',{}).get('test'); assert s['shop']['depends_on']['db']['condition']=='service_healthy'"
  check "db publishes no port, shop publishes 8080" \
    py "import json,os; s=json.loads(os.environ['J'])['services']; assert not s['db'].get('ports'); assert any(str(p.get('published'))=='8080' and int(p['target'])==80 for p in s['shop']['ports'])"
  check "named volumes db-data on /var/lib/mysql and shop-uploads on wp-content/uploads" \
    py "import json,os; d=json.loads(os.environ['J']); s=d['services']; v=lambda x:{(m.get('source'),m['target']) for m in s[x].get('volumes',[])}; assert ('db-data','/var/lib/mysql') in v('db') and ('shop-uploads','/var/www/html/wp-content/uploads') in v('shop'); assert {'db-data','shop-uploads'} <= set(d.get('volumes',{}))"
  check "both services on one user-defined network, restart unless-stopped" \
    py "import json,os; s=json.loads(os.environ['J'])['services']; n=lambda x:set(s[x].get('networks',{})); assert n('db') & n('shop') - {'default'}; assert s['db'].get('restart')==s['shop'].get('restart')=='unless-stopped'"
  check "no password written in compose.yaml: values come from .env" \
    bash -c "! grep -E '^[[:space:]]*-?[[:space:]]*[A-Z_]*PASSWORD[[:space:]]*[:=][[:space:]]*[^\$[:space:]]' compose.yaml"
  restore_env; trap - EXIT
}

stage_compose_run() {
  echo "== compose: run it"
  ports_free || { fail "ports 8080 and 8090 are free"; return; }
  fresh_env
  sed -i "s/^SHOP_IMAGE=.*/SHOP_IMAGE=cao-shop:test/" .env
  docker compose down --volumes >/dev/null 2>&1
  if docker compose up -d --build --wait >/tmp/compose-up.log 2>&1; then pass "docker compose up --wait: db and shop healthy"
  else fail "docker compose up --wait: db and shop healthy (see /tmp/compose-up.log)"; tail -20 /tmp/compose-up.log; docker compose down --volumes >/dev/null 2>&1; return; fi
  if bash scripts/install-shop.sh compose >/tmp/install.log 2>&1; then pass "scripts/install-shop.sh compose"
  else fail "scripts/install-shop.sh compose (see /tmp/install.log)"; tail -20 /tmp/install.log; fi
  local shop; shop=$(docker compose ps -q shop)
  check "site title is SESAME Shop, WooCommerce active" \
    bash -c "[ \"\$(docker exec -u www-data $shop wp option get blogname)\" = 'SESAME Shop' ] && docker exec -u www-data $shop wp plugin is-active woocommerce"
  check "http://localhost:8080/wp-login.php answers 200" \
    bash -c "[ \"\$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/wp-login.php)\" = 200 ]"
  docker compose down >/dev/null 2>&1
  if docker compose up -d --wait >/dev/null 2>&1; then pass "docker compose down, then up again"; else fail "docker compose down, then up again"; fi
  shop=$(docker compose ps -q shop)
  check "after down and up, the shop is still installed (data in volumes)" \
    bash -c "[ \"\$(docker exec -u www-data $shop wp option get blogname)\" = 'SESAME Shop' ]"
  docker compose down --volumes >/dev/null 2>&1
  restore_env; trap - EXIT
}

stage_stack() {
  echo "== stack: the file"
  [[ -f stack.yml ]] || { fail "stack.yml exists"; return; }
  export STACKFILE=stack.yml
  local load="import yaml,os; d=yaml.safe_load(open(os.environ['STACKFILE'])); s=d['services']"
  check "stack.yml is valid YAML with services hello, db and shop" py "$load; assert {'hello','db','shop'} <= set(s)"
  check "hello: image cao-hello:\${HELLO_VERSION...}, 3 replicas, port 8090" \
    py "$load; h=s['hello']; assert h['image'].startswith('cao-hello:\${HELLO_VERSION'); assert h['deploy']['replicas']==3; assert any(str(p).startswith('8090:80') or (isinstance(p,dict) and int(p.get('published',0))==8090) for p in h['ports'])"
  check "hello: rolling update one at a time, start-first, rollback on failure" \
    py "$load; u=s['hello']['deploy']['update_config']; assert u['parallelism']==1 and u['order']=='start-first' and u['failure_action']=='rollback'"
  check "shop: image cao-shop:1.0, at least 2 replicas, port 8080" \
    py "$load; h=s['shop']; assert h['image']=='cao-shop:1.0' and h['deploy']['replicas']>=2; assert any(str(p).startswith('8080:80') or (isinstance(p,dict) and int(p.get('published',0))==8080) for p in h['ports'])"
  check "passwords only as secrets: *_PASSWORD_FILE=/run/secrets/..., no plain *_PASSWORD" \
    py "$load; e=lambda x: s[x].get('environment',{}); assert all(not k.endswith('PASSWORD') for x in ('db','shop') for k in e(x)); assert e('db')['MARIADB_PASSWORD_FILE'].startswith('/run/secrets/') and e('db')['MARIADB_ROOT_PASSWORD_FILE'].startswith('/run/secrets/') and e('shop')['WORDPRESS_DB_PASSWORD_FILE'].startswith('/run/secrets/')"
  check "secrets db_password and db_root_password come from files in secrets/" \
    py "$load; x=d['secrets']; assert x['db_password']['file'].lstrip('./').startswith('secrets/') and x['db_root_password']['file'].lstrip('./').startswith('secrets/'); assert 'db_password' in str(s['shop']['secrets']) and 'db_root_password' in str(s['db']['secrets'])"
  check "two overlay networks: hello on one, db and shop on the other" \
    py "$load; n=d['networks']; assert all(v.get('driver')=='overlay' for v in n.values()) and len(n)>=2; net=lambda x:set(s[x]['networks']); assert net('db') & net('shop') and not (net('hello') & net('db'))"
  check "named volumes db-data and shop-uploads" \
    py "$load; v=lambda x:[str(m).split(':')[0] for m in s[x].get('volumes',[])]; assert 'db-data' in v('db') and 'shop-uploads' in v('shop')"
}

stage_swarm() {
  echo "== swarm: run the stack"
  ports_free || { fail "ports 8080 and 8090 are free"; return; }
  fresh_env
  local created=0
  if ! docker info --format '{{.Swarm.LocalNodeState}}' | grep -q active; then
    for _ in 1 2 3; do
      docker swarm init --advertise-addr 127.0.0.1 >/dev/null 2>&1 && { created=1; break; }
      sleep 3
    done
  fi
  check "this node is a swarm manager" bash -c "docker node ls >/dev/null"
  echo "  building cao-shop:1.0, cao-hello:1 and cao-hello:2 ..."
  docker build -q -t cao-shop:1.0 . >/dev/null \
    && docker build -q -t cao-hello:1 --build-arg APP_VERSION=1 hello >/dev/null \
    && docker build -q -t cao-hello:2 --build-arg APP_VERSION=2 hello >/dev/null \
    || { fail "images build"; return; }
  bash scripts/secrets.sh >/dev/null
  if HELLO_VERSION=1 docker stack deploy --detach=false -c stack.yml "$TSTACK" >/tmp/stack-up.log 2>&1; then pass "docker stack deploy converges"
  else fail "docker stack deploy converges (see /tmp/stack-up.log)"; tail -20 /tmp/stack-up.log; cleanup_swarm $created; return; fi
  check "hello runs 3 replicas" bash -c "[ \"\$(docker service ls -f name=${TSTACK}_hello --format '{{.Replicas}}')\" = 3/3 ]"
  local hosts
  hosts=$(for _ in $(seq 1 30); do curl -fsS --max-time 2 http://localhost:8090/ ; done | awk '{print $3}' | sort -u | wc -l)
  check "the routing mesh spreads requests over at least 2 replicas (saw $hosts)" test "$hosts" -ge 2
  if STACK=$TSTACK bash scripts/install-shop.sh stack >/tmp/install-stack.log 2>&1; then pass "the shop installs in the stack"
  else fail "the shop installs in the stack (see /tmp/install-stack.log)"; tail -20 /tmp/install-stack.log; fi
  check "the shop answers on 8080 through the mesh" \
    bash -c "[ \"\$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://localhost:8080/wp-login.php)\" = 200 ]"
  local dbc; dbc=$(docker ps -q -f "label=com.docker.swarm.service.name=${TSTACK}_db" | head -1)
  check "the db container gets its password from /run/secrets, not from its environment" \
    bash -c "docker exec $dbc test -s /run/secrets/db_password && ! docker inspect -f '{{json .Config.Env}}' $dbc | grep -qE 'MARIADB_(ROOT_)?PASSWORD='"
  # Rolling update under load: no request may fail.
  rm -f /tmp/hammer.log
  bash scripts/hammer.sh 0 >/tmp/hammer.log 2>&1 &
  local hp=$!
  sleep 2
  HELLO_VERSION=2 docker stack deploy --detach=false -c stack.yml "$TSTACK" >/tmp/stack-update.log 2>&1
  sleep 3
  kill -INT $hp 2>/dev/null; wait $hp 2>/dev/null
  local failed; failed=$(grep -c FAILED /tmp/hammer.log)
  check "rolling update to cao-hello:2 with no failed request (failed: $failed)" test "$failed" -eq 0
  check "after the update, every replica answers version 2" \
    bash -c "for _ in \$(seq 1 12); do curl -fsS http://localhost:8090/ | grep -q 'version 2' || exit 1; done"
  cleanup_swarm $created
  restore_env; trap - EXIT
}

cleanup_swarm() {
  docker stack rm "$TSTACK" >/dev/null 2>&1
  for _ in $(seq 1 30); do [[ -z $(docker ps -q -f "label=com.docker.stack.namespace=$TSTACK") ]] && break; sleep 1; done
  sleep 3
  docker volume rm "${TSTACK}_db-data" "${TSTACK}_shop-uploads" >/dev/null 2>&1
  [[ ${1:-0} -eq 1 ]] && docker swarm leave --force >/dev/null 2>&1
  return 0
}

case "${1:-all}" in
  compose) stage_compose ;;
  compose-run) stage_compose_run ;;
  stack) stage_stack ;;
  swarm) stage_swarm ;;
  all) stage_compose; stage_compose_run; stage_stack; stage_swarm ;;
  *) echo "usage: $0 compose|compose-run|stack|swarm|all"; exit 2 ;;
esac

echo
if [[ $fails -eq 0 ]]; then echo "All checks passed."; else echo "$fails check(s) failed."; fi
exit $(( fails > 0 ))
