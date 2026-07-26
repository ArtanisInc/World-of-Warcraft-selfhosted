.PHONY: init build up down restart logs status console backup health metrics diagnose watch bots-help clean-logs account gm ahbot-bootstrap ahbot update clean

init:
	./scripts/init-env.sh

build:
	docker compose build

up:
	docker compose up -d --build

down:
	docker compose down

restart:
	docker compose restart authserver worldserver

logs:
	docker compose logs -f --tail=200 authserver worldserver

status:
	docker compose ps

console:
	docker attach $$(docker compose ps -q worldserver)

backup:
	./scripts/backup-db.sh

health:
	./scripts/healthcheck.sh

metrics:
	./scripts/metrics-snapshot.sh

diagnose:
	./scripts/diagnose.sh

watch:
	./scripts/watch-services.sh "$(or $(INTERVAL),30)"

bots-help:
	./scripts/playerbots-help.sh

clean-logs:
	./scripts/clean-logs.sh

account:
	./scripts/create-account.sh "$(ACCOUNT)" "$(PASS)"

gm:
	./scripts/set-gm.sh "$(ACCOUNT)" "$(LEVEL)" "$(or $(REALM),-1)"

ahbot-bootstrap:
	./scripts/bootstrap-ahbot.sh "$(ACCOUNT)" "$(PASS)"

ahbot:
	./scripts/setup-ahbot.sh "$(GUIDS)"

update:
	docker compose build --pull --no-cache
	docker compose up -d

clean:
	docker compose down --remove-orphans
