FROM nlnetlabs/routinator
COPY entrypoint.sh /opt/
COPY --from=relyingpartybase /opt/* /opt/
USER root
RUN apk add bash
USER routinator
WORKDIR /
ENTRYPOINT ["/opt/entrypoint.sh"]
