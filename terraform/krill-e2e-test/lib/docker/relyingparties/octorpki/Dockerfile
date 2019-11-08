FROM cloudflare/octorpki
USER root
RUN apk add jq bash
COPY --from=relyingpartybase /opt/* /opt/
COPY entrypoint.sh /opt/
WORKDIR /
USER rpki
ENTRYPOINT ["/opt/entrypoint.sh"]