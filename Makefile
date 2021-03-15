.PHONY: start-production
start-production:
	docker-compose \
		--project-name="current-bench" \
		--file=./environments/production.docker-compose.yaml \
		--env-file=production.env \
		up \
		--detach

.PHONY: stop-production
stop-production:
	docker-compose \
		--project-name="current-bench" \
		--file=./environments/production.docker-compose.yaml \
		down

.PHONY: start-development
start-development:
	docker-compose \
		--project-name="current-bench" \
		--file=./environments/development.docker-compose.yaml \
		--env-file=development.env \
		up \
		--remove-orphans
