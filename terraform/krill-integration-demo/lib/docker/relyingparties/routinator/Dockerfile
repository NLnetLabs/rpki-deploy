FROM nlnetlabs/routinator:latest
COPY entrypoint.sh /opt/
COPY --from=relyingpartybase /opt/* /opt/
WORKDIR /
ENTRYPOINT ["/opt/entrypoint.sh"]