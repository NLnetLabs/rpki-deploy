FROM nicmx/fort-validator
RUN apk add bash ca-certificates wget
COPY --from=relyingpartybase /opt/* /opt/
COPY entrypoint.sh /opt/
COPY fort.conf /opt/
RUN mv /opt/rootCA.crt /usr/local/share/ca-certificates/
RUN update-ca-certificates || true
ENTRYPOINT ["tini", "-g", "--", "/opt/entrypoint.sh"]