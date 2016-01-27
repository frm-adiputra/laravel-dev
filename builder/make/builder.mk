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

SERVICES=\
	db \
	db-admin \
	web

VOLUMES=\
	db-volume

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

DOCKERFILES=$(addsuffix /Dockerfile,$(addprefix $(BUILD_DIR)/docker/, \
	web \
))

# ordering is IMPORTANT!
DOCKER_IMAGES=$(addprefix $(BASENAME)/$(PROJECT)-, \
	web \
)

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
	clean

$(COMPOSE_BIN):
	$(COMPOSE_CURL) > "$@"
	chmod +x $@

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

clean:
	$(call infoblue,stopping containers: $(SERVICES) $(VOLUMES))
	@$(COMPOSE_SERVICES_CMD) stop $(SERVICES) $(VOLUMES)
	$(call infoblue,removing containers: $(SERVICES) $(VOLUMES))
	@$(COMPOSE_SERVICES_CMD) rm -v --force $(SERVICES) $(VOLUMES)
	$(call infoblue,removing dirs: $(BUILD_DIR))
	@rm -rf $(BUILD_DIR)


#################
# Initialization
#################

# GENERATED=$(addprefix $(BUILD_DIR)/, \
# 	docker/web/Dockerfile \
# 	docker/init-laravel/Dockerfile \
# 	docker/shell/Dockerfile \
# 	docker/volumes.yml \
# 	info.md \
# )
#
# # ordering is IMPORTANT!
# DOCKER_IMAGES=$(addprefix $(BASENAME)/$(PROJECT)-, \
# 	web \
# 	init-laravel \
# 	shell \
# )
#
# VOLUMES=$(addprefix $(PROJECT)-, \
# 	db-volume \
# )
#
# .PHONY: $(DOCKER_IMAGES)
#
# init: $(GENERATED) $(DOCKER_IMAGES) $(PROJECT_SRC)
#
# $(PROJECT_SRC):
# 	$(call infoblue,generating project source code)
# 	@-docker run -it --rm \
# 		-v $(ROOT)/src:/home/devuser/src \
# 		$(BASENAME)/$(PROJECT)-init-laravel
#
# $(GENERATED): $(BUILD_DIR)/%: $(TMPL_DIR)/%
# 	$(call infoblue,generating $*)
# 	@mkdir -p $(dir $@)
# 	@$(MO) "$<" > "$@"
#
# $(DOCKER_IMAGES): $(BASENAME)/$(PROJECT)-%: $(BUILD_DIR)/docker/%
# 	$(call infoblue,building docker image $@)
# 	@docker build -t $@ $<
#
# #################
# # Working tasks
# #################
#
# shell:
# 	@docker run -it --rm \
# 		--hostname="$(PROJECT)-shell" \
# 		-v $(ROOT)/src:/home/devuser/src \
# 		-p $(WEBPORT):8080 \
# 		$(BASENAME)/$(PROJECT)-shell
#
# web:
# 	$(call infoblue,starting web server http://localhost:$(WEBPORT) $@)
# 	@docker run -it --rm \
# 		-v $(ROOT)/src:/home/devuser/src \
# 		-p $(WEBPORT):8080 \
# 		$(BASENAME)/$(PROJECT)-web
#
# ##################
# # Additional tasks
# ##################
#
# info:
# 	@cat $(BUILD_DIR)/info.md
#
# remove-images:
# 	@docker rmi $(DOCKER_IMAGES)
#
# create-volumes:
# 	@docker-compose -f $(BUILD_DIR)/docker/volumes.yml up
