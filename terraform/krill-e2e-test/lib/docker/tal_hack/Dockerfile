FROM alpine
RUN apk add bash wget
COPY --from=relyingpartybase /opt/my_funcs.sh /opt/
COPY tal_hack.sh /opt/
WORKDIR /share
ENTRYPOINT ["/bin/bash", "/opt/tal_hack.sh"]