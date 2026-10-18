# Cloud Automation and Orchestration - Lab 6

SESAME University, Computer Engineering, ING5. Week 9: Docker Compose and Docker Swarm.

Your Lab 5 shop, declared instead of scripted: first as a Compose project on one host,
then as a Swarm stack with replicas, overlay networks, secrets and a rolling update
that never drops a request.

## Start

1. Open this repository in a Codespace, wait for `Toolbox ready`, run `make check`.
2. `cp .env.example .env`, change the three passwords.
3. Follow the Lab 6 guide.

## What you write

| File | Part |
| --- | --- |
| `compose.yaml` | A: the shop as a Compose project |
| `stack.yml` | D, E: the shop and the hello service as a Swarm stack |
| `SUBMISSION.md` | answers |

Given: the shop `Dockerfile` (the Lab 5 solution), the `hello/` service, the scripts and the Makefile (`make help`).

## Grading (10 points, autograded on every push)

| Check | Points |
| --- | --- |
| `compose.yaml`: services, healthcheck, depends_on, volumes, network, no password | 2 |
| Compose run: the shop installs, and survives `down` then `up` | 2 |
| `stack.yml`: replicas, rolling update settings, secrets, overlay networks | 2 |
| Swarm run: 3 hello replicas behind the mesh, the shop with secrets, an update with no failed request | 2 |
| `SUBMISSION.md` complete | 2 |

Run the same checks with `make test`, after stopping your own app (`make down`, `make stack-down`).

**Before you leave:** `make clean`, `make swarm-leave`, then stop your Codespace.
