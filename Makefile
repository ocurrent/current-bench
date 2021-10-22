.PHONY: start-production
start-production:
	docker-compose \
		--project-name="current-bench" \
		--file=./environments/production.docker-compose.yaml \
		--env-file=./environments/production.env \
		up \
		--detach \
		--build

.PHONY: stop-production
stop-production:
	docker-compose \
		--project-name="current-bench" \
		--file=./environments/production.docker-compose.yaml \
		--env-file=./environments/production.env \
		down

# Make sure the fake testing repo is initialised.
./local-test-repo/.git:
	cd ./local-test-repo/ && git init && git add . && git commit -m "Initial commit."

.PHONY: start-development
start-development: ./local-test-repo/.git
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
