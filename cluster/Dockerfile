FROM ocaml/opam:debian-ocaml-4.13 AS build
RUN sudo apt-get update && sudo apt-get install libc6-dev libev-dev capnproto m4 pkg-config libsqlite3-dev libgmp-dev libffi-dev -y --no-install-recommends
RUN opam remote add origin 'https://opam.ocaml.org' --all-switches && opam remote remove default && opam update
RUN mkdir src && cd src && git clone 'https://github.com/ocurrent/ocluster' && opam pin -yn ocluster
RUN cd src && git clone 'https://github.com/ocurrent/obuilder' && opam pin -yn obuilder
WORKDIR src/ocluster
RUN opam install -y --deps-only .
RUN opam config exec -- dune build \
  ./_build/install/default/bin/ocluster-scheduler \
  ./_build/install/default/bin/ocluster-admin

FROM debian:stable-slim
RUN apt-get update && apt-get install libev4 libsqlite3-0 -y --no-install-recommends
RUN apt-get install ca-certificates -y  # https://github.com/mirage/ocaml-conduit/issues/388
WORKDIR /var/lib/ocluster-scheduler
ENTRYPOINT ["/usr/local/bin/ocluster-scheduler"]
COPY --from=build \
     /home/opam/src/ocluster/_build/install/default/bin/ocluster-scheduler \
     /home/opam/src/ocluster/_build/install/default/bin/ocluster-admin \
     /usr/local/bin/
