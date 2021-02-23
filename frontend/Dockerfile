# pull official base image
FROM node:lts AS builder

# set working directory
WORKDIR /app

# add app
COPY . /app/

RUN yarn install
RUN yarn build:re
RUN yarn vite build

# build nginx image with static files built previously
FROM nginx:stable-alpine

COPY ./nginx.conf /etc/nginx/nginx.conf

## Remove default nginx index page
RUN rm -rf /usr/share/nginx/html/*

COPY --from=builder /app/dist /usr/share/nginx/html

ENTRYPOINT ["nginx", "-g", "daemon off;"]

