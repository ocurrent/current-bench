# pull official base image
FROM node:lts AS builder

ARG VITE_OCAML_BENCH_GRAPHQL_URL

# set working directory
WORKDIR /app

COPY package.json yarn.lock /app/
RUN yarn install

# add app
COPY . /app/

RUN echo "VITE_OCAML_BENCH_GRAPHQL_URL=${VITE_OCAML_BENCH_GRAPHQL_URL}" > /app/.env

RUN yarn build
RUN yarn bundle

# build nginx image with static files built previously
FROM nginx:stable-alpine

COPY ./nginx.conf /etc/nginx/nginx.conf

## Remove default nginx index page
RUN rm -rf /usr/share/nginx/html/*

COPY --from=builder /app/dist /usr/share/nginx/html

ENTRYPOINT ["nginx", "-g", "daemon off;"]
