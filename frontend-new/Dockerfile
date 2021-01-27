# pull official base image
FROM node:lts AS builder

# set working directory
WORKDIR /app

COPY package.json yarn.lock /app/
RUN yarn install

# add app
COPY . /app/

RUN yarn --verbose build

# build nginx image with static files built previously
FROM nginx:stable-alpine

COPY ./nginx.conf /etc/nginx/nginx.conf

## Remove default nginx index page
RUN rm -rf /usr/share/nginx/html/*

COPY --from=builder /app/build /usr/share/nginx/html

ENTRYPOINT ["nginx", "-g", "daemon off;"]

