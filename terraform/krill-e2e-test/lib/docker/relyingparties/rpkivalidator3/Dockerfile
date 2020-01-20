FROM alpine AS builder
RUN apk add bash maven openjdk8
WORKDIR /tmp/
RUN wget 'https://github.com/RIPE-NCC/rpki-validator-3/archive/v3.1.tar.gz' && \
    tar xvf v3.1.tar.gz && \
    cd rpki-validator-3-3.1/rpki-rtr-server && \
    mvn package -DskipTests || true

FROM ripencc/rpki-validator-3-docker:alpine
RUN apk add bash
COPY --from=builder /tmp/rpki-validator-3-3.1/rpki-rtr-server/target/rpki-rtr-server-3.0-SNAPSHOT.jar /opt/rpki-rtr-server.jar
COPY --from=relyingpartybase /opt/* /opt/
COPY *.properties *.sh /opt/
ENV CONFIG_DIR=/opt/
ENTRYPOINT [ "/opt/entrypoint.sh" ]