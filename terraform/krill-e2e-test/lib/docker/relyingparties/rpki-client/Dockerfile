# Use 'latest' because with 0.2.0 we get error
# "tal.c:109: tal_parse_stream: Assertion `line[linelen - 1] == '\n'' failed."
FROM ximoneighteen/rpki-client:latest

# Install packages
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