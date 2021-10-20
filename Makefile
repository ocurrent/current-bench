
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
		exec frontend bash -c '\
URL=$$(echo "$${VITE_OCAML_BENCH_GRAPHQL_URL/localhost/graphql-engine}"); \
yarn -s gq "$${URL}" -H "X-Hasura-Admin-Secret: $${HASURA_GRAPHQL_ADMIN_SECRET}" --introspect --format=json > graphql_schema.json'


.PHONY: bench
bench:
	@cd ./local-test-repo/ && make -s bench
