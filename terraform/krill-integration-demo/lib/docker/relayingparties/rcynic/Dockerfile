FROM ubuntu:18.04

# Install packages
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get -y upgrade && apt-get install -y \
    # rcynic dependencies
    build-essential \
    libpython2.7-dev \
    python2.7 \
    python-django \
    python-lxml \
    python-tornado \
    rrdtool \
    rsync \
    # Dockerfile dependencies
    curl  \
    git \
    # entrypoint.sh dependencies
    wget
RUN update-alternatives --install /usr/bin/python python /usr/bin/python2.7 1

# Build
WORKDIR /tmp/build/rpki
RUN git clone --branch buildbot-1.0.1544679302 --depth 1 https://github.com/dragonresearch/rpki.net.git .
RUN ./configure --disable-ca-tools && make && make install

# Prepare rcynic environment
COPY rcynic.conf /opt/rcynic.conf
RUN mkdir -p /tmp/rcynic/unauthenticated
RUN mkdir -p /tmp/rcynic/tals

# Prepare Docker environment
COPY --from=relyingpartybase /opt/my_funcs.sh /opt/my_funcs.sh
COPY entrypoint.sh /opt/
WORKDIR /
ENTRYPOINT ["/opt/entrypoint.sh"]