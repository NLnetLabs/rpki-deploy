FROM ripencc/rpki-validator-3-docker:alpine
COPY --from=relyingpartybase /opt/* /opt/
COPY *.properties *.sh /opt/
ENV CONFIG_DIR=/opt/
RUN apk add bash
ENTRYPOINT [ "/opt/entrypoint.sh" ]