# Lab 6 submission

Fill in every line marked `ANSWER:` (one to three sentences each). Write the answer on the same line, right after `ANSWER:`; for pasted output, add a short summary there and paste the output below. Push before the start of the week 10 session.

## Part A - Compose

1. Name two things your `compose.yaml` does that you wrote by hand in `scripts/up.sh` in Lab 5. What does `depends_on` with `condition: service_healthy` replace?
   ANSWER:

## Part B - operating the project

2. What did `docker compose up -d --scale shop=2` print, and why? What would you need in front of the shops to run two of them on one port?
   ANSWER:

## Part C - a first Swarm service

3. You removed one container of the service `hello-cli` with `docker rm -f`. Paste the lines of `docker service ps hello-cli` that show what happened. Who restarted it, and why?
   ANSWER:

## Part D - the stack

4. Paste the output of `docker exec <db container> ls -l /run/secrets`. Compared with Lab 5, where is the database password now, and why does `docker inspect` no longer show it?
   ANSWER:

5. Swarm ignores `depends_on`. What did `make stack-ps` show for the shop tasks while the database was starting, and what makes the stack converge anyway?
   ANSWER:

## Part E - rolling update

6. Paste the `make hammer` lines around the moment the version changed during `make update V=2`. Did any request fail? What does `order: start-first` do, and what would change with `stop-first`?
   ANSWER:

## Cleanup

- `make clean` and `make swarm-leave` done (yes/no): ANSWER:
