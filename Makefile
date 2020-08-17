SERVICE_NAME := rxpy-web
.DEFAULT_GOAL := help
SHELL := /bin/bash
BUILD_DATE := $(shell eval date -u +"%Y-%m-%dT%H:%M:%SZ")
VCS_REF := $(shell eval git rev-parse --short HEAD)
COMPOSE_ALL_SVC := docker-compose -f docker-compose.yml
EXEC_SERVICE := rxpy-web
DB_SERVICE := db

DOCKER_RUN_FE := docker run --rm -w="/app"
DOCKER_COMPOSE := docker-compose

ifeq (start,$(firstword $(MAKECMDGOALS)))
  # use the rest as arguments for "run"
  RUN_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
  # ...and turn them into do-nothing targets
  $(eval $(RUN_ARGS):;@:)
endif

help: ## print this help
		@# https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
		@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
		@echo ""
.PHONY: help

# set { "features": { "buildkit": true } } in /etc/docker/daemon.json for --target base, which
# will ignore frontend_devel stage.
# https://docs.docker.com/develop/develop-images/build_enhancements/
build-pybase: ## build python-3.6 base image
			@docker build --network=host . -f Dockerfile \
				--build-arg JFROG_USERNAME --build-arg JFROG_ACCESS_TOKEN \
				--build-arg VCS_REF=$(VCS_REF) --build-arg BUILD_DATE=$(BUILD_DATE) \
				--build-arg HTTP_PROXY=${HTTP_PROXY} --build-arg HTTPS_PORXY=${HTTPS_PORXY} \
				--build-arg HTTP_PROXY_DOCKER=${HTTP_PROXY_DOCKER} \
				-t "${SERVICE_NAME}/builder_base:latest" --target base
.PHONY: build-pybase

devel: ## Combine python code with frontend bundle for test
			@docker build --network=host . -f Dockerfile \
				--build-arg JFROG_USERNAME --build-arg JFROG_ACCESS_TOKEN \
				--build-arg VCS_REF=$(VCS_REF) --build-arg BUILD_DATE=$(BUILD_DATE) \
				--build-arg HTTP_PROXY=${HTTP_PROXY} --build-arg HTTPS_PORXY=${HTTPS_PORXY} \
				--build-arg HTTP_PROXY_DOCKER=${HTTP_PROXY_DOCKER} \
				-t "${SERVICE_NAME}/devel:latest" --target devel
.PHONY: devel

up: ## run a dev site via docker-compose
			@$(DOCKER_COMPOSE) up --build -d
.PHONY: up

up-tail: ## run a dev site via docker-compose, but tail it this time
			@$(DOCKER_COMPOSE) up --build
.PHONY: up-tail

down:  ## tear down and delete the docker-compose dev site
			@$(COMPOSE_ALL_SVC) down -v
.PHONY: down

shell: ## run a bash shell using the image
			@${DOCKER_COMPOSE} run --rm --entrypoint "bash" ${EXEC_SERVICE}
.PHONY: shell

lock:  ## Run pipenv lock
			pipenv lock
.PHONY: lock

debug:  ## debug pdb
			@$(DOCKER_COMPOSE) run --service-ports --rm ${EXEC_SERVICE}
.PHONY: debug
