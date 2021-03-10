FROM ocaml/opam AS build

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
    libcapnp-dev

WORKDIR /mnt/project

# Build dependencies.
COPY --chown=opam:opam pipeline.opam pipeline.opam
RUN opam install -y --deps-only -t .
COPY --chown=opam . .

# Build the project.
RUN opam exec -- dune build --profile=release bin/main.exe


FROM debian:stable-slim

RUN apt-get update \
    && apt-get install --no-install-recommends --assume-yes \
        netbase \
        ca-certificates \
        apt-transport-https \
        curl \
        gnupg \
        lsb-release \
        git \
        libpq-dev \
        libsqlite3-dev \
    && curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=arm64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" \
        > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install docker-ce-cli \
    && rm -r /var/lib/apt/lists /var/cache/apt

WORKDIR /app
ENV PATH="/app/bin:${PATH}"

COPY --from=build /mnt/project/_build/default/bin/main.exe /app/bin/current-bench-pipeline
ENTRYPOINT ["/app/bin/current-bench-pipeline"]