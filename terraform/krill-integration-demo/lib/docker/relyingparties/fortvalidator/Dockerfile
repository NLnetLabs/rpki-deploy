FROM ximoneighteen/fortvalidator
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get -y install wget
COPY --from=relyingpartybase /opt/* /opt/
COPY entrypoint.sh /opt/krill-entrypoint.sh
ENTRYPOINT ["/tini", "-g", "--", "/opt/krill-entrypoint.sh"]