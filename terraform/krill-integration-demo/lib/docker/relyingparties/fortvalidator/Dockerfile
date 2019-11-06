FROM ximoneighteen/fortvalidator
COPY --from=relyingpartybase /opt/* /opt/
COPY entrypoint.sh /opt/krill-entrypoint.sh
ENTRYPOINT ["/tini", "-g", "--", "/opt/krill-entrypoint.sh"]