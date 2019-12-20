FROM ripencc/rpki-validator-3-docker:alpine
COPY --from=relyingpartybase /opt/* /opt/
COPY *.properties *.sh /opt/
ENV CONFIG_DIR=/opt/
RUN apk add bash
RUN mv /opt/rootCA.crt /usr/local/share/ca-certificates/
RUN update-ca-certificates
ENTRYPOINT [ "/opt/entrypoint.sh" ]
