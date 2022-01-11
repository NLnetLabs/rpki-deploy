FROM lolepezy/rpki-prover
COPY --from=relyingpartybase /opt/* /opt/
COPY entrypoint.sh /opt/
RUN mv /opt/rootCA.crt /usr/local/share/ca-certificates/
RUN update-ca-certificates || true
WORKDIR /
ENTRYPOINT ["/opt/entrypoint.sh"]
