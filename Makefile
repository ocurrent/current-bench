
.PHONY: start-production
start-production:
	docker-compose \
		--project-name="current-bench" \
		--file=./environments/production.docker-compose.yaml \
		--env-file=./environments/production.env \
		up \
		--detach

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
		--env-file=./development.env \
		up \
		--remove-orphans \
		--build
