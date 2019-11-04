FROM nlnetlabs/routinator:latest
COPY entrypoint.sh /opt/
COPY --from=relayingpartybase /opt/my_funcs.sh /opt/my_funcs.sh
WORKDIR /
ENTRYPOINT ["/opt/entrypoint.sh"]