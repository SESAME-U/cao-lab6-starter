.PHONY: help check build build-hello up install ps logs down down-all scale-test \
        swarm-init nodes secrets stack-up stack-install stack-ps hammer update rollback \
        stack-down swarm-leave test clean

STACK ?= cao
V ?= 1
COMPOSE = docker compose

help:
	@echo "Part A-B, Compose"
	@echo "  make build          build the shop image (cao-shop:1.0)"
	@echo "  make up             docker compose up: db and shop, wait until healthy"
	@echo "  make install        install WordPress and WooCommerce in the Compose shop"
	@echo "  make ps / logs      the project's containers / follow the shop logs"
	@echo "  make down           stop and remove the containers, keep the volumes"
	@echo "  make down-all       the same AND delete the volumes (data lost)"
	@echo "Part C-E, Swarm"
	@echo "  make swarm-init     turn this Codespace into a one-node swarm"
	@echo "  make build-hello V=1   build cao-hello:1 (V=2 for version 2)"
	@echo "  make secrets        write secrets/*.txt from .env"
	@echo "  make stack-up       docker stack deploy -c stack.yml $(STACK) (HELLO_VERSION=$(V))"
	@echo "  make stack-install  install WordPress in one task of $(STACK)_shop"
	@echo "  make stack-ps       services and tasks of the stack"
	@echo "  make hammer         one request to the hello service every 0.2 s (Ctrl+C)"
	@echo "  make update V=2     rolling update of hello to cao-hello:2"
	@echo "  make rollback       go back to the previous hello version"
	@echo "  make stack-down     remove the stack (volumes and secrets files stay)"
	@echo "  make swarm-leave    leave the swarm"
	@echo "Grading"
	@echo "  make test           run the autograder checks (stop your own app first)"
	@echo "  make clean          remove everything this lab created"

check:
	@bash scripts/check.sh

build:
	docker build -t cao-shop:1.0 .

build-hello:
	docker build -t cao-hello:$(V) --build-arg APP_VERSION=$(V) hello

up:
	$(COMPOSE) up -d --wait

install:
	@bash scripts/install-shop.sh compose

ps:
	$(COMPOSE) ps

logs:
	$(COMPOSE) logs -f shop

down:
	$(COMPOSE) down

down-all:
	$(COMPOSE) down --volumes

swarm-init:
	@docker info --format '{{.Swarm.LocalNodeState}}' | grep -q active \
	  && echo "Already a swarm node." \
	  || docker swarm init --advertise-addr 127.0.0.1

nodes:
	docker node ls

secrets:
	@bash scripts/secrets.sh

stack-up:
	HELLO_VERSION=$(V) docker stack deploy --detach=false -c stack.yml $(STACK)

stack-install:
	@bash scripts/install-shop.sh stack

stack-ps:
	docker stack services $(STACK)
	@echo
	docker stack ps $(STACK) --format 'table {{.Name}}\t{{.Image}}\t{{.CurrentState}}\t{{.Error}}'

hammer:
	@bash scripts/hammer.sh

update:
	HELLO_VERSION=$(V) docker stack deploy --detach=false -c stack.yml $(STACK)

rollback:
	docker service rollback $(STACK)_hello

stack-down:
	-docker stack rm $(STACK)

swarm-leave:
	-docker swarm leave --force

test:
	@bash tests/run.sh all

clean: down-all stack-down
	@sleep 5
	-docker volume rm $(STACK)_db-data $(STACK)_shop-uploads
	-docker rmi cao-hello:1 cao-hello:2
	rm -rf secrets
