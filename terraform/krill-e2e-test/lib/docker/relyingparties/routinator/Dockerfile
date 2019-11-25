FROM nlnetlabs/routinator:latest
COPY entrypoint.sh /opt/
COPY --from=docker-reg.do.nlnetlabs.nl/relyingpartybase /opt/* /opt/
USER root
RUN apk add bash jq
USER routinator
WORKDIR /
ENTRYPOINT ["/opt/entrypoint.sh"]