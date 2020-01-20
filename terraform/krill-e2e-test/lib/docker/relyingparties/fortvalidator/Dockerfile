FROM ximoneighteen/fortvalidator
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get -y install wget
COPY --from=relyingpartybase /opt/* /opt/
RUN mv /opt/rootCA.crt /usr/local/share/ca-certificates/
COPY entrypoint.sh /opt/krill-entrypoint.sh
RUN update-ca-certificates
ENTRYPOINT ["/tini", "-g", "--", "/opt/krill-entrypoint.sh"]