FROM ximoneighteen/rcynic

# Install packages
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        lighttpd \
        sqlite3 \
        wget

# Prepare Docker environment
COPY --from=relyingpartybase /opt/* /opt/
COPY entrypoint.sh /opt/
RUN chmod +x /opt/entrypoint.sh
RUN mv /opt/rootCA.crt /usr/local/share/ca-certificates/
RUN update-ca-certificates
ENTRYPOINT ["/opt/entrypoint.sh"]