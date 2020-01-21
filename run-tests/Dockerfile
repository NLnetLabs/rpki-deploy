FROM ubuntu:18.04
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        apt-transport-https \
        build-essential \
        ca-certificates \
        cmake \
        curl \
        git \
        python3-venv \
        software-properties-common \
        unzip
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - && \
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic stable" && \
    apt-get update && \
    apt-cache policy docker-ce && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y docker-ce
RUN curl -L https://github.com/docker/compose/releases/download/1.25.2/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose && \
    chmod +x /usr/local/bin/docker-compose
WORKDIR /tmp/build/rtrlib
RUN curl -fsSLo- 'https://github.com/rtrlib/rtrlib/archive/v0.7.0.tar.gz' | tar zx --strip-components 1 && \
    cmake -D CMAKE_C_FLAGS='-DNDEBUG' -D CMAKE_BUILD_TYPE=Release -D RTRLIB_TRANSPORT_SSH=No . && \
    make && \
    make install && \
    ldconfig
WORKDIR /tmp/build/terraform
RUN curl -fsSLo terraform.zip 'https://releases.hashicorp.com/terraform/0.12.19/terraform_0.12.19_linux_amd64.zip' && \
    unzip terraform.zip && \
    cp terraform /opt/
RUN git clone --depth 1 --branch master https://github.com/nlnetlabs/rpki-deploy/ /opt/run-tests/
RUN rm -Rf /tmp/build
RUN apt-get purge -y \
        apt-transport-https \
        build-essential \
        cmake \
        curl \
        git \
        software-properties-common \
        unzip && \
    apt-get autoremove -y
ENV PATH /opt:$PATH
ENV TF_DIR /opt/run-tests/terraform/krill-e2e-test/run_on_do
ENV TF_PLUGIN_DIR /opt/tf.plugins/
WORKDIR ${TF_PLUGIN_DIR}
WORKDIR ${TF_DIR}
RUN mv /opt/run-tests/terraform/plugins/terraform-provider-dockermachine . && \
    terraform init -lock=false && \
    mv .terraform/plugins/linux_amd64/* ${TF_PLUGIN_DIR} && \
    rm -R .terraform
RUN terraform init -lock=false -plugin-dir=${TF_PLUGIN_DIR}
COPY entrypoint.sh /opt/entrypoint.sh
ENTRYPOINT ["/opt/entrypoint.sh"]