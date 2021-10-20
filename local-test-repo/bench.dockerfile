FROM ocaml/opam
RUN sudo apt-get update && sudo apt-get install -qq -yy jq
COPY . .
