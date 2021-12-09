FROM ocaml/opam:debian-ocaml-4.13 AS build

RUN sudo apt-get update && \
    sudo apt-get install -qq -yy \
    libffi-dev \
    m4 \
    pkg-config \
    libssl-dev \
    libgmp-dev \
    libpq-dev \
    graphviz \
    capnproto \
    libsqlite3-dev \
    libcapnp-dev \
    libev-dev \
    libsqlite3-dev

WORKDIR /mnt/project

# Build dependencies.
COPY --chown=opam:opam cb-worker.opam cb-worker.opam
RUN opam install -y --deps-only -t .
COPY --chown=opam . .
RUN sudo chown opam .

# Build the project.
RUN opam exec -- dune build --profile=release ./cb_worker.exe

FROM debian:stable-slim

ARG TARGET_ARCH=amd64

RUN apt-get update \
    && apt-get install --no-install-recommends --assume-yes \
        netbase \
        ca-certificates \
        apt-transport-https \
        curl \
        netcat \
        gnupg \
        lsb-release \
        git \
        libpq-dev \
        libsqlite3-dev \
        libev-dev \
    && curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=${TARGET_ARCH} signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" \
        > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install docker-ce-cli graphviz --assume-yes \
    && rm -r /var/lib/apt/lists /var/cache/apt

WORKDIR /app
ENV PATH="/app/bin:${PATH}"

COPY ./aslr_seccomp.json /app/aslr_seccomp.json
COPY --from=build /mnt/project/_build/default/cb_worker.exe /app/bin/cb_worker.exe
