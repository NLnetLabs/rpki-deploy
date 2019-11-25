FROM cloudflare/octorpki
USER root
RUN apk add jq bash
COPY --from=docker-reg.do.nlnetlabs.nl/relyingpartybase /opt/* /opt/
COPY entrypoint.sh /opt/
WORKDIR /
USER rpki
ENTRYPOINT ["/opt/entrypoint.sh"]