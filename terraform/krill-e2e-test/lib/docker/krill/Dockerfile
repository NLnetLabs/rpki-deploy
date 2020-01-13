# This file is intended to replace the official Dockerfile in the Krill repo.
# Aside from the variable base image it is identical to the official Krill
# Dockerfile.
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

COPY . /tmp/krill/
RUN cargo build --release

#
# -- stage 2: create an image containing just the binaries, configs &
#             scripts needed to run Krill, and not the things needed to build
#             it.
#
FROM ubuntu:16.04
COPY --from=builder /tmp/krill/target/release/krill /usr/local/bin/
COPY --from=builder /tmp/krill/target/release/krillc /usr/local/bin/

# Build variables for uid and guid of user to run container
ARG RUN_USER=krill
ARG RUN_USER_UID=1012
ARG RUN_USER_GID=1012

# Install openssl as Krill depends on it.
# Install uuid-runtime for generating an authorization token on startup.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        openssl \
        uuid-runtime

RUN groupadd -g ${RUN_USER_GID} ${RUN_USER} && \
    useradd -g ${RUN_USER_GID} -u ${RUN_USER_UID} ${RUN_USER}

# Create the data directory structure and install a config file that uses it
WORKDIR /var/krill/data
COPY docker/krill.conf .
RUN chown -R ${RUN_USER}: .

# Install a Docker entrypoint script that will be executed when the container
# runs
COPY docker/entrypoint.sh /opt/
RUN chown ${RUN_USER}: /opt/entrypoint.sh

EXPOSE 3000/tcp

ENTRYPOINT ["/opt/entrypoint.sh"]
CMD ["krill", "-c", "/var/krill/data/krill.conf"]
