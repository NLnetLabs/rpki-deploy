FROM ximoneighteen/fortvalidator
COPY --from=relyingpartybase /opt/my_funcs.sh /opt/my_funcs.sh
COPY entrypoint.sh /opt/krill-entrypoint.sh
ENTRYPOINT ["/tini", "-g", "--", "/opt/krill-entrypoint.sh"]