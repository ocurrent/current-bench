# pull official base image
FROM node:13.12.0-alpine as builder

# set working directory
WORKDIR /app

# install app dependencies
COPY package.json ./

RUN npm install --save err && npm config set registry https://skimdb.npmjs.com/registry && npm install --silent

# add app
COPY . ./

RUN npm run build

FROM nginx:alpine

#!/bin/sh

COPY ./.nginx/nginx.conf /etc/nginx/nginx.conf

## Remove default nginx index page
RUN rm -rf /usr/share/nginx/html/*

COPY --from=builder /app/build /usr/share/nginx/html

EXPOSE 3000 82

ENTRYPOINT ["nginx", "-g", "daemon off;"]

