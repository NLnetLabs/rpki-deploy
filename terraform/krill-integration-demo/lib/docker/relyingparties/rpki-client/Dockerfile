# Use 'latest' because with 0.2.0 we get error
# "tal.c:109: tal_parse_stream: Assertion `line[linelen - 1] == '\n'' failed."
FROM ximoneighteen/rpki-client:latest
COPY --from=relyingpartybase /opt/* /opt/
COPY entrypoint.sh /opt/
RUN chmod +x /opt/entrypoint.sh
ENTRYPOINT ["/opt/entrypoint.sh"]