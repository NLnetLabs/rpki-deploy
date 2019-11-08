FROM ximoneighteen/rcynic

# Install packages
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
    sqlite3 \
    wget

# Prepare Docker environment
COPY --from=relyingpartybase /opt/* /opt/
COPY entrypoint.sh /opt/
RUN chmod +x /opt/entrypoint.sh
ENTRYPOINT ["/opt/entrypoint.sh"]