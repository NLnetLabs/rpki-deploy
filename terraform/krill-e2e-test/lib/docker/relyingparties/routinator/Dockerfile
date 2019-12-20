FROM nlnetlabs/routinator:v0.6.5-with-tls-via-features
COPY entrypoint.sh /opt/
COPY --from=relyingpartybase /opt/* /opt/
USER root
RUN apk add bash jq ca-certificates
RUN mv /opt/rootCA.crt /usr/local/share/ca-certificates/
RUN update-ca-certificates
USER routinator
WORKDIR /
ENTRYPOINT ["/opt/entrypoint.sh"]
