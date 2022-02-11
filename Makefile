.PHONY: start-production
start-production: update-version-info validate-env
	docker-compose \
		--project-name="current-bench" \
		--file=./environments/production.docker-compose.yaml \
		--env-file=./environments/production.env \
		up \
		--detach \
		--build

.PHONY: build-production
build-production:
	docker-compose \
		--project-name="current-bench" \
		--file=./environments/production.docker-compose.yaml \
		--env-file=./environments/production.env \
		build

.PHONY: stop-production
stop-production:
	docker-compose \
		--project-name="current-bench" \
		--file=./environments/production.docker-compose.yaml \
		--env-file=./environments/production.env \
		down

.PHONY: redeploy-production
redeploy-production: \
	build-production \
	stop-production \
	start-production

# Validate docker-compose env files
.PHONY: validate-env
validate-env:
	./scripts/validate-env.sh

# Make sure the fake testing repo is initialised.
./local-test-repo/.git:
	cd ./local-test-repo/ && git init && git add . && git commit -m "Initial commit."

# Update current bench version
.PHONY: update-version-info
update-version-info:
	./scripts/version.sh

# Clean the fake testing repo
.PHONY: clean-local-test-repo
clean-local-test-repo:
	cd ./local-test-repo/ && rm -rf .git/

.PHONY: start-development
start-development: ./local-test-repo/.git update-version-info validate-env
	docker-compose \
		--project-name="current-bench" \
		--file=./environments/development.docker-compose.yaml \
		--env-file=./environments/development.env \
		up \
		--remove-orphans \
		--build

.PHONY: stop-development
stop-development: ./local-test-repo/.git
	docker-compose \
		--project-name="current-bench" \
		--file=./environments/development.docker-compose.yaml \
		--env-file=./environments/development.env \
		down

.PHONY: update-graphql-schema
update-graphql-schema: ./local-test-repo/.git
	docker-compose \
		--project-name="current-bench" \
		--file=./environments/development.docker-compose.yaml \
		--env-file=./environments/development.env \
		exec frontend /app/scripts/update-graphql-schema.sh


.PHONY: rebuild-pipeline
rebuild-pipeline: ./local-test-repo/.git
	docker-compose \
		--project-name="current-bench" \
		--file=./environments/development.docker-compose.yaml \
		--env-file=./environments/development.env \
		up --detach --build pipeline

.PHONY: bench
bench:
	@cd ./local-test-repo/ && make -s bench

.PHONY: start-prometheus-alertmanager
start-prometheus-alertmanager:
	cd ./prometheus/ && \
	docker-compose --env-file=../environments/production.env up --detach

.PHONY: stop-prometheus-alertmanager
stop-prometheus-alertmanager:
	cd ./prometheus/ && \
	docker-compose --env-file=../environments/production.env down

.PHONY: start-node-exporter
start-node-exporter:
	./prometheus/scripts/start-node-exporter.sh --web.listen-address 0.0.0.0:10080
