COMPOSE ?= ./scripts/compose.sh

.PHONY: init build up down restart logs status console backup health metrics diagnose watch bots-help clean-logs account gm ahbot-bootstrap ahbot update clean

init:
	./scripts/init-env.sh

build:
	$(COMPOSE) build

up:
	$(COMPOSE) up -d --build

down:
	$(COMPOSE) down

restart:
	$(COMPOSE) restart authserver worldserver

logs:
	$(COMPOSE) logs -f --tail=200 authserver worldserver

status:
	$(COMPOSE) ps

console:
	$(COMPOSE) attach worldserver

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
	$(COMPOSE) build --pull --no-cache
	$(COMPOSE) up -d

clean:
	$(COMPOSE) down --remove-orphans
