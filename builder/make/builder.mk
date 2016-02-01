include builder/make/helpers.mk

include builder/make/env-dev.mk
export MYSQL_ROOT_PASSWORD

# UID and GID of owner of src directory
UID=$(shell stat -c "%u" src)
GID=$(shell stat -c "%g" src)

# Check required variables
$(call check_defined, UID, user UID not set)
$(call check_defined, GID, user GID not set)
$(call check_defined, PROJECT, project name not set)
$(call check_defined, BASENAME, base path for docker image name not set)
$(call check_defined, WEBPORT, port for application web server not set)
$(call check_defined, DBADMINPORT, port for phpmyadmin web server not set)

ROOT=$(shell pwd)
MO=$(ROOT)/builder/scripts/mo
BUILD_DIR=$(ROOT)/.build
TMPL_DIR=$(ROOT)/builder/templates
SRC_DIR=$(ROOT)/src
PROJECT_SRC=src/$(PROJECT)

DB_IMAGE=mariadb:10.1
DB_ADMIN_IMAGE=nazarpc/phpmyadmin
VOLUME_IMAGE=busybox
COMPOSER_IMAGE=frma/baseimage-composer

IMAGES=\
	$(DB_IMAGE) \
	$(DB_ADMIN_IMAGE) \
	$(VOLUME_IMAGE) \
	$(COMPOSER_IMAGE)

export UID
export GID
export PROJECT
export BASENAME
export WEBPORT
export DBADMINPORT
export ROOT
export BUILD_DIR
export SRC_DIR
export MYSQL_DATABASE
export MYSQL_USER
export MYSQL_PASSWORD
export DB_IMAGE
export DB_ADMIN_IMAGE
export VOLUME_IMAGE
export COMPOSER_IMAGE

SERVICES=\
	db \
	db-admin \
	web

VOLUMES=\
	db-volume

PULL_IMAGES:=$(subst :,..,$(IMAGES))

COMPOSE_VERSION=1.5.2
COMPOSE_CURL=curl -L https://github.com/docker/compose/releases/download/$(COMPOSE_VERSION)/docker-compose-`uname -s`-`uname -m`
COMPOSE_BIN=$(ROOT)/builder/scripts/docker-compose-$(COMPOSE_VERSION)

COMPOSE_DIR=$(ROOT)/builder/compose

# ordering is IMPORTANT!
COMPOSE_FILES=$(addprefix $(COMPOSE_DIR)/, \
	services.yml \
	volumes.yml \
	names.yml \
	env-dev.yml \
)

COMPOSE_CMD=$(COMPOSE_BIN) --project-name $(PROJECT)
COMPOSE_SERVICES_CMD=$(COMPOSE_CMD) $(addprefix -f , $(COMPOSE_FILES))

GENERATED=$(addprefix $(BUILD_DIR)/, \
	info.md \
)

# ordering is IMPORTANT!
DOCKERFILES=$(addsuffix /Dockerfile,$(addprefix $(BUILD_DIR)/docker/, \
	web \
))

BUILDER_FILES=\
	Makefile \
	builder/make/builder.mk \
	builder/make/helpers.mk \
	builder/make/env-dev.mk

### TARGETS

.DEFAULT_GOAL := start

.PHONY: \
	prepare \
	start \
	info \
	app-shell \
	db-shell \
	mysql-shell \
	volumes \
	rm-volumes \
	clean \
	$(PULL_IMAGES)

$(COMPOSE_BIN):
	$(COMPOSE_CURL) > "$@"
	chmod +x $@

$(PULL_IMAGES):
	$(call infoblue,pulling $(subst ..,:,$@))
	@docker pull $(subst ..,:,$@)

$(DOCKERFILES): $(BUILDER_FILES) $(GENERATED)

$(DOCKERFILES): $(BUILD_DIR)/docker/%/Dockerfile: $(TMPL_DIR)/docker/%/Dockerfile
	$(call infoblue,generating $*/Dockerfile)
	@mkdir -p $(dir $@)
	@$(MO) "$<" > "$@"
	$(call infoblue,building docker image $(BASENAME)/$(PROJECT)-$*)
	docker build -t $(BASENAME)/$(PROJECT)-$* $(dir $@)

$(GENERATED): $(BUILDER_FILES)

$(GENERATED): $(BUILD_DIR)/%: $(TMPL_DIR)/%
	$(call infoblue,generating $*)
	@mkdir -p $(dir $@)
	@$(MO) "$<" > "$@"

$(PROJECT_SRC):
	$(call infoblue,generating project source code)
	@$(COMPOSE_CMD) -f $(COMPOSE_DIR)/init.yml up --force-recreate
	@-$(COMPOSE_CMD) -f $(COMPOSE_DIR)/init.yml rm -v --force

prepare: $(COMPOSE_BIN) $(DOCKERFILES)

start: prepare volumes $(PROJECT_SRC)
	$(call infoblue,starting services: $(SERVICES))
	@$(COMPOSE_SERVICES_CMD) up --force-recreate $(SERVICES)

info:
	$(call infoblue,INFO)
	@echo "App web server       : http://localhost:$(WEBPORT)"
	@echo "phpMyAdmin web server: http://localhost:$(DBADMINPORT)"

app-shell:
	$(call infoblue,opening shell in container $(BASENAME)_$(PROJECT)-web)
	@docker exec -it $(BASENAME)_$(PROJECT)-web bash

db-shell:
	$(call infoblue,opening shell in container $(BASENAME)_$(PROJECT)-db)
	@docker exec -it $(BASENAME)_$(PROJECT)-db bash

mysql-shell:
	$(call infoblue,opening shell in container $(BASENAME)_$(PROJECT)-db)
	@docker exec -it $(BASENAME)_$(PROJECT)-db mysql -u root -p$(MYSQL_ROOT_PASSWORD) $(MYSQL_DATABASE)

volumes:
	$(call infoblue,starting volume containers: $(VOLUMES))
	@$(COMPOSE_SERVICES_CMD) up $(VOLUMES)

rm-volumes:
	@$(COMPOSE_SERVICES_CMD) rm -v --force $(VOLUMES)

update-images: $(PULL_IMAGES)

clean:
	$(call infoblue,stopping containers: $(SERVICES) $(VOLUMES))
	@$(COMPOSE_SERVICES_CMD) stop $(SERVICES) $(VOLUMES)
	$(call infoblue,removing containers: $(SERVICES) $(VOLUMES))
	@$(COMPOSE_SERVICES_CMD) rm -v --force $(SERVICES) $(VOLUMES)
	$(call infoblue,removing dirs: $(BUILD_DIR))
	@rm -rf $(BUILD_DIR)
