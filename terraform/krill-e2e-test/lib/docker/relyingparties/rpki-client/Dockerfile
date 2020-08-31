FROM ximoneighteen/rpki-client

# Install packages
USER root
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        lighttpd \
        wget

# Prepare Docker environment
COPY --from=relyingpartybase /opt/* /opt/
COPY entrypoint.sh /opt/
RUN chmod a+x /opt/entrypoint.sh
RUN mv /opt/rootCA.crt /usr/local/share/ca-certificates/
RUN update-ca-certificates
ENTRYPOINT ["/opt/entrypoint.sh"]