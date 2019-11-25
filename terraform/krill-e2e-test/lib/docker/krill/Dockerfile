# This file makes assumptions about how it can "cheat" to speed up the Docker
# build of the Krill image for E2E testing purposes.
#
# Define a variable base image defaulting to Ubuntu 16.04 LTS (because that is
# what the Krill Travis CI build uses). The purpose of using a variable base
# image is to allow for accelerated E2E test builds of Krill by leveraging an
# existing Cargo build cache stored in an image resulting from building only
# stage 1 of the official Cargo build. A full build of Krill from an empty
# Cargo cache takes many times longer and mostly rebuilds lots of the same
# dependencies in which nothing has changed from one Krill build to the next.
# An alternative could be to externalize the Cargo cache via a Docker volume
# mount. To use this Dockerfile for the E2E test 3 things have to happen:
#   1. Build this Dockerfile using --target builder to stop after the first
#      stage.
#   2. Publish the resulting image.
#   3. Invoke this Dockerfile from the E2E test building passing the BASE_IMG
#      arg value that identifies the image published in step 2.
# Steps 3 should happen on every E2E test build, while steps 1 and 2 need only
# be done infrequently, whenever the build time becomes too high because the
# Cargo build cached items are less of a match to the current Krill
# requirements than was the case when the image was last built.
ARG BASE_IMG=ubuntu:16.04

#
# -- stage 1: build krill and krillc
#
FROM ${BASE_IMG} AS builder

# Install Rust
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        curl \
        libssl-dev \
        pkg-config

RUN curl https://sh.rustup.rs -sSf | sh -s -- -y
ENV PATH "/root/.cargo/bin:$PATH"

WORKDIR /tmp/krill
COPY Cargo.toml /tmp/krill/
COPY src /tmp/krill/src/
RUN cargo build --release

# Use an existing runnable Krill image which has the necessary runtime
# dependencies installed already, just copy in the binaries built in the
# previous stage. This avoids installing runtime dependencies on every E2E test
# run even though most of the time these don't change.
# TODO: update FROM to use :latest once published
FROM nlnetlabs/krill:v0.3.0

COPY --from=builder /tmp/krill/target/release/krill /usr/local/bin/
COPY --from=builder /tmp/krill/target/release/krillc /usr/local/bin/

ENTRYPOINT ["/opt/entrypoint.sh"]
CMD ["krill", "-c", "/var/krill/data/krill.conf"]
