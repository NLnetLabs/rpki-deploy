FROM cloudflare/octorpki
USER root
RUN apk add jq bash ca-certificates
COPY --from=relyingpartybase /opt/* /opt/
COPY entrypoint.sh /opt/
RUN mv /opt/rootCA.crt /usr/local/share/ca-certificates/
RUN update-ca-certificates || true
USER rpki
WORKDIR /
ENTRYPOINT ["/opt/entrypoint.sh"]