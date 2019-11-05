FROM cloudflare/octorpki
USER root
RUN apk add jq bash
COPY --from=relyingpartybase /opt/my_funcs.sh /opt/my_funcs.sh
COPY entrypoint.sh /opt/
WORKDIR /
USER rpki
ENTRYPOINT ["/opt/entrypoint.sh"]