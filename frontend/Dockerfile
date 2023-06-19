# pull official base image
FROM node:lts-bookworm@sha256:4a55308cc855cba1a925d19ae4e45838741dad2fd7bb8949a93b2a0f2ae339e3 AS dev

ARG VITE_OCAML_BENCH_GRAPHQL_URL
ARG VITE_OCAML_BENCH_PIPELINE_URL
ARG VITE_CURRENT_BENCH_VERSION

ENV VITE_OCAML_BENCH_GRAPHQL_URL=$VITE_OCAML_BENCH_GRAPHQL_URL
ENV VITE_OCAML_BENCH_PIPELINE_URL=$VITE_OCAML_BENCH_PIPELINE_URL
ENV VITE_CURRENT_BENCH_VERSION=$VITE_CURRENT_BENCH_VERSION

RUN apt-get update \
    && apt-get install --no-install-recommends --assume-yes \
    screen \
    && rm -r /var/lib/apt/lists /var/cache/apt

# set working directory
WORKDIR /app

COPY ./pipeline/cb-schema/schema.ml /pipeline/cb-schema/schema.ml
COPY ./pipeline/cb-schema/json.ml /pipeline/cb-schema/json.ml

# Build frontend code for production
FROM dev AS builder

COPY ./frontend/package.json frontend/yarn.lock /app/
RUN yarn install

# add app
COPY ./frontend/. /app/

RUN echo "VITE_OCAML_BENCH_GRAPHQL_URL=${VITE_OCAML_BENCH_GRAPHQL_URL}" > /app/.env
RUN echo "VITE_OCAML_BENCH_PIPELINE_URL=${VITE_OCAML_BENCH_PIPELINE_URL}" >> /app/.env
RUN echo "VITE_CURRENT_BENCH_VERSION=${VITE_CURRENT_BENCH_VERSION}" >> /app/.env

RUN yarn build
RUN yarn bundle

# build nginx image with static files built previously
FROM nginx:stable-alpine3.17@sha256:5e1ccef1e821253829e415ac1e3eafe46920aab0bf67e0fe8a104c57dbfffdf7

COPY ./frontend/nginx.conf /etc/nginx/nginx.conf

## Remove default nginx index page
RUN rm -rf /usr/share/nginx/html/*

COPY --from=builder /app/dist /usr/share/nginx/html

ENTRYPOINT ["nginx", "-g", "daemon off;"]
